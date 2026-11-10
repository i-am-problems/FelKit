-- Settings window: grouped sidebar, one page per module, illustrated cards of
-- controls. Every control reads S.db on Sync and writes through S.refreshAll().
local addon,S=...
local O={controls={},pages={}}; S.Options=O
local T,A=S.Theme,S.API
local I=T.I
local L
local W,H,SIDE=900,620,214
local CONTENT_W=W-SIDE-1
local PAGE_W=CONTENT_W-46
local HEADER_H=82
local function apply() S.refreshAll() end
-- Icons of individual controls, by setting key. Only where the art fits.
local ICON={
    preview=I.eye, enemiesCombatOnly=I.reveal, dotTargetFirst=I.target, dotMarkers=I.pet, maxEnemies=I.crowd,
    dotTicks=I.ticks, dotWarnings=I.warning, dotChannels=I.drain, dotHealth=I.health, enemyNameHeader=I.tongues,
    enemyLocked=I.lock, dotAuto=I.clock, dotPredict=I.timer, dotConfirmedOnly=I.target,
    compact=I.shards, autoShards=I.burn, sound=I.sound, visual=I.proc,
    tickMarks=I.ticks, locked=I.lock, minimap=I.map, scale=I.size, opacity=I.opacity,
    grimoire=I.grimoire, spellDetails=I.book, spellTooltips=I.note, ['kit.hideUnknown']=I.reveal,
}
-- Setting accessors ---------------------------------------------------------
-- Accessors are {get,set} pairs: a multi-value call in the middle of an
-- argument list would be truncated to its first value by Lua.
local function bool(key)
    return {function() return S.db[key]==true end,
        function(v) S.db[key]=v==true; if key=='autoShards' then S.db.shardRefused={} end; apply() end}
end
local function kitBool(key)
    return {function() return S.db.kit[key]==true end,function(v) S.db.kit[key]=v==true; apply() end}
end
local function value(key) return {function() return S.db[key] end,function(v) S.db[key]=v; apply() end} end
local function kitValue(key) return {function() return S.db.kit[key] end,function(v) S.db.kit[key]=v; apply() end} end
local function scaled(key,mult,kit)
    return {function() local t=kit and S.db.kit or S.db; return math.floor(t[key]*mult+0.5) end,
        function(v) local t=kit and S.db.kit or S.db; t[key]=v/mult; apply() end}
end
local function px(v) return v..' px' end
local function pct(v) return v..' %' end
local function sec(v) return v..' s' end
-- Page / section / control factories ------------------------------------------
local function register(page,key,control,when)
    control.when=when; page.controls[#page.controls+1]=control
    if key then O.controls[key]=control end
    return control
end
local function newSection(page,key)
    local s=CreateFrame('Frame',nil,page.child); s:SetPoint('TOPLEFT',0,0); s:SetSize(PAGE_W,10)
    s.cards={}; page.sections[key]=s; page.order[#page.order+1]=key
    function s:Card(title,sub,visible,icon)
        local c=T.card(self,PAGE_W,title,sub,icon); c.visible=visible; self.cards[#self.cards+1]=c; return c
    end
    function s:Layout()
        local y=0
        for _,c in ipairs(self.cards) do
            local v=not c.visible or c.visible()
            c:SetShown(v)
            if v then c:ClearAllPoints(); c:SetPoint('TOPLEFT',self,'TOPLEFT',0,y); y=y-c:GetHeight()-12 end
        end
        self.height=-y; self:SetHeight(math.max(10,-y)); return -y
    end
    return s
end
local function toggle(page,card,key,title,help,acc,when)
    local r=T.toggleRow(card,card.inner,title,help,acc[1],acc[2],ICON[key]); card:Add(r,nil,8)
    return register(page,key,r,when)
end
local function slider(page,card,key,title,lo,hi,step,acc,fmt,when)
    local r=T.slider(card,card.inner,title,lo,hi,step,acc[1],acc[2],fmt,ICON[key]); card:Add(r,nil,8)
    return register(page,key,r,when)
end
local function segment(page,card,key,title,options,acc,when)
    if title then
        local t=T.text(card,12); t:SetText(title); t:SetWidth(card.inner); card:Add(t,t:GetStringHeight(),6)
    end
    local g=T.segmented(card,card.inner,options,acc[1],acc[2],30); card:Add(g,nil,10)
    return register(page,key,g,when)
end
local function buttonRow(page,card,list)
    local row=CreateFrame('Frame',nil,card); row:SetSize(card.inner,28)
    local x=0; local out={}
    for _,b in ipairs(list) do
        local w=b.w or math.floor((card.inner-(#list-1)*8)/#list)
        local btn=T.button(row,b.label,w,28,b.fn,b.kind,b.icon); btn:SetPoint('TOPLEFT',x,0); x=x+w+8
        if b.key then O.controls[b.key]=btn end
        if b.when or b.label_fn then
            local control={Sync=function() if b.label_fn then btn:SetLabel(b.label_fn()) end
                if b.when then btn:SetActive(b.when()) end end}
            page.controls[#page.controls+1]=control
        end
        out[#out+1]=btn
    end
    card:Add(row,28,10); return out
end
local function input(parent,width)
    local e=CreateFrame('EditBox',nil,parent); e:SetSize(width,24); e:SetAutoFocus(false); e:EnableMouse(true)
    T.skin(e,T.c.bg,T.c.line); e:SetFont(T.font(),12,''); e:SetTextColor(T.rgb(T.c.text))
    if e.SetTextInsets then e:SetTextInsets(8,8,0,0) end
    e:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    e:SetScript('OnEditFocusGained',function(self) T.paint(self,nil,T.c.accent) end)
    e:SetScript('OnEditFocusLost',function(self) T.paint(self,nil,T.c.line) end)
    return e
end
O.input=input
-- A status line with its own icon: used by the home health checks.
local function statusLine(card,icon)
    local row=CreateFrame('Frame',nil,card); row:SetSize(card.inner,24)
    row.badge=T.badge(row,icon,22); row.badge:SetPoint('LEFT',0,0)
    row.text=T.text(row,12); row.text:SetPoint('LEFT',row.badge,'RIGHT',10,0); row.text:SetWidth(card.inner-34)
    row.text:SetWordWrap(false)
    card:Add(row,24,6); return row
end
local function newPage(def)
    local page={key=def.key,controls={},sections={},order={},def=def}
    local f=CreateFrame('Frame',nil,O.content); f:SetAllPoints(O.content); f:Hide(); page.frame=f
    page.badge=T.badge(f,def.icon,44); page.badge:SetPoint('TOPLEFT',24,-18)
    page.title=T.text(f,20,T.c.text); page.title:SetPoint('TOPLEFT',80,-20); page.title:SetText(L['nav_'..def.key])
    page.desc=T.text(f,11,T.c.muted); page.desc:SetPoint('TOPLEFT',80,-46); page.desc:SetWidth(PAGE_W-56-190)
    page.desc:SetText(L['navDesc_'..def.key] or ''); page.desc:SetWordWrap(true)
    if def.master then
        local acc=def.master(); local get,set=acc[1],acc[2]
        page.masterLabel=T.text(f,11,T.c.muted); page.masterLabel:SetJustifyH('RIGHT')
        page.master=T.switch(f,get,set); page.master:SetPoint('TOPRIGHT',-26,-22)
        page.masterLabel:SetPoint('RIGHT',page.master,'LEFT',-8,0)
        register(page,'master_'..def.key,page.master)
        page.controls[#page.controls+1]={Sync=function()
            page.masterLabel:SetText(page.master.on and L.moduleOn or L.moduleOff)
            page.masterLabel:SetTextColor(T.rgb(page.master.on and T.c.fel or T.c.faint))
            page.badge:SetLit(page.master.on) end}
    end
    if def.preview then
        -- Test bars stay one click away on every tab of the page.
        local function active() return S.legacyEnemies and S.previewOn or
            (not S.legacyEnemies and S.WH.MultiTarget.PreviewActive()) end
        local b=T.button(f,L.previewHeaderOff,170,24,function()
            if S.legacyEnemies then S.setPreview(not S.previewOn)
            else S.WH.MultiTarget.SetPreview(not active()); O.refresh() end
        end,'secondary',I.eye)
        b:SetPoint('TOPRIGHT',-26,-50); O.controls.previewHeader=b
        page.controls[#page.controls+1]={Sync=function()
            b.kind=active() and 'primary' or 'secondary'
            b:SetLabel(active() and L.previewHeaderOn or L.previewHeaderOff); b:SetActive(not A.combat() and S.db.enabled and S.db.enemies) end}
    end
    local top=HEADER_H
    if def.tabs then
        local opts={}
        for _,k in ipairs(def.tabs) do opts[#opts+1]={value=k,label=L['tab_'..def.key..'_'..k],icon=def.tabIcons and def.tabIcons[k]} end
        page.tab=def.tabs[1]
        page.tabs=T.segmented(f,PAGE_W,opts,function() return page.tab end,function(v) O.showTab(page,v) end,32)
        page.tabs:SetPoint('TOPLEFT',24,-top); top=top+42
        O.controls['tabs_'..def.key]=page.tabs
    end
    local rule=T.rule(f,CONTENT_W-48); rule:SetPoint('TOPLEFT',24,-(top-8))
    page.scroll,page.child=T.scroll(f,PAGE_W+10,H-36-top-14)
    page.scroll:SetPoint('TOPLEFT',24,-top)
    page.top=top
    O.pages[def.key]=page
    return page
end
function O.showTab(page,key)
    page.tab=key
    for k,s in pairs(page.sections) do s:SetShown(k==key) end
    if page.tabs then page.tabs:Sync() end
    O.syncPage(page); page.scroll:ScrollTo(0)
end
function O.syncPage(page)
    if not page then return end
    for _,c in ipairs(page.controls) do
        if c.when and c.SetActive then c:SetActive(c.when()==true) end
        if c.Sync then c:Sync() end
    end
    if page.def.sync then page.def.sync(page) end
    local s=page.sections[page.tab or page.order[1]]
    if s then
        for k,other in pairs(page.sections) do other:SetShown(other==s) end
        page.scroll:SetContentHeight(s:Layout()+8)
    end
end
-- Page builders ------------------------------------------------------------------
local B={}
local MODULES={
    {key='enemies',icon=I.dots,acc=function() return bool('enemies') end},
    {key='kit',icon=I.kit,acc=function() return kitBool('enabled') end},
    {key='shards',icon=I.shards,acc=function() return bool('shards') end},
    {key='nightfall',icon=I.nightfall,acc=function() return bool('nightfall') end},
    {key='grimoire',icon=I.grimoire,acc=function() return bool('grimoire') end},
    {key='channels',icon=I.channels,acc=function() return bool('channels') end},
}
function B.home(page)
    local s=newSection(page,'main')
    local hero=s:Card(L.homeTitle,L.homeIntro,nil,I.seal)
    page.status=T.text(hero,12,T.c.gold); page.status:SetWidth(hero.inner); hero:Add(page.status,16,10)
    buttonRow(page,hero,{
        {label=L.demo,fn=function() S.demo() end,kind='primary',icon=I.eye},
        {label=L.unlockFrames,label_fn=function() return S.db.locked and L.unlockFrames or L.lockFrames end,icon=I.lock,
            fn=function() S.db.locked=not S.db.locked; S.db.enemyLocked=S.db.locked; apply() end},
    })
    -- One line per module: icon, name and switch. The row opens the module page.
    local grid=s:Card(L.homeModules,nil,nil,I.general)
    local tileW=math.floor((grid.inner-12)/2); local tileH=48
    local holder=CreateFrame('Frame',nil,grid); holder:SetSize(grid.inner,math.ceil(#MODULES/2)*(tileH+10)-10)
    for i,m in ipairs(MODULES) do
        local acc=m.acc(); local get,set=acc[1],acc[2]
        local t=CreateFrame('Button',nil,holder); t:SetSize(tileW,tileH)
        t:SetPoint('TOPLEFT',((i-1)%2)*(tileW+12),-math.floor((i-1)/2)*(tileH+10))
        T.skin(t,T.c.bg,T.c.lineSoft)
        local badge=T.badge(t,m.icon,30); badge:SetPoint('LEFT',9,0)
        local title=T.text(t,13); title:SetPoint('LEFT',48,0); title:SetWidth(tileW-110); title:SetText(L['nav_'..m.key])
        local sw=T.switch(t,get,set); sw:SetPoint('RIGHT',-10,0)
        t:SetScript('OnClick',function() O.open(m.key) end)
        t:SetScript('OnEnter',function() t.hot=true; O.syncPage(page) end)
        t:SetScript('OnLeave',function() t.hot=false; O.syncPage(page) end)
        register(page,'tile_'..m.key,sw)
        page.controls[#page.controls+1]={Sync=function()
            T.paint(t,t.hot and T.c.raised or T.c.bg,sw.on and T.c.accentDim or T.c.lineSoft); badge:SetLit(sw.on)
            title:SetTextColor(T.rgb(sw.on and T.c.text or T.c.muted)) end}
    end
    grid:Add(holder,nil,4)
end
function O.syncHome(page)
    local on,total=0,0
    for _,v in ipairs({S.db.enemies,S.db.kit.enabled,S.db.shards,S.db.nightfall,S.db.grimoire,S.db.channels}) do
        total=total+1; if v then on=on+1 end
    end
    page.status:SetText(S.db.enabled and string.format(L.homeStatus,on,total) or L.homeDisabled)
end
-- Read-only module states, shown in General > Help.
local function syncHealth(page)
    local N=S.NativeDots
    local mt=not S.legacyEnemies and S.WH and S.WH.MultiTarget
    if mt then
        local built,failed=mt.State()
        page.health.dots:SetText(L.healthDots..'  '..(failed and ('|cfff46454'..L.stateError..'|r') or
            built and ('|cff79e063'..L.stateReady..'|r') or ('|cffaea7c3'..L.stateIdle..'|r')))
    else
    page.health.dots:SetText(L.healthDots..'  '..(N.failed and ('|cfff46454'..L.stateError..'|r') or N.active and ('|cff79e063'..L.stateReady..'|r') or ('|cffaea7c3'..L.stateIdle..'|r'))..
        (N.error and N.failed and ('  ·  '..N.error) or ''))
    end
    local nf=S.Nightfall
    page.health.nightfall:SetText(L.healthNightfall..'  '..(nf.nativeReady and ('|cff79e063'..L.stateReady..'|r') or ('|cffaea7c3'..L.stateFallback..'|r')))
    page.health.shards:SetText(L.healthShards..'  '..(S.UI.countString or L.loading))
end
local previewAcc={function() return S.previewOn==true end,function(v) S.setPreview(v) end}
function B.enemiesLegacy(page)
    local display=newSection(page,'display')
    local test=display:Card(L.cardPreviewBars,L.cardPreviewBarsHelp,nil,I.eye)
    toggle(page,test,'preview',L.previewToggle,nil,previewAcc,function() return not A.combat() end)
    buttonRow(page,test,{{label=L.demo,fn=function() S.demo() end,icon=I.timer}})
    local who=display:Card(L.cardWho,L.cardWhoHelp,nil,I.reveal)
    toggle(page,who,'enemiesCombatOnly',L.enemiesEngagedOnly,L.enemiesEngagedOnlyHelp,bool('enemiesCombatOnly'))
    page.plates=who:Note('')
    buttonRow(page,who,{{label=L.platesShowAll,key='platesShowAll',icon=I.reveal,fn=function()
        if A.combat() then S.print(L.combat); return end
        pcall(SetCVar,'nameplateShowEnemies','1'); pcall(SetCVar,'nameplateShowAll','1'); S.print(L.platesShowAllDone); O.refresh()
    end,when=function() return not A.combat() end}})
    slider(page,who,'maxEnemies',L.maxEnemies,1,12,1,value('maxEnemies'))
    local order=display:Card(L.cardOrder,L.cardOrderHelp,nil,I.target)
    toggle(page,order,'dotTargetFirst',L.dotTargetFirst,nil,bool('dotTargetFirst'))
    toggle(page,order,'dotMarkers',L.dotMarkers,nil,bool('dotMarkers'))
    local look=display:Card(L.cardStyle,L.cardStyleHelp,nil,I.style)
    segment(page,look,'enemyStyle',nil,{{value=1,label=L.enemyStyle1,glyph='cards'},{value=2,label=L.enemyStyle2,glyph='compact'},
        {value=3,label=L.enemyStyle3,glyph='clean'}},value('enemyStyle'))
    toggle(page,look,'enemyBorder',L.enemyBorder,nil,bool('enemyBorder'))
    toggle(page,look,'enemyBackground',L.enemyBackground,nil,bool('enemyBackground'))
    toggle(page,look,'dotSelectionFrame',L.dotSelectionFrame,nil,bool('dotSelectionFrame'),function() return S.db.enemyBorder end)

    local timers=newSection(page,'timers')
    local lay=timers:Card(L.cardDotLayout,L.cardDotLayoutHelp,nil,I.timer)
    segment(page,lay,'dotLayout',nil,{{value=1,label=L.dotLayout1,tip=L.dotLayout1Help,glyph='bars'},
        {value=2,label=L.dotLayout2,tip=L.dotLayout2Help,glyph='icons'}},value('dotLayout'))
    segment(page,lay,'dotDurationMode',L.dotDurationMode,{{value=1,label=L.dotDurationMode1,glyph='same'},
        {value=2,label=L.dotDurationMode2,glyph='proportional'}},value('dotDurationMode'),function() return S.db.dotLayout~=2 end)
    slider(page,lay,'dotSlots',L.dotSlots,1,10,1,value('dotSlots'))
    slider(page,lay,'rowHeight',L.rowHeight,10,36,1,value('rowHeight'),px)
    slider(page,lay,'fontSize',L.fontSize,8,18,1,value('fontSize'),px)
    local ticks=timers:Card(L.cardTicksStyle,L.dotTicksNativeHelp,nil,I.ticks)
    local tickOn=function() return S.db.dotTicks and S.db.dotLayout~=2 end
    toggle(page,ticks,'dotTicks',L.dotTicksNative,nil,bool('dotTicks'),function() return S.db.dotLayout~=2 end)
    segment(page,ticks,'tickColor',L.tickColor,{{value=1,label=L.tickColor1,swatch={1,1,1}},{value=2,label=L.tickColor2,swatch={1,0.82,0.3}},
        {value=3,label=L.tickColor3,swatch={0,0,0}},{value=4,label=L.tickColor4,swatch={0.75,0.55,1}}},value('tickColor'),tickOn)
    slider(page,ticks,'tickAlpha',L.tickAlpha,10,100,5,value('tickAlpha'),pct,tickOn)
    slider(page,ticks,'tickWidth',L.tickWidth,1,3,1,value('tickWidth'),px,tickOn)
    local warn=timers:Card(L.cardWarning,L.cardWarningHelp,nil,I.warning)
    toggle(page,warn,'dotWarnings',L.dotWarnings,nil,bool('dotWarnings'))
    toggle(page,warn,'dotPulse',L.dotPulse,nil,bool('dotPulse'),function() return S.db.dotWarnings end)
    slider(page,warn,'dotWarning',L.dotWarning,1,10,1,value('dotWarning'),sec,function() return S.db.dotWarnings end)
    local tracked=timers:Card(L.cardTracked,L.cardTrackedHelp,nil,I.tracked)
    segment(page,tracked,'dotFilter',nil,{{value=1,label=L.dotFilter1,tip=L.dotFilter1Help,icon=I.tracked},
        {value=2,label=L.dotFilter2,tip=L.dotFilter2Help,icon=I.dots}},value('dotFilter'))
    toggle(page,tracked,'dotChannels',L.dotChannels,L.dotChannelsHelp,bool('dotChannels'))
    local fallback=timers:Card(L.cardFallback,L.cardFallbackHelp,nil,I.general)
    toggle(page,fallback,'enemyAutoHeight',L.enemyAutoHeight,nil,bool('enemyAutoHeight'))
    slider(page,fallback,'enemyHeight',L.enemyHeight,160,900,10,value('enemyHeight'),px)

    local health=newSection(page,'health')
    local hp=health:Card(L.dotHealthTitle,L.dotNameHelp,nil,I.health)
    toggle(page,hp,'dotHealth',L.dotHealth,nil,bool('dotHealth'))
    toggle(page,hp,'enemyNameHeader',L.enemyNameHeader,nil,bool('enemyNameHeader'))
    local fmt=health:Card(L.dotHealthFormat,nil,nil,I.note)
    segment(page,fmt,'healthMode',nil,{{value=2,label='416'},{value=3,label='34 %'},{value=4,label='416 (34 %)'},
        {value=1,label='416 / 1 223'},{value=5,label='416 (34 %) / 1 223'}},value('healthMode'),function() return S.db.dotHealth end)
    slider(page,fmt,'healthWidth',L.healthWidth,100,600,5,value('healthWidth'),px,function() return S.db.dotHealth end)
    slider(page,fmt,'healthHeight',L.healthHeight,12,48,1,value('healthHeight'),px,function() return S.db.dotHealth end)

    local frameSec=newSection(page,'frame')
    local place=frameSec:Card(L.enemyPlacement,L.enemyEditHelp,nil,I.move)
    toggle(page,place,'enemyLocked',L.enemyLocked,nil,bool('enemyLocked'))
    toggle(page,place,'enemyHeader',L.enemyHeader,L.enemyHeaderHelp,bool('enemyHeader'))
    buttonRow(page,place,{
        {label=L.enemyMove,key='enemyMove',icon=I.move,label_fn=function() return S.UI.enemyEdit=='move' and L.enemyDone or L.enemyMove end,
            fn=function() S.UI.editEnemy('move') end,when=function() return not A.combat() end},
        {label=L.enemyResize,key='enemyResize',icon=I.size,label_fn=function() return S.UI.enemyEdit=='resize' and L.enemyDone or L.enemyResize end,
            fn=function() S.UI.editEnemy('resize') end,when=function() return not A.combat() end},
    })
    local size=frameSec:Card(L.cardSize,L.cardSizeHelp,nil,I.size)
    slider(page,size,'width',L.width,220,600,5,value('width'),px)
    slider(page,size,'spacing',L.spacing,2,20,1,value('spacing'),px)

    local adv=newSection(page,'advanced')
    local engine=adv:Card(L.cardEngine,L.cardEngineHelp,nil,I.engine)
    page.engineState=T.text(engine,12); page.engineState:SetWidth(engine.inner); engine:Add(page.engineState,16,10)
    buttonRow(page,engine,{
        {label=L.dotDebug,fn=function() SlashCmdList.FELKIT('dots debug') end,icon=I.engine},
        {label=L.dotTest,fn=function() S.NativeDots.selfTest() end,icon=I.target},
        {label=L.dotRetry,fn=function() S.NativeDots.retry(); S.updateEnemies(); O.refresh() end,icon=I.reset},
    })
    local timing=adv:Card(L.dotTimingTitle,L.dotTimingHelp,nil,I.clock)
    toggle(page,timing,'dotConfirmedOnly',L.dotConfirmedOnly,L.dotConfirmedHelp,bool('dotConfirmedOnly'))
    toggle(page,timing,'dotAuto',L.dotAuto,nil,bool('dotAuto'))
    toggle(page,timing,'dotPredict',L.dotPredict,nil,bool('dotPredict'),function() return not S.db.dotConfirmedOnly end)
    local expert=adv:Card(L.dotExpertTitle,L.dotExpertHelp,nil,I.note)
    local fields={}; O.controls.dotProfile=fields
    local grid=CreateFrame('Frame',nil,expert); grid:SetSize(expert.inner,58)
    local fw=math.floor((expert.inner-24)/4)
    for i,k in ipairs({'dotID','dotDuration','dotInterval','dotDamage'}) do
        local lab=T.text(grid,11,T.c.muted); lab:SetPoint('TOPLEFT',(i-1)*(fw+8),0); lab:SetWidth(fw); lab:SetText(L[k])
        local e=input(grid,fw); e:SetPoint('TOPLEFT',(i-1)*(fw+8),-18); e:SetMaxLetters(12); fields[k]=e
    end
    expert:Add(grid,52,8)
    buttonRow(page,expert,{
        {label=L.dotSave,key='dotSave',kind='primary',fn=function()
            if S.Tracker.setProfile(fields.dotID:GetText(),fields.dotDuration:GetText(),fields.dotInterval:GetText(),fields.dotDamage:GetText()) then S.print(L.dotSaved)
            else S.print(L.invalid) end end,when=function() return not S.db.dotAuto end},
        {label=L.dotLoad,key='dotLoad',fn=function()
            local id=tonumber(fields.dotID:GetText()); local spec=id and S.Tracker.profile(id)
            fields.dotDuration:SetText(spec and tostring(spec.duration) or '')
            fields.dotInterval:SetText(spec and tostring(spec.interval or 0) or '')
            fields.dotDamage:SetText(spec and tostring(math.floor((spec.total or 0)+0.5)) or '') end},
        {label=L.dotClear,key='dotClear',fn=function()
            local id=tonumber(fields.dotID:GetText())
            if id then S.db.dotProfiles[id]=nil; S.Tracker.profiles[id]=nil end
            fields.dotDuration:SetText(''); fields.dotInterval:SetText(''); fields.dotDamage:SetText('') end},
    })
    page.controls[#page.controls+1]={Sync=function() for _,e in pairs(fields) do e:SetEnabled(not S.db.dotAuto) end
        grid:SetAlpha(S.db.dotAuto and 0.45 or 1) end}
end
function O.syncEnemies(page)
    local N=S.NativeDots
    local enemies,all=GetCVar and A.call(GetCVar,'nameplateShowEnemies'),GetCVar and A.call(GetCVar,'nameplateShowAll')
    page.plates:SetText(string.format(L.platesState,tostring(enemies=='1' and L.moduleOn or L.moduleOff),tostring(all=='1' and L.moduleOn or L.moduleOff)))
    page.engineState:SetText(N.failed and ('|cfff46454'..L.stateError..'|r  '..(N.error or '')) or
        N.active and ('|cff79e063'..L.stateReady..'|r  '..string.format(L.engineBound,N.bound or 0)) or ('|cffaea7c3'..L.stateIdle..'|r'))
end
-- Multi-Target DoTs window (Warlock HUD port): its own settings, Warlock HUD's
-- bounds. Changes rebuild native slots out of combat only (S.WH.refresh).
local function mtBool(key)
    return {function() return S.db.multiTarget[key]==true end,function(v) S.db.multiTarget[key]=v==true; apply() end}
end
local function mtValue(key)
    return {function() return S.db.multiTarget[key] end,function(v) S.db.multiTarget[key]=v; apply() end}
end
local function mtShown(key)
    return {function() return S.db.multiTarget.enabled[key]~=false end,
        function(v) if v==true then S.db.multiTarget.enabled[key]=nil else S.db.multiTarget.enabled[key]=false end; apply() end}
end
-- 0.7.1: four tabs. Display (style, bar height, the spells as the game names
-- them), Health (height, spacing, name, icon, 20 %), Does It Die (where and how
-- it looks), Frame (window, click targeting).
local DID_COLORS={white={1,1,1},gold={1,.85,.1},purple={.7,.3,1},red={1,.2,.2},orange={1,.55,.1},
    green={.3,1,.3},cyan={.2,.9,1},pink={1,.45,.6},black={0,0,0}}
local function swatches()
    local list={}
    for _,id in ipairs(S.Model.didColors) do list[#list+1]={value=id,label='',swatch=DID_COLORS[id]} end
    return list
end
local function choices(prefix,ids)
    local list={}
    for _,id in ipairs(ids) do list[#list+1]={value=id,label=L[prefix..id]} end
    return list
end
-- The tracked spells the player knows, in family order, by their game names.
local function knownSpells()
    local api=S.WH.API
    local list={}
    for _,key in ipairs(S.Model.multiTargetKeys) do
        for _,spell in ipairs(api.Spells) do
            if spell.group~=2 and api.MainKeys[spell.slot]==key then
                local known=key=='demonicbrand' and api.knowsBrand() or (key~='demonicbrand' and api.knownSpell(spell))
                if known then
                    local id=spell.ids[1]
                    for _,rank in ipairs(spell.ids) do
                        if (IsPlayerSpell and A.call(IsPlayerSpell,rank)==true) then id=rank end
                    end
                    list[#list+1]={spell=spell,key=key,id=id}
                end
            end
        end
    end
    return list
end
function B.multiTarget(page)
    local p=function() return S.db.multiTarget end
    local display=newSection(page,'display')
    display:Card(L.cardPreviewBars,L.mtPreviewHelp,nil,I.eye)
    local place=display:Card(L.mtCardPlace,L.mtPlaceHelp,nil,I.move)
    toggle(page,place,'mtLocked',L.mtLocked,nil,mtBool('locked'))
    local dots=display:Card(L.mtCardDots,L.mtDotsHelp,nil,I.timer)
    segment(page,dots,'mtDotStyle',nil,{{value='hud',label='Warlock HUD',tip=L.mtStyleHudHelp,glyph='icons'},
        {value='equal',label=L.mtStyleEqual,tip=L.mtStyleEqualHelp,glyph='bars'},
        {value='kit',label=L.mtStyleKit,tip=L.mtStyleKitHelp,glyph='bars'}},mtValue('dotStyle'))
    slider(page,dots,'mtBarHeight',L.mtBarHeight,8,30,1,{function() return p().barHeight end,
        function(v) p().barHeight=math.floor(v); apply() end},px,function() return p().dotStyle~='hud' end)
    toggle(page,dots,'mtKitColors',L.mtKitColors,L.mtKitColorsHelp,mtBool('kitColors'),function() return p().dotStyle=='kit' end)
    toggle(page,dots,'mtKitRings',L.mtKitRings,nil,mtBool('kitRings'),function() return p().dotStyle=='kit' end)
    toggle(page,dots,'mtKitEdges',L.mtKitEdges,nil,mtBool('kitEdges'),function() return p().dotStyle=='kit' end)
    page.mtPresentationState=T.text(dots,11,T.c.muted)
    page.mtPresentationState:SetWidth(dots.inner); page.mtPresentationState:SetWordWrap(true)
    dots:Add(page.mtPresentationState,30,6)
    local fx=display:Card(L.mtCardEffects,L.mtSpellsHelp,nil,I.tracked)
    local spells=knownSpells()
    for _,e in ipairs(spells) do
        local name,known=e.spell.name,A.spell(e.id)
        local key='mt_'..name:gsub('%s','')
        ICON[key]={spell=e.id}
        local acc={function() return p().enabled[name]~=false end,function(v)
            local value=nil
            if v~=true then value=false end -- only the off choice is stored
            p().enabled[name]=value
            -- Brand is also gated by its own family key in Warlock HUD.
            if e.key=='demonicbrand' then p().enabled.demonicbrand=value end
            apply() end}
        toggle(page,fx,key,type(known)=='string' and known or name,nil,acc)
    end
    if #spells==0 then fx:Note(L.mtSpellsNone) end
    local health=newSection(page,'health')
    local bar=health:Card(L.mtCardHealth,L.mtHealthHelp2,nil,I.style)
    slider(page,bar,'mtHealthHeight',L.healthHeight,8,40,1,{function() return p().healthHeight end,
        function(v) p().healthHeight=math.floor(v); apply() end},px)
    slider(page,bar,'mtSpacing',L.mtSpacing,0,16,1,{function() return p().spacing end,
        function(v) p().spacing=math.floor(v); apply() end},px)
    toggle(page,bar,'mtShowName',L.mtShowName,nil,mtBool('showName'))
    toggle(page,bar,'mtShowPortrait',L.mtShowPortrait,nil,mtBool('showPortrait'))
    toggle(page,bar,'mtExecute',L.mtExecute,nil,mtBool('execute'))
    segment(page,bar,'mtHealthColor',L.mtHealthColor,{{value='green',label=L.healthColor_green,swatch={.20,.55,.36}},
        {value='red',label=L.healthColor_red,swatch={.70,.16,.14}},{value='reaction',label=L.healthColor_reaction,tip=L.healthColorReactionHelp}},
        mtValue('healthColor'))
    local selectCard=health:Card(L.mtCardSelect,L.mtSelectHelp,nil,I.target)
    segment(page,selectCard,'mtSelectStyle',nil,choices('selectStyle_',{'line','outline','fill','health'}),mtValue('selectStyle'))
    segment(page,selectCard,'mtSelectColor',L.mtSelectColor,swatches(),mtValue('selectColor'))
    slider(page,selectCard,'mtSelectSize',L.mtSelectSize,1,4,1,{function() return p().selectSize end,
        function(v) p().selectSize=math.floor(v); apply() end},px,function() return p().selectStyle~='fill' end)
    local didSec=newSection(page,'did')
    local did=didSec:Card(L.mtCardDID,L.mtDIDHelp,nil,I.target)
    -- Off: no DoT table at all; Does It Die stays on the nameplates.
    toggle(page,did,'mtTableShown',L.mtTableShown,L.mtTableShownHelp,bool('enemies'))
    toggle(page,did,'mtDidBars',L.mtDidBars,nil,mtBool('didBars'),function() return S.db.enemies end)
    toggle(page,did,'mtDidPlates',L.mtDidPlates,L.mtDidPlatesHelp,mtBool('didPlates'),
        function() return not (S.DID and S.DID.external()) end)
    page.mtExternal=T.text(did,11,T.c.muted); page.mtExternal:SetWidth(did.inner); page.mtExternal:SetWordWrap(true)
    did:Add(page.mtExternal,18,6)
    local look=didSec:Card(L.mtDidLook,L.mtDidLookHelp,nil,I.style)
    local any=function() return p().didBars or p().didPlates end
    segment(page,look,'mtDidDotColors',L.mtDidDotColors,choices('didDotColors_',{'school','each','single'}),mtValue('didDotColors'),any)
    segment(page,look,'mtDidFill',L.mtDidFill,choices('didFill_',{'stripes','flat','smooth','none'}),mtValue('didFill'),any)
    segment(page,look,'mtDidColor',L.mtDidColor,swatches(),mtValue('didColor'),
        function() return any() and p().didDotColors=='single' and p().didFill~='none' end)
    slider(page,look,'mtDidOpacity',L.mtDidOpacity,10,100,5,{function() return p().didOpacity end,
        function(v) p().didOpacity=math.floor(v); apply() end},pct,any)
    segment(page,look,'mtDidOutline',L.mtDidOutline,choices('didOutline_',{'dashed','solid','none'}),mtValue('didOutline'),any)
    segment(page,look,'mtDidOutlineColor',L.mtDidOutlineColor,swatches(),mtValue('didOutlineColor'),
        function() return any() and p().didOutline~='none' end)
    slider(page,look,'mtDidOutlineSize',L.mtDidOutlineSize,1,3,1,{function() return p().didOutlineSize end,
        function(v) p().didOutlineSize=math.floor(v); apply() end},px,function() return any() and p().didOutline~='none' end)
    segment(page,look,'mtDidIcon',L.mtDidIcon,choices('didIcon_',{'skull','cross','check','boss'}),mtValue('didIcon'),any)
    local plates=function() return p().didPlates and not (S.DID and S.DID.external()) end
    slider(page,look,'mtDidPlateIconSize',L.mtDidPlateIconSize,12,40,1,{function() return p().didPlateIconSize end,
        function(v) p().didPlateIconSize=math.floor(v); apply() end},px,plates)
    segment(page,look,'mtDidPlateIconPos',L.mtDidPlateIconPos,choices('didPos_',{'left','right','above'}),mtValue('didPlateIconPos'),plates)
    local frameSec=newSection(page,'frame')
    local win=frameSec:Card(L.mtCardWindow,L.mtCardWindowHelp,nil,I.dots)
    toggle(page,win,'mtClick',L.mtClick,L.mtClickHelp,mtBool('clickTarget'))
    toggle(page,win,'mtTransparent',L.mtTransparent,nil,mtBool('transparent'))
    slider(page,win,'mtAlpha',L.mtAlpha,30,100,5,{function() return math.floor(p().multiDotAlpha*100+0.5) end,
        function(v) p().multiDotAlpha=v/100; apply() end},pct,function() return not p().transparent end)
    toggle(page,win,'mtHeader',L.mtHeader,L.mtHeaderHelp,mtBool('header'))
    toggle(page,win,'mtHideOOC',L.mtHideOOC,nil,mtBool('multiDotHideOutOfCombat'))
    slider(page,win,'mtScale',L.scale,70,160,5,{function() return math.floor(p().multiDotScale*100+0.5) end,
        function(v) p().multiDotScale=v/100; apply() end},pct)
    buttonRow(page,win,{
        {label=L.mtResetPos,key='mtResetPos',icon=I.move,when=function() return not A.combat() end,fn=function()
            if A.combat() then S.print(L.combat); return end
            local d=S.Model.multiTarget({})
            p().multiDotX,p().multiDotY=d.multiDotX,d.multiDotY; apply() end},
        {label=L.mtResetSize,key='mtResetSize',icon=I.size,when=function() return not A.combat() end,fn=function()
            if A.combat() then S.print(L.combat); return end
            local d=S.Model.multiTarget({})
            p().multiDotScale=d.multiDotScale; p().multiDotWidth,p().multiDotHeight=d.multiDotWidth,d.multiDotHeight; apply() end},
    })
    frameSec:Card(nil,L.mtCredit..' '..L.mtCreditDID,nil,I.help)
end
function O.syncMultiTarget(page)
    local p=S.WH and S.WH.Presentation
    if p and page.mtPresentationState then
        page.mtPresentationState:SetText(p.error or (p.pending and L.mtPresentationPending or L.mtDotsSorted))
    end
    if page.mtExternal then page.mtExternal:SetText(S.DID and S.DID.external() and L.mtDidExternal or '') end
end
-- The game's own icon of a kit group (its first known family member).
local function kitIcon(group)
    local list=S.KitData.families[group.families[1]]
    return list and {spell=list[#list]} or I.kit
end
function B.kit(page)
    local layoutSec=newSection(page,'layout')
    local shape=layoutSec:Card(L.kitLayout,nil,nil,I.move)
    segment(page,shape,'kit.layout',nil,{{value='orb',label=L.kit_orb,glyph='circle'},{value='circle',label=L.kit_circle,glyph='circle'},{value='horizontal',label=L.kit_horizontal,glyph='horizontal'},
        {value='vertical',label=L.kit_vertical,glyph='vertical'},{value='grid',label=L.kit_grid,glyph='grid'},{value='free',label=L.kit_free,glyph='free'}},kitValue('layout'))
    local circle=layoutSec:Card(L.kitCircleDistance,L.kitCircleHelp,function() return S.db.kit.layout=='circle' end,I.size)
    slider(page,circle,'kit.circleDistance',L.kitCircleDistance,-200,200,1,kitValue('circleDistance'),px)
    for _,key in ipairs({'horizontal','vertical','grid'}) do
        local values=key=='horizontal' and {'left','right'} or key=='vertical' and {'up','down'} or {'up','down','left','right'}
        -- No arrow glyphs: the game font has none (they showed as squares).
        local opts={}; for _,v in ipairs(values) do opts[#opts+1]={value=v,label=L['kit_'..v]} end
        local c=layoutSec:Card(L['kit_'..key]..' · '..L.kitDirection,nil,function() return S.db.kit.layout==key end,I.move)
        segment(page,c,'kit.'..key..'Direction',nil,opts,kitValue(key..'Direction'))
    end
    local free=layoutSec:Card(L.kitFreeTitle,L.kitFreeSteps,function() return S.db.kit.layout=='free' end,I.move)
    buttonRow(page,free,{
        {label=L.kitEdit,key='kitEdit',icon=I.move,label_fn=function() return S.Kit.editing and L.kitEditDone or L.kitEdit end,
            fn=function() S.Kit.setEditing(not S.Kit.editing) end,
            when=function() return S.db.kit.layout=='free' and S.db.kit.enabled and not A.combat() end,kind='primary'},
        {label=L.kitReset,key='kitReset',icon=I.reset,fn=function() S.Kit.resetPositions() end,
            when=function() return S.db.kit.layout=='free' and not A.combat() end},
    })
    local orb=layoutSec:Card(L.kitOrbTitle,L.kitOrbHelp,function() return S.db.kit.layout=='orb' end,I.size)
    slider(page,orb,'kit.orbSize',L.kitOrbSize,40,96,2,kitValue('orbSize'),px)
    slider(page,orb,'kit.smallScale',L.kitSmallScale,40,90,2,kitValue('smallScale'),pct)
    slider(page,orb,'kit.orbArc',L.kitOrbArc,120,300,5,kitValue('orbArc'),function(v) return v..' deg' end)
    slider(page,orb,'kit.orbGap',L.kitOrbGap,0,24,1,kitValue('orbGap'),px)
    slider(page,orb,'kit.rowGap',L.kitRowGap,0,24,1,kitValue('rowGap'),px)
    slider(page,orb,'kit.rowDrop',L.kitRowDrop,0,120,1,kitValue('rowDrop'),px)
    segment(page,orb,'kit.orbArt',L.kitOrbArt,{{value='arcane',label=L.kitArt_arcane},{value='fel',label=L.kitArt_fel},{value='shadow',label=L.kitArt_shadow},
        {value='item',label=L.kitArt_item},{value='class',label=L.kitArt_class},{value='none',label=L.kitArt_none}},kitValue('orbArt'))
    segment(page,orb,'kit.countPos',L.kitCountPos,{{value='middle',label=L.kitCount_middle},{value='corner',label=L.kitCount_corner},
        {value='hidden',label=L.kitCount_hidden}},kitValue('countPos'))
    toggle(page,orb,'kit.orbArtFlip',L.kitOrbArtFlip,nil,kitBool('orbArtFlip'))
    local ringOpts={{value='purple',label=L.color_purple},{value='gold',label=L.color_gold},{value='silver',label=L.color_silver},
        {value='fel',label=L.color_fel},{value='cyan',label=L.color_cyan}}
    segment(page,orb,'kit.ringColor',L.kitRingColor,ringOpts,kitValue('ringColor'))
    segment(page,orb,'kit.orbRingColor',L.kitOrbRingColor,ringOpts,kitValue('orbRingColor'))
    toggle(page,orb,'kit.divider',L.kitDivider,nil,kitBool('divider'))
    toggle(page,orb,'kit.orbGlow',L.kitOrbGlow,nil,kitBool('orbGlow'))
    local size=layoutSec:Card(L.cardSize,L.kitScaleHelp,nil,I.size)
    slider(page,size,'kit.scale',L.kitScale,50,200,5,scaled('scale',100,true),pct)
    segment(page,size,'kit.size',L.kitBaseSize,{{value=28,label='28 px'},{value=36,label='36 px'},{value=44,label='44 px'},{value=52,label='52 px'}},kitValue('size'))

    local buttons=newSection(page,'buttons')
    local filter=buttons:Card(L.kitVisibleTitle,L.kitVisibilityHelp,nil,I.reveal)
    toggle(page,filter,'kit.hideUnknown',L.kitHideUnknown,nil,kitBool('hideUnknown'))
    buttonRow(page,filter,{
        {label=L.kitShowAll,key='kitShowAll',icon=I.eye,fn=function() for _,g in ipairs(S.KitData.groups) do S.db.kit.visible[g.key]=true end; apply() end},
        {label=L.kitHideAll,key='kitHideAll',fn=function() for _,g in ipairs(S.KitData.groups) do S.db.kit.visible[g.key]=false end; apply() end},
    })
    -- Weapon stone kind; the button always uses the best rank learned or carried.
    local weaponGroup; for _,g in ipairs(S.KitData.groups) do if g.key=='weapon' then weaponGroup=g end end
    local weapon=buttons:Card(L.kitWeaponChoice,L.kitWeaponHelp,nil,kitIcon(weaponGroup))
    segment(page,weapon,'kit.weaponStone',nil,{{value='fire',label=L.kitFirestone},{value='stone',label=L.kitSpellstone}},
        {function() return S.db.kit.selected.weapon or 'fire' end,function(v) S.db.kit.selected.weapon=v; apply() end})
    local list=buttons:Card(L.kitButtonsTitle,nil,nil,I.kit)
    local half=math.floor((list.inner-24)/2)
    local holder=CreateFrame('Frame',nil,list); local rows=math.ceil(#S.KitData.groups/2)
    holder:SetSize(list.inner,rows*36)
    for i,g in ipairs(S.KitData.groups) do
        local key=g.key
        local r=T.toggleRow(holder,half,L['kit_'..key],nil,function() return S.db.kit.visible[key] end,
            function(v) S.db.kit.visible[key]=v; apply() end,kitIcon(g))
        r:SetPoint('TOPLEFT',((i-1)%2)*(half+24),-math.floor((i-1)/2)*36)
        register(page,'kit.visible.'..key,r)
    end
    list:Add(holder,nil,4)

    local remind=newSection(page,'reminders')
    local rc=remind:Card(L.kitRemindTitle,L.kitRemindHelp,nil,I.note)
    segment(page,rc,'kit.alertColor',L.kitAlertColor,{{value='cyan',label=L.color_cyan},{value='orange',label=L.color_orange},
        {value='green',label=L.color_green},{value='red',label=L.color_red},{value='pink',label=L.color_pink},{value='white',label=L.color_white}},kitValue('alertColor'))
    for _,k in ipairs({'soul','health','armor','weapon','link'}) do
        toggle(page,rc,'kit.reminders.'..k,L['kitRemind_'..k],nil,
            {function() return S.db.kit.reminders[k]~=false end,function(v) S.db.kit.reminders[k]=v==true; apply() end})
    end
    local summons=newSection(page,'summons')
    local opener=summons:Card(L.kitQueueButtonDesign,nil,nil,I.summon)
    segment(page,opener,'kit.queueButtonDesign',nil,{{value='full',label=L.kit_full},{value='compact',label=L.kit_compact},{value='icon',label=L.kit_icon,icon=I.summon}},kitValue('queueButtonDesign'))
    page.openerHelp=opener:Note('')
    slider(page,opener,'kit.queueButtonScale',L.kitQueueButtonScale,60,180,5,scaled('queueButtonScale',100,true),pct,
        function() return S.db.kit.queueButtonDesign~='icon' end)
    buttonRow(page,opener,{
        {label=L.kitQueueButtonMove,key='queueButtonEdit',icon=I.move,label_fn=function() return S.Kit.queueButtonEditing and L.kitEditDone or L.kitQueueButtonMove end,
            fn=function() S.Kit.setQueueButtonEditing(not S.Kit.queueButtonEditing) end,
            when=function() return S.db.kit.queueButtonDesign~='icon' and S.db.enabled and S.db.kit.enabled and not A.combat() end},
        {label=L.kitQueueButtonReset,key='queueButtonReset',icon=I.reset,fn=function() S.Kit.resetQueueButtonPosition() end,
            when=function() return S.db.kit.queueButtonDesign~='icon' and not A.combat() end},
    })
    local window=summons:Card(L.kitQueue,L.kitQueueSizingHelp,nil,I.note)
    buttonRow(page,window,{{label=L.kitOptionsQueueOpen,fn=function() S.Kit.openQueue() end,kind='primary',icon=I.summon}})
    slider(page,window,'kit.queueWidth',L.kitQueueWidth,460,800,10,kitValue('queueWidth'),px)
    slider(page,window,'kit.queueHeight',L.kitQueueHeight,540,820,4,kitValue('queueHeight'),px)
    slider(page,window,'kit.queueScale',L.kitQueueScale,65,150,5,scaled('queueScale',100,true),pct)
end
function O.syncKit(page)
    page.openerHelp:SetText(S.db.kit.queueButtonDesign=='icon' and L.kitQueueIconHelp or L.kitQueueButtonHelp)
end
function B.shards(page)
    local s=newSection(page,'main')
    local counter=s:Card(L.cardShardCount,nil,nil,I.shards)
    page.count=T.text(counter,26,T.c.gold); page.count:SetWidth(counter.inner); counter:Add(page.count,32,4)
    page.countSub=T.text(counter,11,T.c.muted); page.countSub:SetWidth(counter.inner); counter:Add(page.countSub,14,10)
    toggle(page,counter,'compact',L.compact,L.compactHelp,bool('compact'),function() return not S.db.kit.enabled end)
    counter:Note(L.shardClickHelp)
    local keep=s:Card(L.keep,L.keepHelp,nil,I.bag)
    slider(page,keep,'keep',L.keep,0,80,1,{function() return S.db.keep end,function(v) S.setKeep(v) end})
    buttonRow(page,keep,{
        {label='10',fn=function() S.setKeep(10) end},{label='20',fn=function() S.setKeep(20) end},
        {label='30',fn=function() S.setKeep(30) end},{label='40',fn=function() S.setKeep(40) end},
    })
    local clean=s:Card(L.cardCleaning,L.autoHelp,nil,I.burn)
    toggle(page,clean,'autoShards',L.autoShards,nil,bool('autoShards'))
    toggle(page,clean,'pruneSoulBag',L.pruneSoulBag,L.pruneSoulBagHelp,bool('pruneSoulBag'))
    buttonRow(page,clean,{{label=L.prune,fn=function() S.prune() end,kind='danger',icon=I.burn}})
    clean:Note(L.manual..'\n|cffcfc9de/fk prune  ·  /click FelkitPruneButton|r')
end
function O.syncShards(page)
    local _,total=A.inventory()
    page.count:SetText((total and tostring(total) or '?')..'  |cff9a93ad/ '..S.db.keep..'|r')
    page.countSub:SetText(S.UI.countString or '')
end
-- Nightfall geometry/volume: relayout in place so a running preview survives.
local function nf(key,mult)
    return {function() return mult and math.floor(S.db[key]*mult+0.5) or S.db[key] end,
        function(v) S.db[key]=mult and v/mult or v
            if key=='procVolume' then S.stopSound() end
            S.Nightfall.layout(); S.Nightfall.tick(GetTime()); O.refresh() end}
end
function B.nightfall(page)
    local s=newSection(page,'main')
    local test=s:Card(L.cardPreview,L.nightfallIntro,nil,I.eye)
    buttonRow(page,test,{
        {label=L.nightfallTest,key='nightfallTest',fn=function() S.demoAlert() end,kind='primary',icon=I.proc},
        {label=L.nightfallStop,key='nightfallStop',fn=function() S.stopAlertPreview() end},
    })
    local sound=s:Card(L.sound,L.procSoundHelp,nil,I.sound)
    toggle(page,sound,'sound',L.sound,nil,bool('sound'))
    -- The original sound, then game sounds; spell sounds are named and pictured by
    -- their spell. Picking a tile plays it.
    local options={{value=0,label=L.procSnd_original,sub=L.procSndOriginalSub,icon={spell=17941}}}
    for i,c in ipairs(S.PROC_SOUNDS) do
        local name=c.spell and A.spell(c.spell)
        options[#options+1]={value=i,label=type(name)=='string' and name or L['procSnd_'..(c.key or 'spell')],
            sub=c.file and L.procSndCustom or c.spell and L.procSndSpell or L.procSndGame,icon=c.icon or {spell=c.spell}}
    end
    local grid=T.choiceGrid(sound,sound.inner,options,function() return S.db.procSound end,
        function(v) S.db.procSound=v; apply(); S.sound() end,3,40)
    sound:Add(grid,nil,10); register(page,'procSound',grid,function() return S.db.sound end)
    slider(page,sound,'procVolume',L.nightfallVolume,0,100,10,nf('procVolume'),pct,function() return S.db.sound end)
    buttonRow(page,sound,{{label=L.nightfallListen,key='nightfallListen',fn=function() S.demoAlert('sound') end,icon=I.sound}})
    local visual=s:Card(L.visual,L.procStyleHelp,nil,I.proc)
    toggle(page,visual,'visual',L.visual,nil,bool('visual'))
    -- Each tile shows the style's own texture, drawn additively as in game.
    local styles={}
    local media='Interface\\AddOns\\'..addon..'\\Media\\'
    for i,style in ipairs(S.Nightfall.STYLES) do
        local image=style.tex and {media..style.tex,nil,nil,0.32} or {'Interface\\Buttons\\WHITE8X8',{0.4,0.6,0,1},{0.62,0.3,1},0.14}
        styles[i]={value=i,label=L['procStyle_'..style.key],image=image}
    end
    local styleGrid=T.choiceGrid(visual,visual.inner,styles,function() return S.db.procStyle end,
        function(v) S.db.procStyle=v; S.Nightfall.layout(); apply(); S.demoAlert('visual') end,3,64)
    visual:Add(styleGrid,nil,10); register(page,'procStyle',styleGrid,function() return S.db.visual end)
    slider(page,visual,'barGap',L.nightfallGap,20,500,10,nf('barGap'),px,function() return S.db.visual end)
    slider(page,visual,'alertScale',L.nightfallScale,50,200,5,nf('alertScale',100),pct,function() return S.db.visual end)
    buttonRow(page,visual,{{label=L.nightfallVisualTest,key='nightfallVisualTest',fn=function() S.demoAlert('visual') end,icon=I.eye}})
end
function B.grimoire(page)
    local cat=newSection(page,'catalogue')
    local search=cat:Card(L.grimSearch,nil,nil,I.search)
    local row=CreateFrame('Frame',nil,search); row:SetSize(search.inner,26)
    local box=input(row,search.inner-110); box:SetPoint('TOPLEFT'); box:SetMaxLetters(80); O.controls.grimSearch=box
    local clear=T.button(row,L.grimClear,100,24,function() box:SetText(''); box:ClearFocus(); page.pageNo=1; O.renderCatalogue() end)
    clear:SetPoint('TOPRIGHT'); O.controls.grimClear=clear
    search:Add(row,26,8)
    page.results=T.text(search,11,T.c.muted); page.results:SetWidth(search.inner); search:Add(page.results,14,4)
    local list=cat:Card()
    page.rows={}; page.pageNo=1; page.perPage=8
    for i=1,page.perPage do
        local b=CreateFrame('Button',nil,list); b:SetSize(list.inner,40); T.skin(b,T.c.bg,T.c.lineSoft)
        b.badge=T.badge(b,134400,32); b.badge:SetPoint('LEFT',4,0); b.icon=b.badge.icon
        b.name=T.text(b,12); b.name:SetPoint('TOPLEFT',46,-5); b.name:SetWidth(list.inner-70); b.name:SetWordWrap(false)
        b.meta=T.text(b,10,T.c.muted); b.meta:SetPoint('TOPLEFT',46,-22); b.meta:SetWidth(list.inner-70); b.meta:SetWordWrap(false)
        b.chevron=T.text(b,14,T.c.faint); b.chevron:SetPoint('RIGHT',-10,0); b.chevron:SetText('›')
        b:SetScript('OnClick',function(self) if self.entry then S.UI.detail(self.entry) end end)
        b:SetScript('OnEnter',function(self) T.paint(self,T.c.raised,T.c.accent); self.chevron:SetTextColor(T.rgb(T.c.accent)) end)
        b:SetScript('OnLeave',function(self) T.paint(self,T.c.bg,T.c.lineSoft); self.chevron:SetTextColor(T.rgb(T.c.faint)) end)
        list:Add(b,40,6); page.rows[i]=b
    end
    page.empty=T.text(list,12,T.c.muted); page.empty:SetPoint('TOPLEFT',14,-20); page.empty:SetWidth(list.inner)
    local pager=CreateFrame('Frame',nil,list); pager:SetSize(list.inner,26)
    page.prev=T.button(pager,'‹  '..L.previous,110,24,function() page.pageNo=math.max(1,page.pageNo-1); O.renderCatalogue() end)
    page.prev:SetPoint('LEFT')
    page.next=T.button(pager,L.next..'  ›',110,24,function() page.pageNo=page.pageNo+1; O.renderCatalogue() end)
    page.next:SetPoint('RIGHT')
    page.pageText=T.text(pager,11,T.c.muted); page.pageText:SetPoint('CENTER'); page.pageText:SetJustifyH('CENTER')
    list:Add(pager,26,4)
    cat:Card(nil,L.grimCatalogueNote,nil,I.help)
    box:SetScript('OnTextChanged',function() page.pageNo=1; O.renderCatalogue() end)
    O.controls.grimRows=page.rows; O.controls.grimPrev=page.prev; O.controls.grimNext=page.next
    local opt=newSection(page,'display')
    local c=opt:Card(L.grimDisplay,nil,nil,I.grimoire)
    for _,key in ipairs({'grimoire','spellDetails','spellTooltips'}) do
        toggle(page,c,key,L['grimOption_'..key],L['grimHelp_'..key],bool(key),key~='grimoire' and function() return S.db.grimoire end or nil)
    end
    opt:Card(nil,L.grimShiftHelp,nil,I.help)
end
function O.renderCatalogue()
    local page=O.pages.grimoire; if not page then return end
    local box=O.controls.grimSearch
    local list={}; local query=string.lower(box:GetText() or '')
    if S.db.grimoire then
        for _,r in ipairs(A.catalogue()) do
            if query=='' or string.find(string.lower(r.name),query,1,true) or string.find(tostring(r.id),query,1,true) then list[#list+1]=r end
        end
    end
    local maxPage=math.max(1,math.ceil(#list/page.perPage)); page.pageNo=math.min(page.pageNo,maxPage)
    page.results:SetText(string.format(L.grimResults,#list))
    page.pageText:SetText(string.format(L.grimPage,page.pageNo,maxPage))
    page.prev:SetActive(page.pageNo>1); page.next:SetActive(page.pageNo<maxPage)
    O.controls.grimClear:SetActive(query~='')
    page.empty:SetShown(#list==0); page.empty:SetText(S.db.grimoire and L.grimEmpty or L.grimDisabled)
    for i,b in ipairs(page.rows) do
        local r=list[(page.pageNo-1)*page.perPage+i]; b.entry=r; b:SetShown(r~=nil)
        if r then
            b.icon:SetTexture(r.icon or 134400); b.name:SetText(r.name)
            local rank=C_Spell and A.call(C_Spell.GetSpellSubtext,r.id)
            b.meta:SetText((rank and rank~='' and (rank..' · ') or '')..(L[r.data.school] or L.unknown)..' · #'..r.id)
        end
    end
end
function B.channels(page)
    local s=newSection(page,'main')
    local c=s:Card(L.cardTicks,L.channelHelp,nil,I.ticks)
    c:Note(L.tickLegend)
    local swatches={}
    for i,color in ipairs(S.Ticks.COLORS) do swatches[i]={value=i,label=L['tickColor_'..i],swatch=color} end
    segment(page,c,'channelTickColor',L.channelTickColor,swatches,value('channelTickColor'))
    toggle(page,c,'tickAnimate',L.tickAnimate,L.tickAnimateHelp,bool('tickAnimate'))
    local spells=s:Card(L.cardChannelSpells,L.cardChannelSpellsHelp,nil,I.drain)
    local byName,order={},{}
    for _,entry in ipairs(A.catalogue()) do
        if entry.data.channel then
            local group=byName[entry.name]
            if not group then group={name=entry.name,icon=entry.icon or {spell=entry.id},ids={}}; byName[entry.name]=group; order[#order+1]=group end
            group.ids[#group.ids+1]=entry.id
        end
    end
    for _,group in ipairs(order) do
        local ids=group.ids
        local r=T.toggleRow(spells,spells.inner,group.name,nil,
            function() for _,id in ipairs(ids) do if S.db.channelSpells[id]==false then return false end end return true end,
            function(v) for _,id in ipairs(ids) do S.db.channelSpells[id]=v end; apply() end,group.icon)
        spells:Add(r,nil,6); register(page,'channel.'..group.name,r)
    end
    if #order==0 then spells:Note(L.grimEmpty) end
end
function B.general(page)
    local s=newSection(page,'main')
    local frames=s:Card(L.cardFrames,L.cardFramesHelp,nil,I.move)
    toggle(page,frames,'locked',L.locked,nil,bool('locked'))
    toggle(page,frames,'minimap',L.minimap,nil,bool('minimap'))
    toggle(page,frames,'chatMessages',L.chatMessages,L.chatMessagesHelp,bool('chatMessages'))
    slider(page,frames,'scale',L.scale,65,160,5,scaled('scale',100),pct)
    slider(page,frames,'opacity',L.opacity,25,100,5,scaled('opacity',100),pct)
    buttonRow(page,frames,{{label=L.reset,fn=function() S.UI.reset() end,icon=I.reset}})
    local engine=s:Card(L.dotEngineTitle,L.dotEngineHelp,nil,I.dots)
    segment(page,engine,'dotEngine',nil,{{value='window',label=L.dotEngineWindow,tip=L.dotEngineWindowHelp,glyph='bars'},
        {value='cards',label=L.dotEngineCards,tip=L.dotEngineCardsHelp,glyph='grid'}},
        {function() return S.db.dotEngine end,function(v) S.db.dotEngine=v; O.refresh() end})
    page.engineNote=engine:Note('',T.c.gold)
    buttonRow(page,engine,{{label=L.languageReload,fn=function() if ReloadUI then ReloadUI() end end,kind='primary',icon=I.reset}})
    local help=s:Card(L.cardHelp,L.cardHelpBody,nil,I.help)
    page.health={dots=statusLine(help,I.dots).text,nightfall=statusLine(help,I.proc).text,shards=statusLine(help,I.shards).text}
    buttonRow(page,help,{
        {label=L.setupAgain,fn=function() S.Onboarding.open(true) end,kind='primary',icon=I.note},
        {label=L.diagnostics,fn=function() S.diagnostics() end,icon=I.engine},
    })
    page.aboutLine=help:Note('')
    s:Card(L.cardCredits,L.creditsBody,nil,I.note)
end
function O.syncGeneral(page)
    local version,build=GetBuildInfo()
    local get=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local addonVersion=get and A.call(get,addon,'Version') or '?'
    page.aboutLine:SetText(string.format(L.aboutLine,addonVersion,tostring(version),tostring(build)))
    page.engineNote:SetText(((S.db.dotEngine=='cards')~=(S.legacyEnemies==true)) and L.dotEngineReload or '')
    syncHealth(page)
end
-- Felkit: proc timers and raid assignments.
local function procValue(key,field)
    return {function() return S.db.procs[key][field] end,function(v) S.db.procs[key][field]=v; apply() end}
end
local function procBool(key,field)
    return {function() return S.db.procs[key][field]==true end,function(v) S.db.procs[key][field]=v==true; apply() end}
end
function B.procs(page)
    local s=newSection(page,'main')
    local place=s:Card(L.procPlaceTitle,L.procPlaceHelp,nil,I.move)
    buttonRow(page,place,{
        {label=L.procTest,key='procTest',icon=I.eye,label_fn=function() return S.Procs.testing and L.kitEditDone or L.procTest end,
            fn=function() S.Procs.setTest(not S.Procs.testing) end,when=function() return not A.combat() end,kind='primary'},
        {label=L.procResetBtn,key='procReset',icon=I.reset,fn=function() S.Procs.slash('reset') end,when=function() return not A.combat() end},
    })
    for _,def in ipairs(S.Procs.DEFS) do
        local k=def.key
        local c=s:Card(L['proc_'..k],L['procHelp_'..k],nil,{spell=def.icon})
        toggle(page,c,'procs.'..k..'.enabled',L.procEnabled,nil,procBool(k,'enabled'))
        segment(page,c,'procs.'..k..'.style',L.procStyle,{{value='bar',label=L.procStyle_bar,glyph='bars'},{value='icon',label=L.procStyle_icon,glyph='icons'}},procValue(k,'style'))
        local isBar=function() return S.db.procs[k].style=='bar' end
        slider(page,c,'procs.'..k..'.width',L.procWidth,80,400,5,procValue(k,'width'),px,isBar)
        slider(page,c,'procs.'..k..'.height',L.procHeight,10,40,1,procValue(k,'height'),px,isBar)
        toggle(page,c,'procs.'..k..'.showName',L.procShowName,nil,procBool(k,'showName'),isBar)
        slider(page,c,'procs.'..k..'.iconSize',L.procIconSize,20,96,2,procValue(k,'iconSize'),px,function() return not isBar() end)
        slider(page,c,'procs.'..k..'.alpha',L.opacity,20,100,5,{function() return math.floor(S.db.procs[k].alpha*100+0.5) end,
            function(v) S.db.procs[k].alpha=v/100; apply() end},pct)
    end
end
local function raidValue(field) return {function() return S.db.raid[field] end,function(v) S.db.raid[field]=v; apply() end} end
function B.raid(page)
    local s=newSection(page,'main')
    local w=s:Card(L.assignTitle,L.assignCardHelp,nil,I.crowd)
    buttonRow(page,w,{
        {label=L.assignOpen,key='assignOpen',icon=I.note,fn=function() S.Assign.toggle() end,kind='primary'},
        {label=L.assignAnnounce,key='assignAnnounce',icon=I.sound,fn=function() S.Assign.announce() end},
    })
    local p=s:Card(L.assignPanelCard,L.assignPanelCardHelp,nil,I.kit)
    toggle(page,p,'raid.panel',L.assignShowPanel,nil,{function() return S.db.raid.panel end,function(v) S.db.raid.panel=v==true; apply() end})
    segment(page,p,'raid.size',L.assignButtonSize,{{value='small',label=L.assignSmall},{value='full',label=L.assignFull}},raidValue('size'))
    slider(page,p,'raid.x',L.assignOffsetX,-400,400,2,raidValue('x'),px)
    slider(page,p,'raid.y',L.assignOffsetY,-200,400,2,raidValue('y'),px)
end
O.NAV={
    {key='home',icon=I.seal,build=B.home,sync=function(p) O.syncHome(p) end},
    -- Enemies & DoTs = Warlock HUD's Multi-Target window; the former cards page
    -- is built only when the dormant legacy module is switched on (tests).
    {key='enemies',group='combat',icon=I.dots,build=S.legacyEnemies and B.enemiesLegacy or B.multiTarget,
        sync=function(p) if S.legacyEnemies then O.syncEnemies(p) else O.syncMultiTarget(p) end end,preview=true,
        master=function() return bool('enemies') end,module=function() return S.db.enemies end,
        tabs=S.legacyEnemies and {'display','timers','health','frame','advanced'} or {'display','health','did','frame'},
        tabIcons={display=I.reveal,timers=I.timer,health=I.health,frame=I.move,advanced=I.engine,did=I.target}},
    {key='nightfall',group='combat',icon=I.nightfall,build=B.nightfall,
        master=function() return bool('nightfall') end,module=function() return S.db.nightfall end},
    {key='procs',group='combat',icon=I.timer,build=B.procs},
    {key='channels',group='combat',icon=I.channels,build=B.channels,
        master=function() return bool('channels') end,module=function() return S.db.channels end},
    {key='kit',group='tools',icon=I.kit,build=B.kit,sync=function(p) O.syncKit(p) end,
        master=function() return kitBool('enabled') end,module=function() return S.db.kit.enabled end,tabs={'layout','buttons','reminders','summons'},
        tabIcons={layout=I.move,buttons=I.kit,reminders=I.note,summons=I.summon}},
    {key='raid',group='tools',icon=I.crowd,build=B.raid},
    {key='shards',group='tools',icon=I.shards,build=B.shards,sync=function(p) O.syncShards(p) end,
        master=function() return bool('shards') end,module=function() return S.db.shards end},
    {key='grimoire',group='tools',icon=I.grimoire,build=B.grimoire,sync=function() O.renderCatalogue() end,
        master=function() return bool('grimoire') end,module=function() return S.db.grimoire end,tabs={'catalogue','display'},
        tabIcons={catalogue=I.grimoire,display=I.note}},
    {key='general',group='system',icon=I.general,build=B.general,sync=function(p) O.syncGeneral(p) end,
        master=function() return bool('enabled') end,module=function() return S.db.enabled end},
}
function O.create()
    L=S.L
    local f=T.window('FelkitWindow',W,H,L.title,'main'); O.frame=f
    f:Hide()
    f.version=T.text(f.titleBar,11,T.c.faint); f.version:SetPoint('RIGHT',f.close,'LEFT',-10,0); f.version:SetJustifyH('RIGHT')
    local get=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    f.version:SetText('v'..tostring(get and A.call(get,addon,'Version') or '?'))
    local side=CreateFrame('Frame',nil,f); side:SetPoint('TOPLEFT',1,-35); side:SetPoint('BOTTOMLEFT',1,1); side:SetWidth(SIDE)
    side.bg=side:CreateTexture(nil,'BACKGROUND'); side.bg:SetAllPoints(); side.bg:SetColorTexture(T.rgb(T.c.side))
    side.rule=side:CreateTexture(nil,'ARTWORK'); side.rule:SetPoint('TOPRIGHT'); side.rule:SetPoint('BOTTOMRIGHT'); side.rule:SetWidth(1)
    side.rule:SetColorTexture(T.rgb(T.c.line))
    O.side=side; O.nav={}
    local y=-12; local group
    for i,def in ipairs(O.NAV) do
        if def.key=='enemies' then
            -- The engine is chosen at load (General > DoT engine).
            def.build=S.legacyEnemies and B.enemiesLegacy or B.multiTarget
            def.tabs=S.legacyEnemies and {'display','timers','health','frame','advanced'} or {'display','health','did','frame'}
        end
        if def.group and def.group~=group then
            group=def.group; y=y-6
            local head=T.text(side,10,T.c.faint); head:SetPoint('TOPLEFT',16,y); head:SetText(string.upper(L['sideGroup_'..group]))
            y=y-18
        end
        local b=CreateFrame('Button',nil,side); b:SetSize(SIDE-16,36); b:SetPoint('TOPLEFT',8,y); y=y-38
        b.bg=b:CreateTexture(nil,'BACKGROUND'); b.bg:SetAllPoints()
        b.mark=b:CreateTexture(nil,'ARTWORK'); b.mark:SetPoint('TOPLEFT'); b.mark:SetPoint('BOTTOMLEFT'); b.mark:SetWidth(3)
        b.mark:SetColorTexture(T.rgb(T.c.accent))
        b.badge=T.badge(b,def.icon,26); b.badge:SetPoint('LEFT',10,0); b.icon=b.badge.icon
        b.label=T.text(b,12); b.label:SetPoint('LEFT',b.badge,'RIGHT',10,0); b.label:SetText(L['nav_'..def.key])
        b.dot=b:CreateTexture(nil,'OVERLAY'); b.dot:SetSize(8,8); b.dot:SetPoint('RIGHT',-12,0)
        b:SetScript('OnClick',function() O.open(def.key) end)
        b:SetScript('OnEnter',function(self) self.hot=true; O.syncNav() end)
        b:SetScript('OnLeave',function(self) self.hot=false; O.syncNav() end)
        b.def=def; O.nav[i]=b
    end
    local hint=T.text(side,10,T.c.faint); hint:SetPoint('BOTTOMLEFT',14,12); hint:SetWidth(SIDE-28); hint:SetText(L.sideHint)
    hint:SetWordWrap(true)
    O.content=CreateFrame('Frame',nil,f); O.content:SetPoint('TOPLEFT',SIDE+1,-35); O.content:SetPoint('BOTTOMRIGHT',-1,1)
    f:SetScript('OnShow',function() O.refresh() end)
    -- Test bars belong to the settings session: closing the window removes them.
    f:SetScript('OnHide',function() if S.previewOn then S.setPreview(false) end
        if S.WH and S.WH.MultiTarget then S.WH.MultiTarget.SetPreview(false) end end)
    O.open('home',true)
end
function O.syncNav()
    for _,b in ipairs(O.nav or {}) do
        local selected=O.current and O.current.key==b.def.key
        b.bg:SetColorTexture(T.rgb(selected and T.c.raised or (b.hot and T.c.card or {0,0,0,0})))
        b.mark:SetShown(selected)
        b.label:SetTextColor(T.rgb((selected or b.hot) and T.c.text or T.c.muted))
        local on=not b.def.module or b.def.module()
        b.dot:SetShown(b.def.module~=nil)
        b.dot:SetColorTexture(T.rgb(on and T.c.fel or T.c.faint))
        b.badge:SetLit(b.def.module==nil or on)
    end
end
function O.page(key)
    local page=O.pages[key]
    if not page then
        for _,def in ipairs(O.NAV) do
            if def.key==key then page=newPage(def); def.build(page); break end
        end
        if not page then return nil end
        for k,s in pairs(page.sections) do s:SetShown(k==page.order[1]) end
        page.tab=page.tab or page.order[1]
    end
    return page
end
function O.open(key,silent,tab)
    if not O.frame then return end
    local page=O.page(key) or O.page('home')
    if O.current and O.current~=page then O.current.frame:Hide() end
    O.current=page; page.frame:Show()
    if tab and page.sections[tab] then page.tab=tab end
    O.showTab(page,page.tab or page.order[1])
    O.syncNav()
    if not silent then O.frame:Show() end
    return page
end
function O.refresh()
    if not O.frame or not O.frame:IsShown() then return end
    O.syncNav()
    if O.current then O.syncPage(O.current) end
end
function O.toggle() if O.frame:IsShown() then O.frame:Hide() else O.frame:Show() end end
