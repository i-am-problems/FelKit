local addon,S=...
local A,U,L=S.API,S.UI,S.L
S.state={tokens={},units={}}; S.plates={}; S.procState={active=nil}; S.failedEvents={}
function S.setKeep(value)
    local n=S.Model.number(value,0,80)
    if not n or n~=math.floor(n) then S.print(L.invalid); return false end
    S.db.keep=n
    local _,count=A.inventory(); U.count(count); U.syncKeep()
    return true
end
function S.print(text) A.chat(text) end
-- kind names the input for automatic runs ('key', 'click', 'UseAction'...); nil = manual.
-- Returns the model code.
function S.prune(kind)
    local automatic=type(kind)=='string'
    if not S.ready or not S.db.enabled or not S.db.shards then
        if not automatic then S.print(L.disabled) end
        return 'disabled'
    end
    -- Until the bags report the previous deletion (or 1.5 s at most).
    if S.pruneBusy and GetTime()<S.pruneBusy then
        S.shardTrace.last='waiting-bag-update'; if not automatic then S.print(L.waitingBag) end
        return 'waiting'
    end
    S.pruneBusy=nil
    S.shardTrace.attempts=S.shardTrace.attempts+1
    local code,n,expected,left=S.Model.prune(A,S.db.keep,S.db.pruneSoulBag)
    S.shardTrace.last=code
    -- Nothing to delete: key presses skip the bag scan until the bags change
    -- (or 1.5 s at most, like the wait for a deletion above).
    S.shardIdle=code=='nothing' and GetTime()+1.5 or nil
    if code=='requested' then
        S.pruneBusy=GetTime()+1.5
        if automatic and left==0 then S.print(string.format(L.autoDeleted,n)) end
    end
    if not automatic then S.print(L[code] or code) end
    -- The model already counted: no second scan for the counter.
    if code=='nothing' then U.count(expected,nil,0)
    elseif code=='requested' then U.count(expected,nil,left)
    else U.count(select(2,A.inventory())) end
    return code
end
-- Proc alert sounds: a few distinct game sounds (client SoundKit IDs checked in
-- the 1.60.1 SoundKit table, played at master volume), then original sounds
-- synthesized for the addon (Media/sfx-*.wav, tools/build_proc_sounds.py), which
-- cannot be mistaken for a class or interface sound.
local function icon(name) return 'Interface\\Icons\\'..name end
S.PROC_SOUNDS={
    {kit=8959,key='raid',icon=icon'Ability_Warrior_BattleShout'},
    {kit=8960,key='ready',icon=icon'INV_Misc_Note_01'},
    {kit=12889,key='alarm',icon=icon'INV_Misc_PocketWatch_01'},
    {kit=888,key='level',icon=icon'Spell_Holy_InnerFire'},
    {kit=7315,spell=1122},  -- Inferno
    {kit=8459,key='bg',icon=icon'INV_BannerPVP_02'},
    {kit=416,key='murloc',icon=icon'INV_Misc_Head_Murloc_01'},
    {file='sfx-crystal',key='crystal',icon=icon'INV_Misc_Gem_Pearl_04'},
    {file='sfx-sweep',key='sweep',icon=icon'Spell_Arcane_StarFire'},
    {file='sfx-drop',key='drop',icon=icon'Spell_Shadow_AntiShadow'},
    {file='sfx-bell',key='bell',icon=icon'Spell_Holy_MagicalSentry'},
    {file='sfx-duo',key='duo',icon=icon'Spell_Nature_WispSplode'},
    {file='sfx-arpeggio',key='arpeggio',icon=icon'Spell_Holy_PowerInfusion'},
    {file='sfx-gong',key='gong',icon=icon'Spell_Nature_Earthquake'},
    {file='sfx-shimmer',key='shimmer',icon=icon'Spell_Nature_Purge'},
    {file='sfx-heartbeat',key='heartbeat',icon=icon'Spell_Nature_Regenerate'},
    {file='sfx-whoosh',key='whoosh',icon=icon'Spell_Nature_Cyclone'},
    {file='sfx-kalimba',key='kalimba',icon=icon'Spell_Nature_Tranquility'},
    {file='sfx-horn',key='horn',icon=icon'INV_Misc_Bone_HumanSkull_01'},
    {file='sfx-zap',key='zap',icon=icon'Spell_Nature_Lightning'},
}
-- 0.7.1: every alert has a volume. Add-ons cannot set the volume of one sound,
-- so below 100 % the sound plays on the Dialog channel, whose volume is lowered
-- for a few seconds and then restored exactly (also at logout).
local DIALOG='Sound_DialogVolume'
function S.restoreDialog()
    if S.dialogSaved and SetCVar then pcall(SetCVar,DIALOG,S.dialogSaved) end
    S.dialogSaved=nil
end
local function scaledChannel(volume)
    if volume>=1 or not GetCVar or not SetCVar or not C_Timer then return 'Master' end
    local ok,enabled=pcall(GetCVar,'Sound_EnableDialog')
    if not ok or enabled~='1' then return 'Master' end
    if not S.dialogSaved then
        local read,current=pcall(GetCVar,DIALOG)
        if not read or not tonumber(current) then return 'Master' end
        S.dialogSaved=current
    end
    pcall(SetCVar,DIALOG,tostring(volume))
    S.dialogToken=(S.dialogToken or 0)+1
    local token=S.dialogToken
    C_Timer.After(4,function() if S.dialogToken==token then S.restoreDialog() end end)
    return 'Dialog'
end
function S.sound()
    S.stopSound()
    local choice=S.PROC_SOUNDS[S.db.procSound]
    if choice then
        local volume=S.db.procVolume/100
        if volume<=0 then return true end
        local channel=scaledChannel(volume)
        local ok,played,handle
        if choice.file then
            ok,played,handle=pcall(PlaySoundFile,'Interface\\AddOns\\'..addon..'\\Media\\'..choice.file..'.wav',channel)
        else ok,played,handle=pcall(PlaySound,choice.kit,channel) end
        S.soundHandle=ok and A.num(handle) or nil
        return ok and A.public(played)~=false
    end
    if S.db.procVolume==0 then return true end
    -- Shadow Trance 17941 -> visual 5219 -> kit 4569 -> SoundKit 3219 -> file 569668.
    -- The exact proc recording is amplified offline with peak limiting.
    -- Master makes it independent of SFX attenuation; global volume CVars stay untouched.
    local file=S.db.procVolume==100 and 'nightfall-proc-strong.wav' or ('nightfall-strong-'..S.db.procVolume..'.wav')
    local ok,played,handle=pcall(PlaySoundFile,'Interface\\AddOns\\'..addon..'\\Media\\'..file,'Master')
    S.soundHandle=ok and A.num(handle) or nil
    return ok and A.public(played)==true
end
function S.stopSound()
    if S.soundHandle then A.call(StopSound,S.soundHandle); S.soundHandle=nil end
end
function S.updateProc(initial)
    if (not S.db.enabled or not S.db.nightfall) and not S.alertDemoUntil then
        S.Nightfall.show(false,nil,false); S.procState.active=nil; return
    end
    local active,aura,source=S.Nightfall.read()
    S.Nightfall.source=source
    local visual,play=S.Model.proc(S.procState,active,initial)
    local enabled=S.db.enabled and S.db.nightfall
    S.Nightfall.show(enabled and S.db.visual and visual,aura,false)
    if enabled and S.db.sound and play then
        if S.sound() and (S.db.procSound>0 or S.db.procVolume>0) then S.Nightfall.soundAlerts=S.Nightfall.soundAlerts+1 end
    end
end
function S.updateChannel(event,cast)
    local c=A.channel()
    if event=='UNIT_SPELLCAST_CHANNEL_STOP' or event=='UNIT_SPELLCAST_INTERRUPTED' or
        (c and GetTime()>=c.finish) then c=nil end
    S.Ticks.capture(c,event)
    S.Tracker.trackChannel(c,event,cast)
    if not S.db.enabled or not S.db.channels then c=nil end
    if c and S.db.channelSpells[c.id]==false then c=nil end
    S.channel=c
    S.Ticks.hide()
end
-- Test bars (settings preview or 10 s demo): public fixtures, never mixed with real units.
function S.setPreview(on)
    S.previewOn=on==true and not A.combat()
    S.updateEnemies()
    if S.Options then S.Options.refresh() end
end
function S.updateEnemies()
    -- The MultiTarget engine owns the current view. Never wake the retired
    -- tracker/render path from its periodic driver.
    if not S.legacyEnemies then return end
    S.state={tokens={},units={}}
    S.excludedEnemies={}; S.unitReasons={}; S.unitMasked={}
    if not S.legacyEnemies or not S.db.enabled or not S.db.enemies then S.Tracker.clear(); U.enemyRows({}); return end
    if S.previewOn or S.demoUntil then U.enemyRows(S.NativeDots.previewUnits(GetTime()),'preview'); return end
    if not S.db.dotPredict and not S.db.dotConfirmedOnly then S.Tracker.targets={} end
    local groupUnits=A.groupUnits()
    for token in pairs(S.plates) do
        local unit,excluded=A.unit(token,groupUnits)
        if excluded then S.excludedEnemies[excluded]=true end
        S.Model.replaceUnit(S.state,token,unit,not S.db.enemiesCombatOnly)
    end
    local list={}
    for _,u in pairs(S.state.units) do list[#list+1]=u end
    table.sort(list,function(a,b) return a.guid<b.guid end)
    U.enemyRows(S.Tracker.merge(list,GetTime()))
end
function S.refreshAll()
    if not S.ready then return end
    -- Readers that cache what they derive from the settings compare this number.
    S.settingsVersion=(S.settingsVersion or 0)+1
    S.shardIdle=nil
    if S.db.enabled then S.Spells.captureReference() end
    S.demoUntil=nil; S.alertDemoUntil=nil
    U.layout(); local items,count=A.inventory(); U.count(count,items)
    S.updateChannel(); S.updateEnemies(); S.updateProc(true)
    if S.WH and S.WH.refresh then S.WH.refresh() end
    if U.refreshDetail then U.refreshDetail() end
    if S.Kit then S.Kit.refresh() end
    S.Ticks.syncGuard()
    if S.Options then S.Options.refresh() end
end
function S.stopAlertPreview()
    S.alertDemoUntil=nil; S.stopSound(); S.updateProc(true)
end
function S.demoAlert(mode)
    if A.combat() then S.print(L.previewOnly); return end
    S.stopAlertPreview()
    if mode~='sound' and (mode=='visual' or S.db.visual) then
        S.alertDemoUntil=GetTime()+5
        S.Nightfall.show(true,{expires=S.alertDemoUntil,duration=5},true)
    end
    if mode~='visual' and (mode=='sound' or S.db.sound) then
        if not S.sound() then S.print(L.nightfallSoundFailed) end
    end
end
function S.demo()
    if A.combat() then S.print(L.previewOnly); return end
    S.Ticks.capture(nil); S.Ticks.hide()
    S.demoUntil=GetTime()+10
    if S.legacyEnemies then U.enemy:Show() end; S.updateEnemies()
    S.channel=nil -- Demo never creates or drives a replacement player cast bar.
    S.demoAlert()
end
function S.diagnostics()
    local t=S.shardTrace
    local refused={}
    for k in pairs(S.db.shardRefused or {}) do refused[#refused+1]=k end
    table.sort(refused)
    S.print('shard-fix 3 | auto='..tostring(S.db.autoShards)..' refused='..(#refused>0 and table.concat(refused,', ') or 'none')..
        ' keys='..t.keys..' clicks='..t.clicks..' attempts='..t.attempts..' last='..t.last)
    local _,total=A.inventory()
    S.print('shards='..tostring(total)..' max='..S.db.keep..' busy='..tostring(S.pruneBusy~=nil)..
        ' keyboardFrame='..tostring(S.autoFrame and S.autoFrame:IsShown() or false))
    local version,build,_,toc=GetBuildInfo()
    S.print(tostring(version)..'.'..tostring(build)..' / '..tostring(toc)..' | '..tostring(_VERSION))
    local checks={C_Container=C_Container and C_Container.GetContainerItemInfo,
        C_UnitAuras=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex,
        C_NamePlate=C_NamePlate and C_NamePlate.GetNamePlateForUnit,
        UnitChannelInfo=UnitChannelInfo,issecretvalue=issecretvalue,DeleteCursorItem=DeleteCursorItem}
    for _,name in ipairs({'C_Container','C_UnitAuras','C_NamePlate','UnitChannelInfo','issecretvalue','DeleteCursorItem'}) do
        S.print(name..': '..tostring(type(checks[name])=='function'))
    end
    S.print(L.tickPrediction..' | '..L.procHelp)
    for name in pairs(S.failedEvents) do S.print(name..': '..L.unavailable) end
end
local function slash(text)
    text=(text or ''):match('^%s*(.-)%s*$')
    if text:match('^dot%s+') then
        local id,duration,interval,total=text:match('^dot%s+(%d+)%s+(%S+)%s+(%S+)%s+(%S+)$')
        if id and S.Tracker.setProfile(id,duration,interval,total) then S.print(L.dotSaved)
        else S.print(L.dotProfileHelp) end
    elseif text=='dots debug' then
        S.NativeDots.diagnostics()
        local registered,visible,public,native=0,0,0,0
        for _ in pairs(S.plates) do registered=registered+1 end
        for _,u in pairs(S.state.units) do
            visible=visible+1
            for _,a in ipairs(u.effects) do if a.native then native=native+1 else public=public+1 end end
        end
        local excluded=0; for _ in pairs(S.excludedEnemies or {}) do excluded=excluded+1 end
        S.print('DoT | nameplates='..registered..' engagés='..visible..' exclus (non engagés)='..excluded..
            ' effets publics='..public..' natifs='..native..' activé='..tostring(S.db.enabled and S.db.enemies)..
            ' filtre engagés='..tostring(S.db.enemiesCombatOnly)..' cvars nameplateShowEnemies='..tostring(GetCVar and A.call(GetCVar,'nameplateShowEnemies'))..
            ' nameplateShowAll='..tostring(GetCVar and A.call(GetCVar,'nameplateShowAll')))
        local reasons={}
        for k,v in pairs(S.unitReasons or {}) do reasons[#reasons+1]=k..'='..v end
        table.sort(reasons)
        S.print('Rejets | '..(#reasons>0 and table.concat(reasons,' ') or 'aucun')..
            ' | masqués par le jeu : nom='..((S.unitMasked or {}).name or 0)..' guid='..((S.unitMasked or {}).guid or 0))
        for i=1,math.min(3,#(S.db.diagLog or {})) do S.print('Journal '..i..' : '..S.db.diagLog[i]) end
        local all,complete,trace=A.enemyAuras('target',true)
        local owned=0; for _,a in ipairs(all) do if a.own then owned=owned+1 end end
        S.print('Cible | lecture complète='..tostring(complete==true)..' effets personnels='..owned..
            ' combat groupe='..tostring(A.groupEngaged('target',all))..
            ' durée native API='..tostring(type(C_UnitAuras and C_UnitAuras.GetAuraDuration)=='function')..
            ' cadre cible natif='..tostring(type(UIParent and UIParent.SetAlphaFromBoolean)=='function')..
            ' clic cible='..tostring(S.CardClick.shown)..
            ' timers malédiction='..tostring(S.Kit.buttons.curse1 and S.Kit.buttons.curse1.curseNative~=nil)..(S.Kit.curseError and (' ('..S.Kit.curseError..')') or ''))
        local errors={}; local printed=0
        for _,key in ipairs({'raw','player','names'}) do
            local t=trace[key]
            S.print('Lecture v2 '..key..' | entrées='..(t.records or 0)..' masquées='..(t.masked or 0)..
                ' erreurs='..(t.failed or 0)..' fin='..(t.ended or 0)..' API absente='..(t.unavailable or 0))
            if key~='raw' then
                S.print(key..' | ID illisible='..(t.idUnreadable or 0)..' instance illisible='..(t.instanceUnreadable or 0)..
                    ' durée illisible='..(t.clockUnreadable or 0)..' retenues='..(t.accepted or 0))
            end
        end
        local ct=trace.clock
        S.print('Horloge | OK='..(ct.accepted or 0)..' erreurs='..(ct.failed or 0)..' masquée='..(ct.masked or 0)..
            ' vide='..(ct.empty or 0)..' sans instance='..(ct.noInstance or 0)..' API absente='..(ct.unavailable or 0))
        for _,key in ipairs({'raw','player','names','clock'}) do
            local errorText=trace[key].error
            if errorText and not errors[errorText] and printed<2 then
                errors[errorText]=true; printed=printed+1; S.print('Erreur '..key..' : '..errorText)
            end
        end
    elseif text=='dots test' then S.NativeDots.selfTest()
    elseif text=='dots retry' then S.NativeDots.retry(); S.updateEnemies(); S.NativeDots.diagnostics()
    elseif text=='dots' then U.open('enemies')
    elseif text=='did' or text:match('^did ') then
        if S.DID and S.DID.command then S.DID.command(text:sub(5)) end
    elseif text=='setup' then S.Onboarding.open(true)
    elseif text=='auto on' or text=='auto off' then
        S.db.autoShards=text=='auto on'; S.db.shardRefused={}
        S.shardTrace.last=S.db.autoShards and 'enabled' or 'disabled'
        if U.autoCheck then U.autoCheck:SetChecked(S.db.autoShards) end
        S.print(S.db.autoShards and L.autoOn or L.autoOff)
    elseif text=='spells' then U.open('grimoire')
    elseif text=='shards' then U.openShards()
    elseif text=='summons' then S.Kit.openQueue()
    elseif text=='kit' then U.openKit()
    elseif text=='pierres' or text=='healthstones' then S.Kit.healthDebug()
    elseif text=='nightfall debug' then S.Nightfall.diagnostics()
    elseif text=='nightfall' then U.open('nightfall')
    elseif text:match('^max%s+') then S.setKeep(text:match('^max%s+(.+)$'))
    elseif text=='prune' then S.prune()
    elseif text=='diagnostics' then S.diagnostics()
    elseif text=='demo' then S.demo()
    elseif text=='reset' then U.reset()
    else S.Options.toggle() end
end
-- A lowered Dialog volume never outlives the session.
local logout=CreateFrame('Frame')
logout:RegisterEvent('PLAYER_LOGOUT')
logout:SetScript('OnEvent',function() S.restoreDialog() end)
local events=CreateFrame('Frame')
local function register(name)
    local ok=pcall(events.RegisterEvent,events,name)
    if not ok then S.failedEvents[name]=true end
end
-- Unit events are frequent in groups: only units that can be on an enemy card
-- matter to the enemy frame (nameplates and the target/focus/mouseover aliases).
local ALIASES={target=true,focus=true,mouseover=true}
local function enemyUnit(unit)
    unit=A.public(unit)
    return type(unit)=='string' and (S.plates[unit]==true or ALIASES[unit]==true)
end
local function aurasSecret() return C_Secrets and A.call(C_Secrets.ShouldAurasBeSecret)==true end
local function initialPlates()
    S.plates={}
    local plates=C_NamePlate and A.call(C_NamePlate.GetNamePlates)
    for _,plate in ipairs(plates or {}) do
        local token=A.field(plate,'namePlateUnitToken')
        if type(token)=='string' then S.plates[token]=true end
    end
end
events:SetScript('OnEvent',function(_,event,arg,arg2,arg3,arg4)
    if event=='ADDON_LOADED' then
        if arg~=addon then return end
        local _,class=UnitClass('player')
        if class~='WARLOCK' then events:UnregisterAllEvents(); return end
        local _,_,_,toc=GetBuildInfo()
        if toc~=16001 then S.print(L.unsupported); events:UnregisterAllEvents(); return end
        if A.combat() then S.pendingLoad=true; register('PLAYER_REGEN_ENABLED'); return end
        S.pendingLoad=nil
        FelkitDB=S.Model.settings(FelkitDB); S.db=FelkitDB
        S.builtLanguage=S.applyLocale(S.db.language)
        U.create(); S.ready=true; S.Kit.create(); S.Spells.setupTooltips()
        SLASH_FELKIT1='/felkit'
        local collision=false
        for k,v in pairs(_G) do
            if type(k)=='string' and k:match('^SLASH_') and type(v)=='string' and v:lower()=='/fk' then collision=true end
        end
        if collision then S.print(L.collision) else SLASH_FELKIT2='/fk' end
        SlashCmdList.FELKIT=slash
        local prune=CreateFrame('Button','FelkitPruneButton',UIParent)
        prune:RegisterForClicks('LeftButtonUp'); prune:SetScript('OnClick',function() S.prune() end)
        for _,name in ipairs({'PLAYER_ENTERING_WORLD','BAG_UPDATE_DELAYED','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED',
            'GROUP_ROSTER_UPDATE','SPELLS_CHANGED','SPELL_TEXT_UPDATE','PLAYER_EQUIPMENT_CHANGED','PLAYER_LEVEL_UP','TRAIT_CONFIG_UPDATED'}) do register(name) end
        -- The player's own events (spell reference, channel ticks, casts).
        for _,name in ipairs({'UNIT_AURA','UNIT_STATS','UNIT_PET','UNIT_SPELLCAST_SENT','UNIT_SPELLCAST_START','UNIT_SPELLCAST_SUCCEEDED',
            'UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_UPDATE','UNIT_SPELLCAST_CHANNEL_STOP',
            'UNIT_SPELLCAST_INTERRUPTED'}) do
            if S.legacyEnemies or not pcall(events.RegisterUnitEvent,events,name,'player') then register(name) end
        end
        -- Enemy events only feed the legacy enemy frame (the DoT table has its own).
        if S.legacyEnemies then
            for _,name in ipairs({'NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_HEALTH','UNIT_MAXHEALTH','UNIT_FLAGS',
                'PLAYER_TARGET_CHANGED','UNIT_THREAT_LIST_UPDATE','UNIT_THREAT_SITUATION_UPDATE','PLAYER_FOCUS_CHANGED','UNIT_TARGET'}) do register(name) end
        end
        initialPlates(); S.refreshAll(); S.setupAutoInput()
        return
    end
    if not S.ready then
        if event=='PLAYER_REGEN_ENABLED' and S.pendingLoad then
            events:GetScript('OnEvent')(events,'ADDON_LOADED',addon)
        end
        return
    end
    if S.db.enabled and (event=='SPELLS_CHANGED' or event=='SPELL_TEXT_UPDATE' or event=='PLAYER_EQUIPMENT_CHANGED'
        or event=='PLAYER_LEVEL_UP' or event=='TRAIT_CONFIG_UPDATED') then
        -- Read now, and once more shortly after in case the game was not ready yet.
        S.Spells.captureReference(); S.referenceDirty=true
    elseif (event=='UNIT_STATS' or event=='UNIT_AURA') and A.public(arg)=='player' then
        -- Frequent: read at most ten times a second (OnUpdate below).
        S.referenceDirty=true
    end
    if event=='PLAYER_ENTERING_WORLD' then
        S.Spells.clearReference()
        S.Spells.setupTooltips()
        S.Ticks.capture(nil); S.Tracker.clear()
        initialPlates(); S.refreshAll(); S.setupAutoInput()
        S.Onboarding.maybeShow()
    elseif event=='GROUP_ROSTER_UPDATE' then S.Tracker.clear(); S.dirty=true
    elseif event=='BAG_UPDATE_DELAYED' then
        S.pruneBusy=nil; S.shardIdle=nil
        local items,count=A.inventory(); U.count(count,items)
    elseif event=='NAME_PLATE_UNIT_ADDED' then
        if type(A.public(arg))=='string' then S.plates[arg]=true; S.dirty=true end
    elseif event=='NAME_PLATE_UNIT_REMOVED' then
        if type(A.public(arg))=='string' then S.plates[arg]=nil; S.Model.replaceUnit(S.state,arg,nil); S.updateEnemies() end
    elseif event=='UNIT_AURA' then
        -- Nightfall has its own event frame; unrelated work above can fail
        -- without preventing the proc callback from running in combat.
        -- Secret auras drawn by the native engine give Lua nothing new to read.
        if enemyUnit(arg) and not (S.NativeDots.active and aurasSecret()) then S.dirty=true end
    elseif event=='UNIT_HEALTH' or event=='UNIT_MAXHEALTH' then
        if enemyUnit(arg) then S.healthDirty=true end
    elseif event=='UNIT_FLAGS' or event=='UNIT_TARGET' or event=='UNIT_THREAT_LIST_UPDATE' then
        if enemyUnit(arg) then S.dirty=true end
    elseif event=='UNIT_PET' then
        if A.public(arg)=='player' then S.dirty=true end
    elseif event=='UNIT_STATS' then -- spell reference only (above)
    elseif event:find('UNIT_SPELLCAST_',1,true)==1 then
        S.Tracker.event(event,arg,arg2,arg3,arg4)
        if A.public(arg)=='player' and (event:find('CHANNEL',1,true) or event=='UNIT_SPELLCAST_INTERRUPTED') then S.demoUntil=nil; S.updateChannel(event,arg2); S.updateEnemies() end
    elseif event=='PLAYER_REGEN_DISABLED' then S.CardClick.hide(); S.previewOn=false; S.refreshAll()
    elseif event=='PLAYER_REGEN_ENABLED' then
        S.CardClick.resume()
        if not S.Kit.header then S.Kit.create() end
        S.refreshAll(); S.setupAutoInput(); S.dirty=true
        S.Onboarding.maybeShow()
    elseif event=='SPELLS_CHANGED' or event=='SPELL_TEXT_UPDATE' then A.dotAuraNames=nil; A.procName=nil; S.Tracker.profiles={}; S.Options.refresh()
    else S.dirty=true end
end)
local elapsed,lastScan,referenceElapsed=0,0,0
events:SetScript('OnUpdate',function(_,dt)
    if not S.ready then return end
    -- Out of combat only (it returns at once in combat): keeps the last
    -- coherent spell reference fresh for the moment combat starts. Player
    -- buffs and stats mark it dirty; every input has an event, so the
    -- periodic read is only a safety net.
    referenceElapsed=referenceElapsed+dt
    if S.db.enabled and ((S.referenceDirty and referenceElapsed>=0.1) or referenceElapsed>=5) then
        referenceElapsed=0; S.referenceDirty=nil; S.Spells.captureReference()
    end
    U.animate(GetTime()) -- lightweight fill only, at the client's rendering rate
    elapsed=elapsed+dt; lastScan=lastScan+dt
    if elapsed<0.05 then return end
    elapsed=0; local now=GetTime()
    if S.demoUntil and now>=S.demoUntil then S.demoUntil=nil; S.refreshAll() end
    if S.alertDemoUntil and now>=S.alertDemoUntil then S.alertDemoUntil=nil; S.updateProc(true) end
    -- Health only, native display: refresh the bars in place, without an aura
    -- scan or relayout. The public fallback needs a full pass.
    local fullHealth=S.healthDirty and not S.NativeDots.active
    if ((S.dirty or fullHealth) and lastScan>=0.15) or lastScan>=0.5 then
        S.dirty=false; S.healthDirty=false; lastScan=0; S.updateEnemies()
        if S.channel and now>=S.channel.finish then S.updateChannel() end
    elseif S.healthDirty and S.NativeDots.active then
        S.healthDirty=false; S.NativeDots.refreshHealth()
    end
    U.tick(now,true)
end)
register('ADDON_LOADED')
