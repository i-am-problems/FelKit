local addon,S=...
local N={}; S.Nightfall=N
local A,L=S.API,S.L
function N.readEventAura()
    local aura=N.eventAura
    if not aura then return nil end
    if aura.expires and GetTime()>=aura.expires then N.eventAura=nil; return nil end
    -- A public instance ID identifies the aura already observed in UNIT_AURA.
    -- Unknown timing may be displayed only while that exact instance is readable.
    if not aura.expires then
        local raw=aura.instance and C_UnitAuras and A.call(C_UnitAuras.GetAuraDataByAuraInstanceID,'player',aura.instance)
        local current=A.procRecord(raw,true)
        if not current then N.eventAura=nil; return nil end
        current.instance=current.instance or aura.instance
        aura=current; N.eventAura=current
    end
    return aura
end
function N.captureAuraUpdate(raw)
    local info=A.public(raw)
    if type(info)~='table' then return end
    local full=A.field(info,'isFullUpdate')
    if full==true then N.eventAura=nil; return end
    if full~=false then return end
    local removed=A.field(info,'removedAuraInstanceIDs')
    if type(removed)=='table' and N.eventAura and N.eventAura.instance then
        for _,instance in ipairs(removed) do
            if A.num(instance)==N.eventAura.instance then
                N.eventAura=nil; N.nativeActive=nil; N.eventRemovals=N.eventRemovals+1; break
            end
        end
    end
    local updated=A.field(info,'updatedAuraInstanceIDs')
    if type(updated)=='table' and N.eventAura and N.eventAura.instance then
        for _,instance in ipairs(updated) do
            if A.num(instance)==N.eventAura.instance then
                local rawAura=C_UnitAuras and A.call(C_UnitAuras.GetAuraDataByAuraInstanceID,'player',N.eventAura.instance)
                local aura=A.procRecord(rawAura,true)
                if aura then
                    -- A masked refresh must not extend a previous public deadline.
                    aura.expires=aura.expires or N.eventAura.expires
                    aura.instance=aura.instance or N.eventAura.instance
                    N.eventAura=aura
                end
            end
        end
    end
    local added=A.field(info,'addedAuras')
    if type(added)=='table' then
        for _,rawAura in ipairs(added) do
            local aura=A.procRecord(rawAura,false)
            if aura then
                N.eventAura=aura; N.nativeActive=nil; N.eventAdds=N.eventAdds+1
            end
        end
    end
end
-- Independent from Core's spell-reference, enemy and channel callbacks.
-- A native overlay event is explicit proc evidence even if the aura is secret.
function N.read()
    if N.dead then return false,nil,'player-dead' end
    local eventAura=N.readEventAura()
    if eventAura then return true,eventAura,'aura-event' end
    if N.nativeActive==true then return true,nil,'native-event' end
    if N.nativeActive==nil then
        local overlay=C_SpellActivationOverlay and A.call(C_SpellActivationOverlay.IsSpellOverlayed,S.Data.procID)
        if overlay==true then return true,nil,'native-query' end
    end
    -- The native container renders this state without returning it to Lua.
    -- Do not repeatedly call APIs which the client explicitly denies in combat.
    if C_Secrets and A.call(C_Secrets.ShouldSpellAuraBeSecret,S.Data.procID)==true then
        N.auraActive=nil
        return nil,nil,N.nativeReady and 'native-display' or 'aura-restricted'
    end
    local ok,active,aura,source=pcall(A.procAura)
    N.auraReadError=not ok
    if not ok then active=nil; aura=nil end
    if active and aura and aura.expires and GetTime()>=aura.expires then active=false; aura=nil end
    N.auraActive=active
    return active,aura,source or 'aura-unknown'
end
function N.event(_,event,arg,updateInfo)
    if not S.ready then return end
    if event=='PLAYER_ENTERING_WORLD' then
        N.nativeActive=nil; N.eventAura=nil; N.dead=nil; S.procState.active=nil
        S.alertDemoUntil=nil; S.updateProc(true)
    elseif event=='PLAYER_DEAD' then
        N.nativeActive=nil; N.eventAura=nil; N.dead=true; S.alertDemoUntil=nil; S.updateProc(true)
    elseif event=='PLAYER_ALIVE' or event=='PLAYER_UNGHOST' then
        N.dead=nil; S.updateProc(true)
    elseif event=='DISPLAY_SIZE_CHANGED' or event=='UI_SCALE_CHANGED' then
        N.screenW,N.screenH=nil,nil
    elseif event=='UNIT_AURA' then
        if A.public(arg)~='player' then return end
        N.auraEvents=N.auraEvents+1
        N.captureAuraUpdate(updateInfo)
        S.alertDemoUntil=nil; S.updateProc(false)
    else
        -- Never treat a masked ID as the nil payload of a global HIDE.
        if issecretvalue and issecretvalue(arg) then return end
        local id=A.num(arg)
        local show=event=='SPELL_ACTIVATION_OVERLAY_SHOW'
        if id~=S.Data.procID and not (not show and arg==nil) then return end
        if not show and arg==nil then
            -- A global screen-overlay reset is not proof that Shadow Trance ended.
            N.globalHides=N.globalHides+1
            if N.nativeActive~=nil then
                N.nativeActive=nil
                if not S.alertDemoUntil then S.updateProc(true) end
            end
            return
        end
        -- HIDE retires only native evidence, never a separately confirmed buff.
        N.nativeActive=show and true or nil
        N.lastNative=event; N.lastNativeAt=GetTime()
        if show then
            N.nativeShows=N.nativeShows+1
        else N.nativeHides=N.nativeHides+1 end
        S.alertDemoUntil=nil; S.updateProc(false)
    end
end
function N.diagnostics()
    local f=N.frame
    local active,_,source=N.read()
    local function public(value) return tostring(A.public(value)) end
    S.print('Nightfall 0.4.37 | combat='..public(A.combat())..' lastAura='..public(N.auraActive)..
        ' native='..public(N.nativeActive)..' source='..source..' active='..public(active))
    S.print('preview/fallback visual='..public(S.db.enabled and S.db.nightfall and S.db.visual)..
        ' shown='..public(f:IsShown())..' visible='..public(f:IsVisible())..
        ' alpha='..public(f.anchor:GetEffectiveAlpha())..' auraEvents='..N.auraEvents..
        ' show/hide='..N.nativeShows..'/'..N.nativeHides..' auraError='..public(N.auraReadError))
    S.print('lastNative='..(N.lastNative or 'none')..' age='..
        (N.lastNativeAt and string.format('%.1fs',GetTime()-N.lastNativeAt) or 'none'))
    local t=A.procTrace or {}
    local secrecy=C_Secrets and A.call(C_Secrets.GetSpellAuraSecrecy,S.Data.procID)
    S.print('id='..(t.id or '-')..' name='..(t.name or '-')..' scan='..(t.scan or '-')..
        ' aura+/-='..N.eventAdds..'/'..N.eventRemovals..' globalHide='..N.globalHides..
        ' addonSounds='..(N.soundAlerts or 0)..' secrecy='..public(secrecy))
    -- Never query the native slot's visibility/alpha: those belong to the engine.
    S.print('nativeDisplay='..(N.nativeReady and 'ready' or 'unavailable')..
        ' layoutPending='..public(N.nativePending==true)..' state=engine-owned'..
        (N.nativeError and (' error='..N.nativeError) or '')..
        (N.nativeAnimationError and ' animations=static' or ''))
    for _,event in ipairs({'SPELL_ACTIVATION_OVERLAY_SHOW','SPELL_ACTIVATION_OVERLAY_HIDE'}) do
        if S.failedEvents[event] then S.print(event..': '..L.unavailable) end
    end
end
function N.create()
    N.nativeActive=nil; N.nativeShows=0; N.nativeHides=0; N.auraEvents=0
    N.eventAura=nil; N.eventAdds=0; N.eventRemovals=0; N.globalHides=0; N.soundAlerts=0
    -- This frame remains shown while the visual is hidden, so missed UNIT_AURA
    -- events or an error in another addon callback cannot stop proc detection.
    local driver=CreateFrame('Frame'); N.driver=driver
    -- The player's auras only (the handler ignores every other unit).
    if not pcall(driver.RegisterUnitEvent,driver,'UNIT_AURA','player') then
        if not pcall(driver.RegisterEvent,driver,'UNIT_AURA') then S.failedEvents.UNIT_AURA=true end
    end
    for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST',
                          'SPELL_ACTIVATION_OVERLAY_SHOW','SPELL_ACTIVATION_OVERLAY_HIDE',
                          'DISPLAY_SIZE_CHANGED','UI_SCALE_CHANGED'}) do
        if not pcall(driver.RegisterEvent,driver,event) then S.failedEvents[event]=true end
    end
    driver:SetScript('OnEvent',N.event)
    local elapsed=0
    driver:SetScript('OnUpdate',function(_,dt)
        if not S.ready then return end
        if not S.db.enabled or not S.db.nightfall then return end
        elapsed=elapsed+dt; if elapsed<0.1 then return end; elapsed=0
        if S.alertDemoUntil then
            if GetTime()<S.alertDemoUntil then return end
            S.alertDemoUntil=nil; S.updateProc(true)
        else S.updateProc(false) end
    end)
    local f=CreateFrame('Frame',nil,UIParent); N.frame=f
    f:SetAllPoints(); f:SetFrameStrata('HIGH'); f:EnableMouse(false)
    -- Keep this effect independent of enemy/DoT updates, including their errors.
    f:SetScript('OnUpdate',function() N.tick(GetTime()) end)
    N.buildBars(f)
    N.layout(); f:Hide(); return f
end
-- Blades: a dark track, a gradient fill that drains with the proc's remaining
-- time, a bright core and a halo that follow the fill, a spark riding its head.
-- The same geometry serves the preview/public fallback (Lua sets the fill) and
-- the engine-owned slots (the engine drives the fill through SetDurationBar).
local WHITE='Interface\\Buttons\\WHITE8X8'
local function gradient(texture,bottom,top)
    texture:SetColorTexture(1,1,1,1)
    local ok=CreateColor and pcall(texture.SetGradient,texture,'VERTICAL',CreateColor(unpack(bottom)),CreateColor(unpack(top)))
    if not ok then texture:SetVertexColor(top[1],top[2],top[3],top[4]) end
end
local function blade(parent)
    local b=CreateFrame('Frame',nil,parent); b:EnableMouse(false)
    b.track=b:CreateTexture(nil,'BACKGROUND'); b.track:SetAllPoints(); b.track:SetColorTexture(0.10,0.04,0.18,0.55)
    b.fill=CreateFrame('StatusBar',nil,b); b.fill:SetAllPoints(); b.fill:EnableMouse(false)
    b.fill:SetOrientation('VERTICAL'); b.fill:SetStatusBarTexture(WHITE); b.fill:SetMinMaxValues(0,1); b.fill:SetValue(1)
    b.fillTex=b.fill:GetStatusBarTexture()
    gradient(b.fillTex,{0.30,0.06,0.62,1},{0.80,0.52,1,1})
    b.glow=b:CreateTexture(nil,'BACKGROUND',nil,1); b.glow:SetColorTexture(0.62,0.26,1,0.22)
    b.halo=b:CreateTexture(nil,'BACKGROUND',nil,0); b.halo:SetColorTexture(0.55,0.18,1,0.09)
    b.core=b.fill:CreateTexture(nil,'OVERLAY'); b.core:SetColorTexture(1,0.93,1,0.85)
    b.spark=b.fill:CreateTexture(nil,'OVERLAY',nil,1); b.spark:SetColorTexture(1,0.92,1,0.95)
    b.sparkGlow=b.fill:CreateTexture(nil,'OVERLAY',nil,0); b.sparkGlow:SetColorTexture(0.85,0.55,1,0.45)
    b.flare=b:CreateTexture(nil,'OVERLAY',nil,2); b.flare:SetColorTexture(0.95,0.80,1,0.65); b.flare:SetAlpha(0)
    return b
end
local MEDIA='Interface\\AddOns\\'..addon..'\\Media\\'
-- Proc looks. Textured styles use original art from tools/build_proc_textures.py
-- (additive, so dark pixels vanish); the last one is the original gradient blade.
-- Each style fixes its own size and breathing; the bars keep their place.
N.STYLES={
    {key='flame',tex='proc-flame',width=48,height=210,pulse=true},
    {key='runes',tex='proc-runes',width=40,height=210,pulse=true},
    {key='bolt',tex='proc-bolt',width=44,height=220,pulse=true},
    {key='crystal',tex='proc-crystal',width=40,height=200,pulse=false},
    {key='blades',width=12,height=160,pulse=false},
    {key='vortex',tex='proc-vortex',width=44,height=220,pulse=true},
    {key='felfire',tex='proc-felfire',width=48,height=210,pulse=true,glow={0.35,1,0.2,0.55}},
    {key='smoke',tex='proc-smoke',width=56,height=220,pulse=false},
    {key='embers',tex='proc-embers',width=48,height=220,pulse=true},
}
function N.style() return N.STYLES[S.db.procStyle] or N.STYLES[1] end
function N.pulse() return N.style().pulse==true end
local function additive(texture,on) if texture.SetBlendMode then pcall(texture.SetBlendMode,texture,on and 'ADD' or 'BLEND') end end
-- Re-skins an existing blade in place, so the engine-owned slots keep their
-- duration bar binding when the style changes (out of combat only).
local function styleBlade(b,style)
    local textured=style.tex~=nil
    b.track:SetShown(not textured); b.core:SetShown(not textured)
    b.halo:SetShown(not textured); b.sparkGlow:SetShown(not textured)
    if textured then
        b.fill:SetStatusBarTexture(MEDIA..style.tex); b.fillTex=b.fill:GetStatusBarTexture()
        b.fillTex:SetVertexColor(1,1,1,1); additive(b.fillTex,true)
        b.glow:SetTexture(MEDIA..'proc-glow'); b.glow:SetVertexColor(unpack(style.glow or {0.62,0.26,1,0.6})); additive(b.glow,true)
        b.spark:SetTexture(MEDIA..'proc-spark'); b.spark:SetVertexColor(1,0.85,1,1); additive(b.spark,true)
        b.flare:SetTexture(MEDIA..'proc-glow'); b.flare:SetVertexColor(0.9,0.7,1,1); additive(b.flare,true)
    else
        b.fill:SetStatusBarTexture(WHITE); b.fillTex=b.fill:GetStatusBarTexture(); additive(b.fillTex,false)
        gradient(b.fillTex,{0.30,0.06,0.62,1},{0.80,0.52,1,1})
        b.glow:SetColorTexture(0.62,0.26,1,0.22); additive(b.glow,false)
        b.spark:SetColorTexture(1,0.92,1,0.95); additive(b.spark,false)
        b.flare:SetColorTexture(0.95,0.80,1,0.65); additive(b.flare,false)
    end
end
function N.buildBars(f,sides)
    f.anchor=CreateFrame('Frame',nil,f); f.anchor:SetSize(1,1); f.anchor:EnableMouse(false)
    f.bars={}
    for _,side in ipairs(sides or {1,2}) do f.bars[side]=blade(f.anchor) end
end
function N.layoutBars(f)
    local style=N.style()
    local scale=S.db.alertScale; local width,height=style.width,style.height
    -- Keep blades and their halo on screen.
    local gap=math.min(S.db.barGap,math.max(40,UIParent:GetWidth()/scale/2-width*1.6-6))
    local limit=math.max(0,UIParent:GetHeight()/2-(height/2+width*0.4)*scale-4)
    local y=math.max(-limit,math.min(limit,S.db.barY))
    f.anchor:SetScale(scale); f.anchor:ClearAllPoints()
    f.anchor:SetPoint('CENTER',f,'CENTER',0,y/scale)
    for i,b in pairs(f.bars) do
        local side=i==1 and -1 or 1
        styleBlade(b,style)
        b:SetSize(width,height); b:ClearAllPoints(); b:SetPoint('CENTER',f.anchor,'CENTER',side*gap,0)
        -- Halo layers follow the filled part only, so the glow shrinks with the timer.
        b.glow:ClearAllPoints(); b.glow:SetPoint('TOPLEFT',b.fillTex,'TOPLEFT',-width*0.45,width*0.25)
        b.glow:SetPoint('BOTTOMRIGHT',b.fillTex,'BOTTOMRIGHT',width*0.45,-width*0.25)
        b.halo:ClearAllPoints(); b.halo:SetPoint('TOPLEFT',b.fillTex,'TOPLEFT',-width*1.1,width*0.4)
        b.halo:SetPoint('BOTTOMRIGHT',b.fillTex,'BOTTOMRIGHT',width*1.1,-width*0.4)
        local inset=math.max(1,math.floor(width*0.36))
        b.core:ClearAllPoints(); b.core:SetPoint('TOPLEFT',b.fillTex,'TOPLEFT',inset,0); b.core:SetPoint('BOTTOMRIGHT',b.fillTex,'BOTTOMRIGHT',-inset,0)
        b.spark:ClearAllPoints(); b.spark:SetPoint('CENTER',b.fillTex,'TOP',0,0)
        if style.tex then b.spark:SetSize(width*1.5,width*1.5) else b.spark:SetSize(width*1.6,math.max(2,width*0.30)) end
        b.sparkGlow:ClearAllPoints(); b.sparkGlow:SetPoint('CENTER',b.fillTex,'TOP',0,0); b.sparkGlow:SetSize(width*3.2,math.max(4,width*0.9))
        b.flare:ClearAllPoints(); b.flare:SetPoint('TOPLEFT',b,'TOPLEFT',-width*0.6,width*0.6); b.flare:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',width*0.6,-width*0.6)
    end
end
local function nativeError(value)
    value=A.public(value)
    N.nativeError=type(value)=='string' and value:gsub('[\r\n]',' '):sub(1,180) or 'unavailable'
end
local function alphaAnimation(owner,from,to,duration,loop)
    local group=owner:CreateAnimationGroup()
    local alpha=group:CreateAnimation('Alpha')
    alpha:SetFromAlpha(from); alpha:SetToAlpha(to); alpha:SetDuration(duration)
    if loop then group:SetLooping('BOUNCE') else group:SetToFinalAlpha(true) end
    return group
end
-- Engine-played animations: blade arrival, entrance flash, optional breathing glow.
function N.configureNativeAnimations(slot)
    if N.nativeAnimationError then return end
    if slot.nativePulse==N.pulse() then return end
    if not slot.nativeAnimations then
        slot.nativeAnimations={}; slot.nativePulses={}
        for _,bar in pairs(slot.bars) do
            bar.flare:SetAlpha(0)
            slot.nativeAnimations[#slot.nativeAnimations+1]=alphaAnimation(bar,0.35,1,0.18)
            slot.nativeAnimations[#slot.nativeAnimations+1]=alphaAnimation(bar.flare,1,0,0.45)
            slot.nativePulses[#slot.nativePulses+1]=alphaAnimation(bar.glow,0.45,1,0.7,true)
        end
    end
    slot:ClearAuraShownAnimations()
    for _,group in ipairs(slot.nativeAnimations) do
        group:Stop(); slot:AddAuraShownAnimation(group)
    end
    for _,group in ipairs(slot.nativePulses) do
        group:Stop()
        if N.pulse() then slot:AddAuraShownAnimation(group) end
    end
    for _,bar in pairs(slot.bars) do bar.glow:SetAlpha(1) end
    slot.nativePulse=N.pulse()
end
function N.safeNativeAnimations(slot)
    local ok=pcall(N.configureNativeAnimations,slot)
    if not ok then
        -- Cosmetic API differences must not disable an otherwise usable slot.
        N.nativeAnimationError=true
        if slot.ClearAuraShownAnimations then pcall(slot.ClearAuraShownAnimations,slot) end
        for _,groups in ipairs({slot.nativeAnimations or {},slot.nativePulses or {}}) do
            for _,group in ipairs(groups) do pcall(group.Stop,group) end
        end
        slot.anchor:SetAlpha(1)
        for _,bar in pairs(slot.bars) do bar:SetAlpha(1); bar.flare:Hide() end
    end
end
function N.syncNative(demo)
    -- This public host is controlled only by preferences/preview, never by an aura.
    if N.nativeHost then
        local shown=N.nativeReady==true and S.db.enabled and S.db.nightfall and S.db.visual and not demo or false
        if N.hostShown~=shown then N.nativeHost:SetShown(shown); N.hostShown=shown end
    end
    -- The screen size is read again only when the game reports a change.
    if not N.screenW then N.screenW,N.screenH=UIParent:GetWidth(),UIParent:GetHeight() end
    local signature=table.concat({S.db.alertScale,N.style().key,S.db.barGap,S.db.barY,
        S.db.barOpacity,N.screenW,N.screenH},':')
    if N.nativeReady and N.nativeSignature==signature then return end
    if A.combat() or (C_Secrets and A.call(C_Secrets.ShouldAurasBeSecret)==true) then
        N.nativePending=true; return
    end
    if not N.nativeReady then
        if N.nativeAttempted then return end
        N.nativeAttempted=true
        local host=CreateFrame('Frame',nil,UIParent); N.nativeHost=host
        host:SetAllPoints(); host:SetFrameStrata('HIGH'); host:EnableMouse(false); host:Hide()
        local ok,err=pcall(function()
            local container=CreateFrame('AuraContainer',nil,host,'CustomAuraContainerTemplate')
            container:SetAllPoints(); container:EnableMouse(false)
            container:SetUnit('player')
            N.nativeSlots={}
            -- One slot per blade: each owns a duration bar the engine drains
            -- with the proc's own remaining time (secret to Lua).
            for side,key in ipairs({'nightfall','nightfallRight'}) do
                container:AddAuraSlot(key,'HELPFUL',{
                    candidateFilters={includeSpellIDs={[S.Data.procID]=true}},
                    initializeFrame=function(slot)
                        slot:SetAllPoints(container); slot:EnableMouse(false)
                        N.buildBars(slot,{side}); N.layoutBars(slot)
                        local direction=Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
                        slot:SetDurationBar(slot.bars[side].fill,{direction=direction,interpolation=0})
                        N.safeNativeAnimations(slot)
                        N.nativeSlots[side]=slot
                    end,
                })
            end
            assert(N.nativeSlots[1] and N.nativeSlots[2],'Nightfall slot initialization did not run')
            N.nativeSlot=N.nativeSlots[1]; N.nativeContainer=container
        end)
        if not ok then nativeError(err); return end
        N.nativeReady=true
    end
    -- Only out of combat and outside secret-aura restrictions. No OnShow,
    -- OnHide, OnUpdate, visibility readback, or aura callback on the native slots.
    local ok,err=pcall(function()
        for _,slot in ipairs(N.nativeSlots) do N.layoutBars(slot); N.safeNativeAnimations(slot) end
        N.nativeHost:SetAlpha(S.db.barOpacity)
    end)
    if not ok then nativeError(err); N.nativePending=true; return end
    N.nativeSignature=signature; N.nativePending=false; N.nativeError=nil
    N.hostShown=S.db.enabled and S.db.nightfall and S.db.visual and not demo or false
    N.nativeHost:SetShown(N.hostShown)
end
function N.layout()
    if not N.frame then return end
    N.layoutBars(N.frame); N.syncNative(N.frame.demo and S.alertDemoUntil~=nil)
end
function N.show(active,aura,demo)
    local f=N.frame
    N.syncNative(demo==true)
    if N.nativeReady and not demo then active=false end
    if active and not f:IsShown() then f.shownAt=GetTime() end
    f.expires=aura and aura.expires; f.duration=aura and aura.duration; f.demo=demo==true
    f:SetShown(active==true); N.tick(GetTime())
end
-- Public preview/fallback: the fill drains with the known remaining time; an
-- unknown duration stays full rather than inventing a timer.
function N.tick(now)
    local f=N.frame; if not f or not f:IsShown() then return end
    if f.expires and now>=f.expires then f:Hide(); return end
    local elapsed=math.max(0,now-(f.shownAt or now))
    local entrance=0.35+0.65*math.min(1,elapsed/0.18)
    f.anchor:SetAlpha(S.db.barOpacity*entrance)
    local ratio=(f.expires and f.duration and f.duration>0) and math.max(0,math.min(1,(f.expires-now)/f.duration)) or 1
    for _,b in pairs(f.bars) do
        b.fill:SetValue(ratio)
        b.flare:SetAlpha(math.max(0,1-elapsed/0.45))
        b.glow:SetAlpha(N.pulse() and (0.725+0.275*math.sin(now*math.pi/0.7)) or 1)
    end
end
