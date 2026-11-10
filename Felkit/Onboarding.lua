-- First-launch assistant. Shown once per account (FelkitDB.onboarded),
-- out of combat, after the world has loaded. Choices are drafted locally and
-- written to the settings only on Finish. Closing it counts as "keep defaults";
-- /fk setup reopens it at any time.
local _,S=...
local O={}; S.Onboarding=O
local T,A=S.Theme,S.API
local L
local W,H=720,560
local STEPS={'welcome','features','tune','done'}
O.FEATURES={
    {key='enemies',icon=T.I.dots},{key='kit',icon=T.I.kit},{key='shards',icon=T.I.shards},
    {key='nightfall',icon=T.I.nightfall},{key='channels',icon=T.I.channels},{key='grimoire',icon=T.I.grimoire},
}
local function readDraft()
    local d=S.db
    return {enemies=d.enemies,kit=d.kit.enabled,shards=d.shards,nightfall=d.nightfall,channels=d.channels,
        grimoire=d.grimoire,dotLayout=d.dotLayout,enemyStyle=d.enemyStyle,keep=d.keep,autoShards=d.autoShards,
        compact=d.compact,sound=d.sound,visual=d.visual,minimap=d.minimap,scale=math.floor(d.scale*100+0.5),language=d.language}
end
local function applyDraft(c)
    local d=S.db
    d.enemies=c.enemies; d.kit.enabled=c.kit; d.shards=c.shards; d.nightfall=c.nightfall; d.channels=c.channels
    d.grimoire=c.grimoire; d.spellDetails=c.grimoire; d.spellTooltips=c.grimoire
    d.dotLayout=c.dotLayout; d.enemyStyle=c.enemyStyle; d.keep=c.keep; d.autoShards=c.autoShards
    d.compact=c.compact; d.sound=c.sound; d.visual=c.visual; d.minimap=c.minimap; d.scale=c.scale/100
    d.shardRefused={}
end
O.applyDraft=applyDraft
local function draftBool(key) return function() return O.draft[key]==true end,function(v) O.draft[key]=v==true; O.sync() end end
local function draftValue(key) return function() return O.draft[key] end,function(v) O.draft[key]=v; O.sync() end end
local function stepFrame(parent)
    local f=CreateFrame('Frame',nil,parent); f:SetPoint('TOPLEFT',28,-86); f:SetPoint('BOTTOMRIGHT',-28,64); f:Hide()
    return f
end
-- The language applies at once: S.L is refilled and this window is rebuilt in
-- the new language, keeping the draft and the current step.
function O.setLanguage(code)
    if A.combat() then S.print(L.combat); return end
    O.draft.language=code; S.db.language=code; S.applyLocale(code)
    if not O.frame then return end
    O.rebuilding=true; O.frame:Hide(); O.rebuilding=nil
    O.build(); O.sync(); O.frame:Show()
end
local function buildLanguage(f)
    local icon=T.badge(f,T.I.tongues,64); icon:SetPoint('TOPLEFT',0,-6)
    local title=T.text(f,22); title:SetPoint('TOPLEFT',84,-8); title:SetWidth(W-150); title:SetText(L.setupLanguageTitle)
    local body=T.text(f,13,T.c.muted); body:SetPoint('TOPLEFT',84,-42); body:SetWidth(W-150); body:SetWordWrap(true)
    body:SetText(L.setupLanguageBody)
    O.languageGrid=T.languageGrid(f,W-56,function() return O.draft.language end,function(code) O.setLanguage(code) end,3,56)
    O.languageGrid:SetPoint('TOPLEFT',0,-118)
end
local function buildWelcome(f)
    local icon=T.logo(f,64); icon:SetPoint('TOPLEFT',0,-6)
    local title=T.text(f,22); title:SetPoint('TOPLEFT',84,-8); title:SetWidth(W-150); title:SetText(L.setupWelcomeTitle)
    local body=T.text(f,13,T.c.muted); body:SetPoint('TOPLEFT',84,-42); body:SetWidth(W-150); body:SetWordWrap(true)
    body:SetText(L.setupWelcomeBody)
    local y=-130
    local points={{'One',T.I.kit},{'Two',T.I.timer},{'Three',T.I.general}}
    for i,p in ipairs(points) do
        local k=p[1]
        local row=CreateFrame('Frame',nil,f); row:SetSize(W-56,64); row:SetPoint('TOPLEFT',0,y-(i-1)*74)
        T.skin(row,T.c.card,T.c.lineSoft)
        local stripe=row:CreateTexture(nil,'ARTWORK'); stripe:SetPoint('TOPLEFT',1,-1); stripe:SetPoint('BOTTOMLEFT',1,1); stripe:SetWidth(2)
        stripe:SetColorTexture(T.rgb(T.c.accent))
        local n=T.text(row,18,T.c.accent); n:SetPoint('LEFT',16,0); n:SetText(tostring(i))
        local badge=T.badge(row,p[2],40); badge:SetPoint('LEFT',40,0)
        local t=T.text(row,13); t:SetPoint('TOPLEFT',94,-13); t:SetWidth(W-170); t:SetText(L['setupPoint'..k])
        local d=T.text(row,11,T.c.muted); d:SetPoint('TOPLEFT',94,-33); d:SetWidth(W-170); d:SetText(L['setupPoint'..k..'Help'])
    end
end
local function buildFeatures(f)
    local intro=T.text(f,13,T.c.muted); intro:SetPoint('TOPLEFT',0,0); intro:SetWidth(W-56); intro:SetWordWrap(true)
    intro:SetText(L.setupFeaturesIntro)
    O.tiles={}
    local tileW=math.floor((W-56-14)/2); local tileH=104
    for i,feature in ipairs(O.FEATURES) do
        local key=feature.key
        local t=CreateFrame('Button',nil,f); t:SetSize(tileW,tileH)
        t:SetPoint('TOPLEFT',((i-1)%2)*(tileW+14),-40-math.floor((i-1)/2)*(tileH+12))
        T.skin(t,T.c.card,T.c.lineSoft)
        t.badge=T.badge(t,feature.icon,42); t.badge:SetPoint('TOPLEFT',14,-14); t.icon=t.badge.icon
        t.title=T.text(t,14); t.title:SetPoint('TOPLEFT',68,-15); t.title:SetWidth(tileW-136); t.title:SetText(L['nav_'..key])
        t.desc=T.text(t,11,T.c.muted); t.desc:SetPoint('TOPLEFT',68,-37); t.desc:SetWidth(tileW-82); t.desc:SetWordWrap(true)
        t.desc:SetText(L['setupFeature_'..key])
        local get,set=draftBool(key)
        t.switch=T.switch(t,get,set); t.switch:SetPoint('TOPRIGHT',-14,-14)
        t:SetScript('OnClick',function() t.switch:Click() end)
        t.key=key; O.tiles[key]=t
    end
end
local function buildTune(f)
    O.tuneScroll,O.tuneChild=T.scroll(f,W-46,H-86-64)
    O.tuneScroll:SetPoint('TOPLEFT',0,0)
    local width=W-66
    O.tuneCards={}; O.tuneControls={}
    local function card(title,sub,visible,icon) local c=T.card(O.tuneChild,width,title,sub,icon); c.visible=visible; O.tuneCards[#O.tuneCards+1]=c; return c end
    local function add(c,control) c:Add(control,nil,8); O.tuneControls[#O.tuneControls+1]=control; return control end
    local I=T.I
    local dots=card(L.nav_enemies,L.setupTuneDots,function() return S.legacyEnemies and O.draft.enemies end,I.dots)
    local g1,s1=draftValue('dotLayout')
    add(dots,T.segmented(dots,dots.inner,{{value=1,label=L.dotLayout1,glyph='bars'},{value=2,label=L.dotLayout2,glyph='icons'}},g1,s1,30))
    local g2,s2=draftValue('enemyStyle')
    add(dots,T.segmented(dots,dots.inner,{{value=1,label=L.enemyStyle1,glyph='cards'},{value=2,label=L.enemyStyle2,glyph='compact'},{value=3,label=L.enemyStyle3,glyph='clean'}},g2,s2,30))
    local shards=card(L.nav_shards,L.setupTuneShards,function() return O.draft.shards end,I.shards)
    local gk,sk=draftValue('keep')
    add(shards,T.slider(shards,shards.inner,L.keep,0,80,1,gk,sk,nil,I.bag))
    local ga,sa=draftBool('autoShards'); add(shards,T.toggleRow(shards,shards.inner,L.autoShards,L.setupAutoHelp,ga,sa,I.burn))
    local gc,sc=draftBool('compact'); add(shards,T.toggleRow(shards,shards.inner,L.compact,nil,gc,sc,I.shards))
    local proc=card(L.nav_nightfall,L.setupTuneNightfall,function() return O.draft.nightfall end,I.nightfall)
    local gv,sv=draftBool('visual'); add(proc,T.toggleRow(proc,proc.inner,L.visual,nil,gv,sv,I.proc))
    local gs,ss=draftBool('sound'); add(proc,T.toggleRow(proc,proc.inner,L.sound,nil,gs,ss,I.sound))
    local ui=card(L.setupTuneInterface,nil,nil,I.general)
    local gm,sm=draftBool('minimap'); add(ui,T.toggleRow(ui,ui.inner,L.minimap,nil,gm,sm,I.map))
    local getScale,setScale=draftValue('scale')
    add(ui,T.slider(ui,ui.inner,L.scale,65,160,5,getScale,setScale,function(v) return v..' %' end,I.size))
end
local function buildDone(f)
    local title=T.text(f,20); title:SetPoint('TOPLEFT',0,-4); title:SetText(L.setupDoneTitle)
    local body=T.text(f,12,T.c.muted); body:SetPoint('TOPLEFT',0,-36); body:SetWidth(W-56); body:SetWordWrap(true); body:SetText(L.setupDoneBody)
    O.summary={}
    for i,feature in ipairs(O.FEATURES) do
        local row=CreateFrame('Frame',nil,f); row:SetSize(W-56,34); row:SetPoint('TOPLEFT',0,-84-(i-1)*38)
        T.skin(row,T.c.card,T.c.lineSoft)
        row.badge=T.badge(row,feature.icon,26); row.badge:SetPoint('LEFT',6,0); row.icon=row.badge.icon
        row.name=T.text(row,12); row.name:SetPoint('LEFT',row.badge,'RIGHT',10,0); row.name:SetText(L['nav_'..feature.key])
        row.state=T.text(row,11); row.state:SetPoint('RIGHT',-12,0); row.state:SetJustifyH('RIGHT')
        O.summary[feature.key]=row
    end
    local tip=T.text(f,11,T.c.gold); tip:SetPoint('TOPLEFT',0,-84-#O.FEATURES*38-8); tip:SetWidth(W-56); tip:SetWordWrap(true)
    tip:SetText(L.setupTip)
    -- Frames built before the language change keep their texts until a reload.
    O.reloadRow=CreateFrame('Frame',nil,f); O.reloadRow:SetSize(W-56,40); O.reloadRow:SetPoint('BOTTOMLEFT',0,0)
    T.skin(O.reloadRow,T.c.card,T.c.accentDim)
    local hint=T.text(O.reloadRow,11,T.c.muted); hint:SetPoint('LEFT',12,0); hint:SetWidth(W-56-230); hint:SetWordWrap(true)
    hint:SetText(L.languageReloadHint)
    O.reload=T.button(O.reloadRow,L.languageReload,190,28,function() O.finish(false); if ReloadUI then ReloadUI() end end,'secondary',T.I.reset)
    O.reload:SetPoint('RIGHT',-6,0)
end
function O.build()
    L=S.L
    local f=T.window('FelkitSetup',W,H,L.setupTitle); O.frame=f
    f:SetFrameStrata('FULLSCREEN_DIALOG'); f:Hide()
    f.titleBar:SetScript('OnDragStart',function() if not InCombatLockdown() then f:StartMoving() end end)
    O.progress={}
    local segW=math.floor((W-56-(#STEPS-1)*8)/#STEPS)
    for i,key in ipairs(STEPS) do
        local seg=f:CreateTexture(nil,'ARTWORK'); seg:SetSize(segW,4); seg:SetPoint('TOPLEFT',28+(i-1)*(segW+8),-50)
        local cap=T.text(f,10,T.c.faint); cap:SetPoint('TOPLEFT',28+(i-1)*(segW+8),-60); cap:SetText(L['setupStep_'..key])
        O.progress[i]={bar=seg,caption=cap}
    end
    O.steps={}
    for _,key in ipairs(STEPS) do O.steps[key]=stepFrame(f) end
    buildWelcome(O.steps.welcome); buildFeatures(O.steps.features); buildTune(O.steps.tune); buildDone(O.steps.done)
    local footer=CreateFrame('Frame',nil,f); footer:SetPoint('BOTTOMLEFT',1,1); footer:SetPoint('BOTTOMRIGHT',-1,1); footer:SetHeight(56)
    T.skin(footer,T.c.side,T.c.line)
    O.back=T.button(footer,'‹  '..L.setupBack,120,30,function() O.go(O.index-1) end,'ghost'); O.back:SetPoint('LEFT',24,0)
    O.skip=T.button(footer,L.setupSkip,170,30,function() O.skipAll() end,'ghost'); O.skip:SetPoint('LEFT',O.back,'RIGHT',8,0)
    O.next=T.button(footer,L.setupNext,170,30,function() O.forward() end,'primary'); O.next:SetPoint('RIGHT',-24,0)
    O.openSettings=T.button(footer,L.setupFinishOpen,230,30,function() O.finish(true) end,'secondary',T.I.general); O.openSettings:SetPoint('RIGHT',O.next,'LEFT',-8,0)
    f:SetScript('OnHide',function()
        -- Closing without finishing keeps the current settings; never show again automatically.
        if not O.finished and S.db and not O.rebuilding then
            S.db.onboarded=true
            if not O.silentHide then S.print(L.setupSkipped) end
        end
        O.silentHide=nil
    end)
end
function O.sync()
    if not O.frame then return end
    local key=STEPS[O.index]
    for i,p in ipairs(O.progress) do
        p.bar:SetColorTexture(T.rgb(i<=O.index and T.c.accent or T.c.track))
        p.caption:SetTextColor(T.rgb(i==O.index and T.c.text or T.c.faint))
    end
    for k,f in pairs(O.steps) do f:SetShown(k==key) end
    for _,t in pairs(O.tiles) do
        t.switch:Sync()
        T.paint(t,t.switch.on and T.c.raised or T.c.card,t.switch.on and T.c.accent or T.c.lineSoft)
        t.badge:SetLit(t.switch.on)
    end
    for _,c in ipairs(O.tuneControls) do c:Sync() end
    if O.languageGrid then O.languageGrid:Sync() end
    O.reloadRow:SetShown(false)
    local y=0
    for _,c in ipairs(O.tuneCards) do
        local v=not c.visible or c.visible(); c:SetShown(v)
        if v then c:ClearAllPoints(); c:SetPoint('TOPLEFT',O.tuneChild,'TOPLEFT',0,y); y=y-c:GetHeight()-12 end
    end
    O.tuneScroll:SetContentHeight(-y)
    for k,row in pairs(O.summary) do
        local on=O.draft[k]==true
        row.state:SetText(on and L.moduleOn or L.moduleOff)
        row.state:SetTextColor(T.rgb(on and T.c.fel or T.c.faint)); row.badge:SetLit(on)
    end
    O.back:SetShown(O.index>1)
    O.skip:SetShown(O.index<#STEPS)
    O.openSettings:SetShown(key=='done')
    O.next:SetLabel(key=='done' and L.setupFinish or (key=='welcome' and L.setupStart or L.setupNext))
end
function O.go(index)
    O.index=math.max(1,math.min(#STEPS,index)); O.sync()
    if STEPS[O.index]=='tune' then O.tuneScroll:ScrollTo(0) end
end
function O.forward()
    if O.index>=#STEPS then O.finish(false) else O.go(O.index+1) end
end
function O.finish(openSettings)
    if A.combat() then S.print(L.combat); return end
    applyDraft(O.draft)
    S.db.onboarded=true; O.finished=true
    O.frame:Hide()
    S.refreshAll()
    S.print(L.setupDone)
    if openSettings then S.Options.open('home') end
end
-- "Skip" keeps the current/default settings and closes the assistant.
function O.skipAll() O.frame:Hide() end
function O.open(force)
    if not S.ready then return end
    if A.combat() then if force then S.print(L.combat) end; return end
    O.draft=readDraft(); O.finished=false; O.index=1
    if not O.frame then O.build() end
    O.sync(); O.frame:Show()
end
-- Called after login, reload and leaving combat. Only the very first launch.
function O.maybeShow()
    if not S.ready or not S.db or S.db.onboarded or O.pending or (O.frame and O.frame:IsShown()) then return end
    if A.combat() then return end
    local function show()
        O.pending=nil
        if not S.db.onboarded and not A.combat() then O.open() end
    end
    if C_Timer and C_Timer.After then O.pending=true; C_Timer.After(1.5,show) else show() end
end
