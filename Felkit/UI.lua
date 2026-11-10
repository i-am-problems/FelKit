-- In-world frames: enemy/DoT frame, shard counter, minimap button and the
-- spell sheet. Settings live in Options.lua; first launch in Onboarding.lua.
local _,S=...
local U={}; S.UI=U
local L,A,T=S.L,S.API,S.Theme
local function font() return S.font() end
local function label(parent,text,x,y,width,size)
    local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    f:SetPoint('TOPLEFT',x,y); f:SetWidth(width or 480); f:SetJustifyH('LEFT')
    f:SetFont(font(),size or 12,'')
    f:SetTextColor(T.rgb(T.c.text)); f:SetText(text or '')
    return f
end
local function panel(name,w,h)
    local f=CreateFrame('Frame',name,UIParent,'BackdropTemplate')
    f:SetSize(w,h); f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
    f:SetBackdropColor(T.rgb(T.c.bg)); f:SetBackdropBorderColor(T.rgb(T.c.line))
    return f
end
function U.anchor(f,key,x,y)
    f.key=key; f.defaultX=x; f.defaultY=y
    local p=S.db.positions[key] or {x=x,y=y}
    f:ClearAllPoints(); f:SetPoint('CENTER',UIParent,'CENTER',p.x,p.y)
    f:SetMovable(true)
    local grip=CreateFrame('Frame',nil,f); grip:SetPoint('TOPLEFT'); grip:SetPoint('TOPRIGHT'); grip:SetHeight(26)
    f.grip=grip
    grip:EnableMouse(true); grip:RegisterForDrag('LeftButton')
    grip:SetScript('OnDragStart',function() if not (key=='enemies' and S.db.enemyLocked or key~='enemies' and S.db.locked) and not A.combat() then f:StartMoving() end end)
    grip:SetScript('OnDragStop',function()
        if A.combat() then return end
        f:StopMovingOrSizing()
        local fx,fy=f:GetCenter(); local px,py=UIParent:GetCenter()
        local ratio=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        S.db.positions[key]={x=fx-px/ratio,y=fy-py/ratio}
    end)
end
-- Pulsing halo: missing reminder on a kit button, or excess shards on the counter.
function U.halo(f,r,g,b)
    local t=f:CreateTexture(nil,'OVERLAY')
    t:SetTexture('Interface\\Buttons\\UI-ActionButton-Border'); t:SetBlendMode('ADD')
    t:SetPoint('CENTER'); t:SetVertexColor(r,g,b); t:Hide()
    local pulse=t:CreateAnimationGroup(); pulse:SetLooping('BOUNCE')
    local a=pulse:CreateAnimation('Alpha'); a:SetFromAlpha(0.45); a:SetToAlpha(1); a:SetDuration(0.55)
    t.pulse=pulse; return t
end
function U.setHalo(t,on,size)
    if not t then return end
    if on then
        if size then local k=t.ringGlow and 2.1 or 1.85; t:SetSize(size*k,size*k) end
        if not t:IsShown() then t:Show(); t.pulse:Play() end
    elseif t:IsShown() then t.pulse:Stop(); t:Hide() end
end
local function bar(parent,height)
    local b=CreateFrame('StatusBar',nil,parent)
    b:SetHeight(height); b:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
    b:SetStatusBarColor(T.rgb(T.c.accent)); b:SetMinMaxValues(0,1); b:SetValue(0)
    local bg=b:CreateTexture(nil,'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0.12,0.10,0.17,1); b.bg=bg
    b.text=label(b,'',4,-3,300,12); b.icon=b:CreateTexture(nil,'OVERLAY'); b.icon:SetSize(height,height)
    b.icon:SetPoint('RIGHT',b,'LEFT',-3,0); b.marks={}
    return b
end
U.bar=bar
local function setbar(b,text,ratio,width,height)
    b:SetSize(width,height); b.text:SetWidth(width-8)
    b.text:SetFont(font(),S.db.fontSize,'')
    b:SetValue(ratio and math.max(0,math.min(1,ratio)) or 0)
    b.text:SetText(text)
end
U.setbar=setbar
function U.reset()
    if A.combat() then S.print(L.combat); return end
    S.db.positions={}
    for _,f in ipairs({U.main,U.counter,U.enemy}) do
        f:ClearAllPoints(); f:SetPoint('CENTER',UIParent,'CENTER',f.defaultX or 0,f.defaultY or 0)
    end
end
-- Compatibility entry points used by Core, Kit and slash commands.
function U.page(key,tab) return S.Options.open(key,true,tab) end
function U.open(key,tab) return S.Options.open(key,false,tab) end
function U.openShards() S.Options.open('shards') end
function U.openKit(section)
    local tab=section=='summons' and 'summons' or section=='buttons' and 'buttons' or 'layout'
    S.Options.open('kit',false,tab)
end
function U.syncKitEditing() S.Options.refresh() end
function U.syncKeep() S.Options.refresh() end
function U.syncQueueButtonEditing() S.Options.refresh() end
function U.detail(r)
    if not U.detailFrame then
        local f=T.window('FelkitDetail',600,540,''); f:SetFrameStrata('DIALOG'); f:Hide()
        f.icon=T.icon(f,134400,40); f.icon:SetPoint('TOPLEFT',18,-50)
        f.title=T.text(f,17); f.title:SetPoint('TOPLEFT',70,-50); f.title:SetWidth(500); f.title:SetMaxLines(1)
        f.meta=T.text(f,11,T.c.muted); f.meta:SetPoint('TOPLEFT',70,-74); f.meta:SetWidth(500)
        f.tabs=T.segmented(f,564,{{value=false,label=L.spellOverview},{value=true,label=L.spellCalculation}},
            function() return f.expanded==true end,
            function(v) if v and not U.detailsOn() then return end; f.expanded=v; U.refreshDetail(); f.scroll:ScrollTo(0) end,30)
        f.tabs:SetPoint('TOPLEFT',18,-100)
        f.overview=f.tabs.items[1]; f.calculation=f.tabs.items[2]
        f.descriptionButton=T.button(f,L.spellDescription,250,26,function()
            f.showDescription=not f.showDescription; U.refreshDetail(); f.scroll:ScrollTo(0)
        end)
        f.descriptionButton:SetPoint('BOTTOMLEFT',18,14)
        f.closeButton=T.button(f,L.close,150,26,function() f:Hide() end,'primary'); f.closeButton:SetPoint('BOTTOMRIGHT',-18,14)
        f.scroll,f.child=T.scroll(f,564,350); f.scroll:SetPoint('TOPLEFT',18,-142)
        f.detailText=label(f.child,'',10,-8,530,12)
        f.description=label(f.child,'',10,0,530,12)
        f.rows={}
        f:SetScript('OnUpdate',function(self,elapsed)
            if not self:IsShown() then return end
            self.elapsed=(self.elapsed or 0)+elapsed
            if self.elapsed>=0.5 then self.elapsed=0; U.refreshDetail() end
        end)
        U.detailFrame=f
    end
    local f=U.detailFrame
    if not U.detailEntry or U.detailEntry.id~=r.id then f.expanded=false; f.showDescription=false end
    U.detailEntry=r
    f.icon:SetTexture(r.icon or 134400)
    U.refreshDetail()
    f.scroll:ScrollTo(0); f:Show()
end
function U.refreshDetail()
    local f,r=U.detailFrame,U.detailEntry
    if not f or not r or not f.detailText then return end
    local d=r.data
    local rank=C_Spell and A.call(C_Spell.GetSpellSubtext,r.id) or L.unknown
    f.title:SetText(r.name); f.title:SetTextColor(T.rgb(T.c.text))
    f.meta:SetText((rank or '')..'  ·  '..(L[d.school] or L.unknown)..'  ·  #'..r.id)
    f.tabs:Sync(); f.calculation.disabled=not U.detailsOn()
    f.calculation:SetAlpha(U.detailsOn() and 1 or 0.45)
    local y=0
    for _,row in ipairs(f.rows) do row:Hide() end
    f.detailText:Hide(); f.description:Hide()
    if U.detailsOn() and f.expanded then
        local text=S.Spells.text(r.id,d.kind)
        if text~=f.lastText then f.lastText=text; f.detailText:SetText(text) end
        f.detailText:Show(); y=-f.detailText:GetStringHeight()-24
    elseif U.detailsOn() then
        local colors={hero={1,0.82,0.32},health={1,0.45,0.48},talent={0.80,0.65,1},
            sp={0.36,0.86,1},value={0.95,0.95,1},muted={0.66,0.70,0.78},warning={1,0.72,0.32},
            effective={1,0.31,0.25},mana={0.45,0.7,1},sum={1,1,1}}
        for i,data in ipairs(S.Spells.summary(r.id,d.kind,true)) do
            local row=f.rows[i]
            if not row then
                row=CreateFrame('Frame',nil,f.child); row:SetWidth(546); T.skin(row)
                row.caption=label(row,'',12,-8,220,12)
                row.value=label(row,'',236,-8,298,13); row.value:SetJustifyH('RIGHT')
                f.rows[i]=row
            end
            local prominent=data.tone=='hero' or (data.label==L.spTalentGain)
            local color=colors[data.tone] or colors.value
            row.caption:SetWidth(data.value and 220 or 520); row.caption:SetText(data.label)
            row.caption:SetTextColor(T.rgb(T.c.muted))
            row.value:SetFont(font(),data.tone=='hero' and 25 or (prominent and 19 or 13),'')
            row.value:SetText(data.value or ''); row.value:SetTextColor(color[1],color[2],color[3])
            if not data.value then row.caption:SetTextColor(color[1],color[2],color[3]) end
            local h=math.max(prominent and 48 or 29,row.caption:GetStringHeight()+16,row.value:GetStringHeight()+16)
            row:ClearAllPoints(); row:SetPoint('TOPLEFT',0,y); row:SetHeight(h)
            T.paint(row,prominent and T.c.raised or T.c.card,prominent and T.c.accentDim or T.c.lineSoft)
            row:Show(); y=y-h-4
        end
    end
    if f.showDescription or not U.detailsOn() then
        f.description:ClearAllPoints(); f.description:SetPoint('TOPLEFT',10,y-10)
        f.description:SetText(A.description(r.id) or L.unknown); f.description:Show()
        y=y-f.description:GetStringHeight()-24
    end
    f.scroll:SetContentHeight(-y+10)
end
function U.editEnemy(mode)
    if A.combat() then S.print(L.combat); return end
    if U.enemyEdit==mode then U.enemyEdit=nil; S.db.enemyLocked=true
    else U.enemyEdit=mode; S.db.enemyLocked=false end
    U.syncEnemyEditing()
    S.Options.refresh()
end
function U.syncEnemyEditing()
    if S.db.enemyLocked or A.combat() or not S.db.enabled or not S.db.enemies then
        if U.enemyDrag then U.enemy:StopMovingOrSizing(); U.enemyDrag=nil end
        U.enemyEdit=nil
    end
    if U.enemyEditor then
        U.enemyEditor:SetShown(U.enemyEdit~=nil)
        U.enemyEditor.text:SetText(U.enemyEdit=='resize' and L.enemyResizeHint or L.enemyMoveHint)
    end
    if U.enemyLockHandle then
        local editing=not S.db.enemyLocked and not A.combat()
        U.enemyLockHandle:SetShown(editing)
        U.enemyLockHandle:SetLabel(S.db.enemyLocked and L.enemyEditLabel or L.enemyFinishLabel)
        U.enemyLockHandle:SetActive(not A.combat())
        U.enemyMoveHandle:SetShown(editing)
        U.enemyResizeHandle:SetShown(editing)
        T.paint(U.enemy.header,nil,editing and T.c.gold or T.c.line)
    end
    if U.enemy and U.enemy.scroll then U.layoutHeader() end
end
-- Native cards carry their own backgrounds: the panel only backs the fallback list.
function U.paintPanel()
    local list=not (S.NativeDots.active or S.NativeDots.previewActive)
    local a=list and S.db.enemyBackground and 1 or 0
    U.enemy:SetBackdropColor(T.c.bg[1],T.c.bg[2],T.c.bg[3],a*0.90)
    U.enemy:SetBackdropBorderColor(T.c.line[1],T.c.line[2],T.c.line[3],a)
end
function U.enemyEditorCreate()
    local f=CreateFrame('Frame',nil,U.enemy); U.enemyEditor=f
    f:SetAllPoints(); f:SetFrameLevel(U.enemy:GetFrameLevel()+30)
    f.tint=f:CreateTexture(nil,'OVERLAY'); f.tint:SetAllPoints(); f.tint:SetColorTexture(1,0.8,0.3,0.06)
    f.text=label(f,'',12,-36,250,12)
    f.text:Hide()
    f:EnableMouse(false); f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',function()
        if not U.enemyEdit or S.db.enemyLocked or A.combat() then return end
        local x,y=GetCursorPosition()
        local left,top=U.enemy:GetLeft(),U.enemy:GetTop()
        U.enemy:ClearAllPoints(); U.enemy:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',left,top)
        U.enemyDrag={x=x,y=y,width=S.db.width,health=S.db.healthWidth,height=U.enemy:GetHeight(),mode=U.enemyEdit}
        if U.enemyEdit=='move' then U.enemy:StartMoving() end
    end)
    local function finish()
        if not U.enemyDrag then return end
        local mode=U.enemyDrag.mode; U.enemyDrag=nil; U.enemy:StopMovingOrSizing()
        if mode=='move' or mode=='resize' then
            local x,y=U.enemy:GetCenter(); local px,py=UIParent:GetCenter()
            local scale=U.enemy:GetEffectiveScale()/UIParent:GetEffectiveScale()
            S.db.positions.enemies={x=x-px/scale,y=y-py/scale}
        end
        S.Options.refresh()
    end
    f:SetScript('OnDragStop',finish)
    f:SetScript('OnUpdate',function()
        local d=U.enemyDrag
        if not d or d.mode~='resize' then return end
        if A.combat() or S.db.enemyLocked then finish(); U.syncEnemyEditing(); return end
        local x,y=GetCursorPosition(); local scale=U.enemy:GetEffectiveScale()
        S.db.width=math.max(220,math.min(600,math.floor(d.width+(x-d.x)/scale+0.5)))
        S.db.healthWidth=math.max(100,math.min(600,math.floor(d.health*S.db.width/d.width+0.5)))
        S.db.enemyHeight=math.max(160,math.min(900,math.floor(d.height+(d.y-y)/scale+0.5)))
        S.db.enemyAutoHeight=false
        U.enemy:SetWidth(math.max(S.db.width,S.db.healthWidth+30)+12)
        U.enemyRows(U.enemyUnits or {},U.enemyDemo)
    end)
    U.enemy.grip:Hide()
    local controls=CreateFrame('Frame',nil,U.enemy)
    controls:SetAllPoints(); controls:SetFrameLevel(f:GetFrameLevel()+1); controls:EnableMouse(false)
    local lock=T.button(controls,L.enemyEditLabel,82,20,function()
        if A.combat() then return end
        finish(); S.db.enemyLocked=not S.db.enemyLocked
        U.enemyEdit=S.db.enemyLocked and nil or 'move'
        U.syncEnemyEditing(); S.Options.refresh()
    end,'primary')
    lock:SetPoint('TOPRIGHT',-4,-3)
    U.enemyLockHandle=lock
    local function handle(texture,mode,hint)
        local b=T.button(controls,'',24,20,function() end)
        b.glyph=b:CreateTexture(nil,'OVERLAY'); b.glyph:SetSize(14,14); b.glyph:SetPoint('CENTER'); b.glyph:SetTexture(texture)
        b:RegisterForDrag('LeftButton')
        b:SetScript('OnDragStart',function()
            if S.db.enemyLocked or A.combat() then return end
            U.enemyEdit=mode; U.syncEnemyEditing(); f:GetScript('OnDragStart')()
        end)
        b:SetScript('OnDragStop',finish)
        T.tooltip(b,hint)
        return b
    end
    U.enemyMoveHandle=handle('Interface\\CURSOR\\UI-Cursor-Move','move',L.enemyMoveHint)
    U.enemyMoveHandle:SetPoint('RIGHT',lock,'LEFT',-4,0)
    U.enemyResizeHandle=handle('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up','resize',L.enemyResizeHint)
    U.enemyResizeHandle:SetPoint('RIGHT',U.enemyMoveHandle,'LEFT',-4,0)
    f:Hide()
end
-- The header is optional, but always shown while the frame is unlocked so the
-- move/resize/lock handles stay reachable.
function U.headerShown() return S.db.enemyHeader or (not S.db.enemyLocked and not A.combat()) end
function U.layoutHeader()
    local shown=U.headerShown()
    U.enemy.header:SetShown(shown)
    U.headerOffset=shown and 28 or 0
    U.enemy.scroll:ClearAllPoints(); U.enemy.scroll:SetPoint('TOPLEFT',2,-(shown and 28 or 4)); U.enemy.scroll:SetPoint('BOTTOMRIGHT',-2,6)
end
function U.layout()
    S.Nightfall.layout()
    U.enemy:SetScale(S.db.scale); U.enemy:SetAlpha(S.db.opacity)
    if not A.combat() then
        U.counter:SetScale(S.db.scale); U.counter:SetAlpha(S.db.opacity)
        U.counter:SetShown(S.db.enabled and ((S.db.shards and S.db.compact) or S.db.kit.enabled))
        U.counter.combatGrip:SetAttribute('movable',not S.db.locked)
        U.counter.combatGrip:SetAttribute('scale',S.db.scale)
    end
    U.showMinimap()
    U.enemy:SetShown(S.legacyEnemies and S.db.enabled and S.db.enemies)
    U.enemy.header.sfBg:SetAlpha(S.db.enemyBackground and 1 or 0)
    U.syncEnemyEditing()
    U.paintPanel()
    U.enemy:SetWidth(math.max(S.db.width,S.db.healthWidth+30)+12)
    U.enemy.title:SetWidth(U.enemy:GetWidth()-(S.db.enemyLocked and 60 or 150))
    U.positionMinimap()
end
function U.positionMinimap()
    if not U.minimap then return end -- LibDBIcon places its own button.
    local angle=math.rad(S.db.angle)
    U.minimap:ClearAllPoints(); U.minimap:SetPoint('CENTER',Minimap,'CENTER',math.cos(angle)*80,math.sin(angle)*80)
end
function U.showMinimap()
    if U.broker then
        pcall(S.db.minimap and U.broker.Show or U.broker.Hide,U.broker,U.BROKER_NAME)
    elseif U.minimap then U.minimap:SetShown(S.db.minimap) end
end
local function createEnemyFrame()
    U.enemy=panel('FelkitEnemies',338,90); U.anchor(U.enemy,'enemies',360,40)
    local header=CreateFrame('Frame',nil,U.enemy); header:SetPoint('TOPLEFT',1,-1); header:SetPoint('TOPRIGHT',-1,-1); header:SetHeight(24)
    T.skin(header,T.c.side,T.c.line); U.enemy.header=header
    header:EnableMouse(false)
    U.enemy.icon=T.icon(header,'Interface\\Icons\\Spell_Shadow_AbominationExplosion',16); U.enemy.icon:SetPoint('LEFT',6,0)
    U.enemy.title=T.text(header,12); U.enemy.title:SetPoint('LEFT',U.enemy.icon,'RIGHT',6,0); U.enemy.title:SetText(L.enemies)
    U.enemy.badge=T.text(header,11,T.c.gold); U.enemy.badge:SetPoint('RIGHT',-10,0); U.enemy.badge:SetJustifyH('RIGHT')
    U.enemy.scroll=CreateFrame('ScrollFrame',nil,U.enemy,'DisableUntrustedLayoutScriptsTemplate')
    U.enemy.scroll:EnableMouseWheel(true)
    U.enemy.scroll:SetScript('OnMouseWheel',function(self,delta)
        self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*36)))
    end)
    U.enemy.scroll:SetPoint('TOPLEFT',2,-28); U.enemy.scroll:SetPoint('BOTTOMRIGHT',-2,6)
    U.enemy.body=CreateFrame('Frame',nil,U.enemy.scroll); U.enemy.body:SetSize(310,60)
    U.enemy.scroll:SetScrollChild(U.enemy.body)
    U.enemy.footer=label(U.enemy.body,'',8,-3,310)
    U.enemy.footer:SetTextColor(T.rgb(T.c.muted))
    U.enemy.rows={}
    U.enemyEditorCreate()
    U.layoutHeader()
end
local function minimapClick(button)
    if button=='RightButton' then S.Options.open('enemies') else S.Options.toggle() end
end
local function minimapTooltip(tip)
    tip:AddLine(L.title)
    tip:AddLine(U.countString or L.loading,1,1,1)
    tip:AddLine(L.minimapHelp,0.8,0.65,1,true)
end
-- The standard LibDBIcon button when another add-on already loaded the library
-- (no copy is embedded here). Minimap button collectors such as Leatrix Plus
-- then show the add-on's name and tooltip instead of a frame name.
U.BROKER_NAME='Felkit'
local function createBrokerMinimap()
    local stub=rawget(_G,'LibStub')
    if type(stub)~='table' or type(stub.GetLibrary)~='function' then return false end
    local okLdb,ldb=pcall(stub.GetLibrary,stub,'LibDataBroker-1.1',true)
    local okIcon,icon=pcall(stub.GetLibrary,stub,'LibDBIcon-1.0',true)
    if not okLdb or not okIcon or type(ldb)~='table' or type(icon)~='table' then return false end
    if type(ldb.NewDataObject)~='function' or type(icon.Register)~='function'
        or type(icon.Show)~='function' or type(icon.Hide)~='function' then return false end
    local ok=pcall(function()
        local object=ldb:NewDataObject(U.BROKER_NAME,{type='launcher',label=U.BROKER_NAME,
            icon=S.Theme.resolveIcon(S.Theme.I.warlock) or 134400,
            OnClick=function(_,button) minimapClick(button) end,
            OnTooltipShow=function(tip) if tip and tip.AddLine then minimapTooltip(tip) end end})
        if not object then error('data object already exists') end
        S.db.minimapIcon.hide=not S.db.minimap
        icon:Register(U.BROKER_NAME,object,S.db.minimapIcon)
    end)
    if ok then U.broker=icon end
    return ok
end
local function createMinimap()
    if createBrokerMinimap() then return end
    U.minimap=CreateFrame('Button','FelkitMinimap',Minimap); U.minimap:SetSize(31,31); U.minimap:SetFrameStrata('MEDIUM')
    U.minimap:SetFrameLevel(8)
    local bg=U.minimap:CreateTexture(nil,'BACKGROUND'); bg:SetSize(20,20); bg:SetPoint('CENTER')
    bg:SetTexture('Interface\\Minimap\\UI-Minimap-Background')
    local icon=U.minimap:CreateTexture(nil,'ARTWORK'); icon:SetSize(19,19); icon:SetPoint('CENTER')
    icon:SetTexCoord(0.08,0.92,0.08,0.92); S.Theme.setIcon(icon,S.Theme.I.warlock); U.minimap.icon=icon
    local border=U.minimap:CreateTexture(nil,'OVERLAY'); border:SetSize(53,53); border:SetPoint('TOPLEFT')
    border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
    U.minimap:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
    U.minimap:RegisterForClicks('LeftButtonUp','RightButtonUp')
    U.minimap:SetScript('OnClick',function(_,button) minimapClick(button) end)
    U.minimap:RegisterForDrag('LeftButton')
    U.minimap:SetScript('OnDragStart',function(self)
        self:SetScript('OnUpdate',function()
            local x,y=GetCursorPosition(); local mx,my=Minimap:GetCenter(); local scale=Minimap:GetEffectiveScale()
            S.db.angle=(math.deg(math.atan2(y/scale-my,x/scale-mx))+360)%360; U.positionMinimap()
        end)
    end)
    U.minimap:SetScript('OnDragStop',function(self) self:SetScript('OnUpdate',nil) end)
    U.minimap:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_LEFT'); GameTooltip:ClearLines()
        minimapTooltip(GameTooltip); GameTooltip:Show()
    end)
    U.minimap:SetScript('OnLeave',function() GameTooltip:Hide() end)
end
-- Moving the counter, and the kit anchored to it, in combat. Insecure code may
-- not move it then, so a secure button covers the shard during combat. Press:
-- note the mouse and cover the whole screen, so the release lands on it too.
-- Release: shrink back, then move the counter by the mouse travel (kept on
-- screen), or open/close the kit when the mouse hardly moved (a click).
local COMBAT_MOVE=[[
    if button ~= 'LeftButton' then return end
    local screen=self:GetFrameRef('screen'); local counter=self:GetFrameRef('counter')
    if down then
        startX,startY=screen:GetMousePosition()
        if self:GetAttribute('movable') then self:ClearAllPoints(); self:SetAllPoints(screen) end
        return
    end
    local x0,y0=startX,startY; startX,startY=nil,nil
    self:ClearAllPoints(); self:SetAllPoints(counter)
    self:SetAttribute('dragged',false)
    local mx,my=screen:GetMousePosition()
    local W,H=screen:GetWidth(),screen:GetHeight()
    local dx,dy=0,0
    if x0 and y0 and mx and my then dx,dy=(mx-x0)*W,(my-y0)*H end
    if dx*dx+dy*dy>=64 then
        self:SetAttribute('dragged',true)
        if not self:GetAttribute('movable') then return end
        local l,b,w,h=counter:GetRect()
        if not l then return end
        local k=self:GetAttribute('scale') or 1
        local hw,hh=w*k/2,h*k/2
        local cx,cy=(l+w/2)*k+dx,(b+h/2)*k+dy
        if cx<hw then cx=hw elseif cx>W-hw then cx=W-hw end
        if cy<hh then cy=hh elseif cy>H-hh then cy=H-hh end
        counter:ClearAllPoints(); counter:SetPoint('CENTER',screen,'BOTTOMLEFT',cx/k,cy/k)
        self:SetAttribute('moved',true)
    elseif not IsShiftKeyDown() and self:GetAttribute('kitEnabled') then
        local kit=self:GetFrameRef('kit')
        if kit then
            if kit:IsShown() then kit:Hide() else kit:Show() end
            local header=self:GetFrameRef('header')
            for i=1,header:GetAttribute('menus') do header:GetFrameRef('menu'..i):Hide() end
        end
    end
]]
function U.saveCounter()
    local x,y=U.counter:GetCenter(); local px,py=UIParent:GetCenter()
    if not x or not px then return end
    local ratio=U.counter:GetEffectiveScale()/UIParent:GetEffectiveScale()
    S.db.positions.counter={x=x-px/ratio,y=y-py/ratio}
    U.counter:ClearAllPoints(); U.counter:SetPoint('CENTER',UIParent,'CENTER',S.db.positions.counter.x,S.db.positions.counter.y)
end
local function combatGrip(shard)
    local screen=CreateFrame('Frame',nil,UIParent,'SecureFrameTemplate'); screen:SetAllPoints(UIParent)
    local grip=CreateFrame('Button',nil,U.counter,'SecureHandlerClickTemplate,SecureHandlerStateTemplate')
    grip:SetAllPoints(U.counter); grip:SetFrameLevel(shard:GetFrameLevel()+5)
    grip:RegisterForClicks('LeftButtonDown','LeftButtonUp','RightButtonUp')
    SecureHandlerSetFrameRef(grip,'screen',screen); SecureHandlerSetFrameRef(grip,'counter',U.counter)
    grip:SetAttribute('movable',not S.db.locked); grip:SetAttribute('scale',S.db.scale)
    grip:SetAttribute('_onclick',COMBAT_MOVE)
    grip:HookScript('OnClick',function(self,mouseButton,down)
        if mouseButton=='RightButton' then U.openKit()
        elseif mouseButton=='LeftButton' and not down and self:GetAttribute('dragged')~=true
            and A.call(IsShiftKeyDown)==true then S.prune() end
    end)
    grip:SetScript('OnEnter',function() local f=shard:GetScript('OnEnter'); if f then f(shard) end end)
    grip:SetScript('OnLeave',function() GameTooltip:Hide() end)
    grip:SetAttribute('_onstate-combat',[[if newstate == '1' then self:Show() else self:Hide() end]])
    RegisterStateDriver(grip,'combat','[combat] 1; 0')
    -- Saved once combat ends, when the game reports the new spot reliably.
    local after=CreateFrame('Frame'); after:RegisterEvent('PLAYER_REGEN_ENABLED')
    after:SetScript('OnEvent',function()
        if grip:GetAttribute('moved') then grip:SetAttribute('moved',nil); U.saveCounter() end
    end)
    U.counter.combatGrip=grip
end
-- Spell details belong to the grimoire: switching the grimoire off turns them off too.
function U.detailsOn() return S.db.spellDetails and S.db.grimoire end
local function createCounter()
    U.counter=CreateFrame('Frame','FelkitCounter',UIParent,'SecureFrameTemplate')
    U.counter:SetSize(46,46); U.counter:SetClampedToScreen(true); U.anchor(U.counter,'counter',0,-190)
    U.counter.grip:Hide()
    local shard=CreateFrame('Button','FelkitShardIcon',U.counter,'SecureHandlerBaseTemplate')
    U.counter.icon=shard; shard:SetAllPoints()
    U.counter.text=label(shard,'',0,0,44,18)
    -- Centred on the shard, large and thick-outlined so it reads over the gem.
    U.counter.text:ClearAllPoints(); U.counter.text:SetPoint('CENTER',0,0); U.counter.text:SetJustifyH('CENTER')
    U.counter.text:SetWidth(60); U.counter.text:SetFont(font(),26,'THICKOUTLINE')
    U.counter.halo=U.halo(shard,1,0.78,0.15)
    local icon=C_Item and A.call(C_Item.GetItemIconByID,6265)
    shard:SetNormalTexture(icon or 'Interface\\Icons\\INV_Misc_Gem_Amethyst_02')
    shard:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
    shard:RegisterForClicks('LeftButtonUp','RightButtonUp')
    shard:RegisterForDrag('LeftButton')
    shard:SetScript('OnDragStart',function()
        if not S.db.locked and not A.combat() then U.counter:StartMoving() end
    end)
    shard:SetScript('OnDragStop',function()
        if A.combat() then return end
        U.counter:StopMovingOrSizing(); U.saveCounter()
    end)
    shard:SetScript('OnClick',function(_,mouseButton)
        if mouseButton=='RightButton' then U.openKit()
        elseif mouseButton=='LeftButton' and A.call(IsShiftKeyDown)==true then S.prune() end
    end)
    shard:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_TOP'); GameTooltip:SetText(L.shards)
        GameTooltip:AddLine(U.countString or L.loading,1,1,1)
        GameTooltip:AddLine(L.shardClickHelp,0.8,0.65,1,true); GameTooltip:Show()
    end)
    shard:SetScript('OnLeave',function() GameTooltip:Hide() end)
    combatGrip(shard)
end
function U.create()
    S.Options.create(); U.main=S.Options.frame
    U.pages=S.Options.pages
    createCounter()
    createEnemyFrame()
    createMinimap()
    U.alert=S.Nightfall.create()
    U.layout()
end
-- items: the scan that gave total; excess: already known (no scan at all).
function U.count(total,items,excess)
    -- Excess = what may go: shards in a soul bag are never deleted.
    if excess==nil then
        local scanned=total
        if not items then items,scanned=A.inventory() end
        excess=total and scanned==total and S.Model.excess(items,total,S.db.keep,S.db.pruneSoulBag)
    end
    U.countString=string.format(L.count,total and tostring(total) or '?',S.db.keep,excess and tostring(excess) or '?')
    -- Same count, excess and settings: the counter already shows it.
    local key=U.countString..tostring(S.settingsVersion)
    if U.countKey==key then return end
    U.countKey=key
    U.counter.text:SetText(total and tostring(total) or '?')
    -- Red when empty; bright gold with a halo when there is excess to delete.
    if total==0 then U.counter.text:SetTextColor(1,0.22,0.18)
    elseif excess and excess>0 then U.counter.text:SetTextColor(1,0.84,0.1)
    else U.counter.text:SetTextColor(T.rgb(T.c.text)) end
    U.counter.text:SetFont(font(),excess and excess>0 and 30 or 26,'THICKOUTLINE')
    U.setHalo(U.counter.halo,excess and excess>0,U.counter:GetWidth())
    S.Options.refresh()
end
local function fitHeight(content)
    local screen=math.max(160,UIParent:GetHeight()/S.db.scale-100)
    U.enemy:SetHeight(math.min(S.db.enemyAutoHeight and content or S.db.enemyHeight,screen,S.db.enemyHeight))
end
function U.enemyRows(units,demo)
    U.enemyUnits=units; U.enemyDemo=demo
    local shown=math.min(#units,S.db.maxEnemies)
    U.enemy.badge:SetText(#units>0 and (#units>shown and (shown..'+') or tostring(shown)) or '')
    local preview=demo=='preview'
    if (preview or not demo) and S.NativeDots.render(units,preview) then
        U.enemy.title:SetText(preview and L.previewTitle or L.enemies)
        U.enemy.body:Hide(); U.enemy.scroll:Hide()
        -- Cards hang below the header and size themselves; the frame keeps only its header.
        U.enemy:SetHeight(U.headerShown() and 26 or 1); U.paintPanel()
        return
    end
    U.enemy.scroll:Show()
    local wasNative=S.NativeDots.active
    S.NativeDots.stop(); U.paintPanel(); U.enemy.body:Show(); U.enemy.scroll:SetScrollChild(U.enemy.body)
    if wasNative then U.enemy.scroll:SetVerticalScroll(0) end
    local compact=S.db.enemyStyle~=1
    local y=6; local limit=S.db.maxEnemies; local width=S.db.width-30; local h=compact and math.max(18,S.db.rowHeight-4) or S.db.rowHeight
    local parent=U.enemy.body
    U.enemy.title:SetText(demo and L.demoLabel or L.enemies)
    local longestDuration=0
    local now=GetTime()
    if S.db.dotDurationMode==2 then
        for i=1,math.min(#units,limit) do
            for j,a in ipairs(units[i].effects or {}) do
                if j>16 then break end
                if a.duration and a.expires and a.expires>now then longestDuration=math.max(longestDuration,a.duration) end
            end
        end
    end
    -- Keep the total-duration reference while this set is active. Expiration or
    -- loss of the longest enemy never stretches surviving bars. A newly longer
    -- duration can extend the scale; an empty set or mode change starts it afresh.
    if S.db.dotDurationMode~=2 or longestDuration==0 then U.dotScale=nil
    else U.dotScale=math.max(U.dotScale or 0,longestDuration) end
    for i=1,math.min(#units,limit) do
        local u=units[i]; local r=U.enemy.rows[i]
        if not r then
            local card=CreateFrame('Frame',nil,parent,'BackdropTemplate'); card:SetFrameLevel(parent:GetFrameLevel()); card:EnableMouse(false)
            card:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
            r={card=card,health=bar(parent,h),nativeHealth=bar(parent,5),forecast=bar(parent,4),effects={}}
            r.nativeHealth:SetStatusBarColor(0.20,0.55,0.36); r.forecast:SetStatusBarColor(0.8,0.5,1)
            -- Edge-only overlay encloses health and effects without intercepting clicks.
            r.outline=CreateFrame('Frame',nil,parent,'BackdropTemplate')
            r.outline:SetFrameLevel(parent:GetFrameLevel()+5); r.outline:EnableMouse(false)
            r.outline:SetBackdrop({edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=2})
            r.outline:SetBackdropBorderColor(1,0.80,0.30,1)
            U.enemy.rows[i]=r
        end
        local rowTop=y; y=y+(compact and 2 or 7); r.guid=u.guid; r.card:Show()
        -- The minimal style keeps an invisible card: it bounds the click-to-target area.
        local plain=S.db.enemyStyle~=3
        r.card:SetBackdropColor(T.c.card[1],T.c.card[2],T.c.card[3],plain and S.db.enemyBackground and 0.94 or 0)
        r.card:SetBackdropBorderColor(T.c.line[1],T.c.line[2],T.c.line[3],plain and S.db.enemyBorder and 0.9 or 0)
        r.health.bg:SetShown(S.db.enemyBackground); r.nativeHealth.bg:SetShown(S.db.enemyBackground)
        local markers=S.db.dotMarkers and ((u.focus and ' [F]' or '')..(u.pet and ' [P]' or '')) or ''
        local title=u.name..markers
        local separate=S.db.enemyNameHeader or not S.db.dotHealth
        r.health:SetShown(separate)
        if separate then
            r.health:ClearAllPoints(); r.health:SetPoint('TOPLEFT',10,-y)
            setbar(r.health,title,nil,math.max(width,S.db.healthWidth),h); A.setName(r.health.text,u,markers); y=y+h+3
            r.health.text:SetWordWrap(false); r.health.text:SetMaxLines(1)
            r.health.text:SetFont(font(),S.db.fontSize,'OUTLINE')
        end
        local hw,hh=S.db.healthWidth,S.db.healthHeight
        r.nativeHealth:ClearAllPoints(); r.nativeHealth:SetPoint('TOPLEFT',10,-y); r.nativeHealth:SetSize(hw,hh)
        if not r.nameText then r.nameText=label(r.nativeHealth,'',0,0,100,10) end
        r.nameText:SetShown(not separate)
        local nameWidth=separate and 0 or math.floor(hw*(S.db.healthMode==5 and 0.30 or 0.36))
        r.nameText:ClearAllPoints(); r.nameText:SetPoint('LEFT',r.nativeHealth,'LEFT',4,0)
        r.nameText:SetSize(math.max(1,nameWidth-8),hh-2); r.nameText:SetJustifyH('LEFT')
        r.nameText:SetWordWrap(false); r.nameText:SetNonSpaceWrap(false); r.nameText:SetMaxLines(1)
        r.nameText:SetFont(font(),math.min(10,S.db.fontSize-2,hh-2),'OUTLINE')
        A.setName(r.nameText,u,markers)
        r.nativeHealth.text:ClearAllPoints(); r.nativeHealth.text:SetPoint('RIGHT',r.nativeHealth,'RIGHT',-4,0)
        r.nativeHealth.text:SetSize(hw-nameWidth-8,hh-2); r.nativeHealth.text:SetJustifyH(separate and 'CENTER' or 'RIGHT')
        r.nativeHealth.text:SetWordWrap(false); r.nativeHealth.text:SetNonSpaceWrap(false); r.nativeHealth.text:SetMaxLines(1)
        r.nativeHealth.text:SetFont(font(),math.min(S.db.fontSize,hh-2),'OUTLINE')
        r.forecast:ClearAllPoints(); r.forecast:SetPoint('TOPLEFT',10,-y-hh-1); r.forecast:SetSize(hw,4)
        local shown=false
        if S.db.dotHealth and not demo then shown=S.Tracker.health(r.nativeHealth,r.forecast,u.token,u.guid,nil)
        else r.nativeHealth:Hide(); r.forecast:Hide() end
        if demo and S.db.dotHealth and u.hp and u.max then
            r.nativeHealth:SetMinMaxValues(0,u.max); r.nativeHealth:SetValue(u.hp); r.nativeHealth:Show(); shown=true
            local hp=S.db.healthMode==5 and string.format('%d (%.0f%%) / %d',u.hp,u.hp/u.max*100,u.max) or S.db.healthMode==4 and string.format('%d (%.0f%%)',u.hp,u.hp/u.max*100) or S.db.healthMode==3 and string.format('%.0f%%',u.hp/u.max*100) or
                (S.db.healthMode==2 and tostring(u.hp) or (u.hp..' / '..u.max))
            r.nativeHealth.text:SetText(hp)
        elseif shown then S.Tracker.healthText(r.nativeHealth.text,u.token,u.guid,S.db.healthMode)
        else r.nativeHealth.text:SetText('') end
        if shown then y=y+hh+3 end
        local effects=u.effects or {}
        local visible=0
        for j,a in ipairs(effects) do
            if j>16 then break end
            visible=j
            local b=r.effects[j]
            if not b then
                b=bar(parent,h); r.effects[j]=b
                b.timer=label(b,'',0,0,60,12); b.timer:SetJustifyH('RIGHT')
                b.lastTick=b:CreateTexture(nil,'ARTWORK'); b.lastTick:SetPoint('BOTTOMLEFT',1,1); b.lastTick:SetSize(3,7); b.lastTick:SetColorTexture(1,0.78,0.22,1); b.lastTick:Hide()
                b:EnableMouse(true)
                b:SetScript('OnEnter',function(self)
                    if not self.aura then return end
                    GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
                    if self.aura.native then GameTooltip:SetText(self.aura.nativeName)
                    else GameTooltip:SetText(self.aura.name or A.spell(self.aura.id)) end
                    GameTooltip:AddLine(L.dotTickHelp,0.85,0.85,0.9,true)
                    if self.aura.interval then GameTooltip:AddLine(string.format(L.dotTickInterval,self.aura.interval),1,0.82,0.32) end
                    if self.nextTick then GameTooltip:AddLine(string.format(L.dotNextTick,self.nextTick),1,0.82,0.32) end
                    GameTooltip:Show()
                end)
                b:SetScript('OnLeave',function() GameTooltip:Hide() end)
            end
            b:Show(); b:ClearAllPoints(); b:SetPoint('TOPLEFT',32,-y)
            if a.native then pcall(b.icon.SetTexture,b.icon,a.nativeIcon)
            else b.icon:SetTexture(a.icon or select(2,A.spell(a.id))) end
            b.icon:Show()
            b.aura=a; b:SetWidth(width-22); b:SetHeight(h)
            b.icon:SetSize(h-2,h-2); b.icon:SetTexCoord(0.08,0.92,0.08,0.92)
            b.icon:SetShown(S.db.enemyStyle~=3); b.bg:SetShown(S.db.enemyBackground)
            local remaining=a.expires and math.max(0,a.expires-now)
            U.dotTime(b,a,remaining,U.dotScale,width-22,h)
            U.dotStyle(b,a,remaining); y=y+h+(compact and 2 or 4)
        end
        for j=visible+1,#r.effects do r.effects[j]:Hide(); r.effects[j].aura=nil end
        if not r.note then r.note=label(parent,'',10,0,width); r.note:SetTextColor(T.rgb(T.c.muted)) end
        local note=(not u.aurasKnown and #effects==0 and L.effectsUnknown) or (#effects>16 and ('+ '..(#effects-16)..' '..L.periodic))
        r.note:SetShown(note~=nil and note~=false)
        if note then r.note:ClearAllPoints(); r.note:SetPoint('TOPLEFT',10,-y); r.note:SetWidth(width); r.note:SetText(note); y=y+18 end
        y=y+(compact and 2 or 5)
        r.card:ClearAllPoints(); r.card:SetPoint('TOPLEFT',4,-rowTop+2)
        r.card:SetSize(math.max(width,S.db.healthWidth)+12,y-rowTop+4)
        r.outline:ClearAllPoints(); r.outline:SetPoint('TOPLEFT',4,-rowTop+2)
        r.outline:SetSize(r.card:GetWidth(),r.card:GetHeight())
        A.outlineTarget(r.outline,u,S.db.enemyBorder and S.db.dotSelectionFrame)
        y=y+S.db.spacing
    end
    for i=math.min(#units,limit)+1,#U.enemy.rows do
        local r=U.enemy.rows[i]; r.card:Hide(); r.outline:Hide(); r.guid=nil; r.health:Hide(); r.nativeHealth:Hide(); r.forecast:Hide(); if r.forecastText then r.forecastText:Hide() end; if r.note then r.note:Hide() end
        for _,b in ipairs(r.effects) do b:Hide(); b.aura=nil end
    end
    local clicks={}
    if not demo then
        for i=1,math.min(#units,limit) do local r=U.enemy.rows[i]; clicks[i]={frame=r.card,token=units[i].token,bars=r.effects} end
    end
    S.CardClick.set(clicks,U.enemy.scroll)
    U.enemy.footer:ClearAllPoints(); U.enemy.footer:SetPoint('TOPLEFT',8,-y); U.enemy.footer:SetWidth(width)
    local footer=#units>limit and string.format(L.more,#units-limit) or ''
    -- The public fallback cannot read protected auras in combat: say so instead of staying silent.
    local blind=not demo and S.NativeDots.failed and S.db.enemies and
        (A.combat() or (C_Secrets and A.call(C_Secrets.ShouldAurasBeSecret)==true))
    if blind then footer=(footer~='' and (footer..'\n') or '')..L.nativeUnavailable end
    U.enemy.footer:SetText(footer); U.enemy.footer:SetShown(footer~='')
    local footerHeight=footer~='' and (blind and 44 or 30) or 4
    U.enemy.body:SetSize(math.max(S.db.width,S.db.healthWidth+30),y+footerHeight)
    fitHeight(y+(U.headerOffset or 28)+10+footerHeight)
end
-- Fixed total track; only its fill and numeric countdown change with time.
function U.nativeDotText(b,a)
    -- The duration object may return a secret number. Only native formatting
    -- receives it: no branching, comparisons, concatenation or GetText roundtrip.
    local ok=pcall(function() b.timer:SetFormattedText('%.1fs',a.nativeDuration:GetRemainingDuration()) end)
    if not ok then b.timer:SetText('?') end
end
function U.dotTime(b,a,remaining,longest,width,height)
    if b.nativeFill then b.nativeFill:Hide() end
    if a.native then
        b:SetSize(width,height); b:SetMinMaxValues(0,1); b:SetValue(0)
        if not b.nativeFill then
            b.nativeFill=CreateFrame('StatusBar',nil,b)
            b.nativeFill:Hide(); b.nativeFill:EnableMouse(false)
            b.nativeFill:SetAllPoints(); b.nativeFill:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
            b.nativeFill:SetStatusBarColor(T.rgb(T.c.accent))
            b.nativeFill:SetFrameLevel(b:GetFrameLevel()+1)
            local overlay=CreateFrame('Frame',nil,b); overlay:SetAllPoints(); overlay:SetFrameLevel(b:GetFrameLevel()+2)
            overlay:EnableMouse(false); b.text:SetParent(overlay); b.timer:SetParent(overlay)
        end
        b.text:ClearAllPoints(); b.text:SetPoint('LEFT',b,'LEFT',6,0); b.text:SetWidth(math.max(20,width-70))
        b.text:SetWordWrap(false); b.text:SetMaxLines(1)
        b.text:SetFont(font(),math.min(S.db.fontSize,height-4),'OUTLINE')
        b.text:SetText('?'); pcall(b.text.SetText,b.text,a.nativeName)
        b.timer:ClearAllPoints(); b.timer:SetPoint('LEFT',b,'LEFT',width-62,0); b.timer:SetSize(58,height-2)
        b.timer:SetFont(font(),math.min(S.db.fontSize+1,height-3),'OUTLINE')
        local direction=Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
        if direction and type(b.nativeFill.SetTimerDuration)=='function' then
            local ok=pcall(b.nativeFill.SetTimerDuration,b.nativeFill,a.nativeDuration,0,direction)
            b.nativeFill:SetShown(ok)
        end
        b.timeScale=nil; b.lastTimeText=nil; U.nativeDotText(b,a)
        return
    end
    local proportional=S.db.dotDurationMode==2
    local barWidth=width
    local ratio=remaining and a.duration and a.duration>0 and remaining/a.duration
    b.timeScale=a.duration; b.fullWidth=width
    if proportional then
        b.timeScale=longest
        if a.duration and longest and longest>0 then barWidth=math.max(1,width*a.duration/longest) end
    end
    setbar(b,(a.name or A.spell(a.id))..'  '..(remaining and string.format('%.1fs',remaining) or '?'),ratio,barWidth,height)
    b.text:SetWidth(width-8); b.text:SetWordWrap(false); b.text:SetMaxLines(1)
    if b.timer then
        b.text:SetText(a.name or A.spell(a.id)); b.text:SetWidth(math.max(20,width-70))
        b.text:ClearAllPoints(); b.text:SetPoint('LEFT',b,'LEFT',6,0)
        b.text:SetFont(font(),math.min(S.db.fontSize,height-4),'OUTLINE')
        b.timer:ClearAllPoints(); b.timer:SetPoint('LEFT',b,'LEFT',width-62,0); b.timer:SetSize(58,height-2)
        b.timer:SetFont(font(),math.min(S.db.fontSize+1,height-3),'OUTLINE')
        b.timer:SetText(remaining and string.format('%.1fs',remaining) or '?')
        b.lastTimeText=b.timer:GetText()
    end
    if a.channel then b.text:SetText(b.text:GetText()..' · '..L.channelTimer) end
    if a.predicted then b.text:SetText('~ '..b.text:GetText()) end
end
function U.dotStyle(b,a,remaining)
    local warn=S.db.dotWarnings and remaining and remaining<=(a.interval or S.db.dotWarning)
    local family=S.Data.dotFamilies[a.id] or a.id
    if warn then b:SetStatusBarColor(0.85,0.29,0.14)
    elseif family==348 then b:SetStatusBarColor(0.80,0.40,0.15)
    elseif family==689 or family==18265 then b:SetStatusBarColor(0.25,0.62,0.38)
    else b:SetStatusBarColor(T.c.accent[1],T.c.accent[2],T.c.accent[3]) end
    if b.timer then b.timer:SetTextColor(1,warn and 0.63 or 0.94,warn and 0.35 or 0.98) end
    b:SetAlpha(warn and S.db.dotPulse and (0.65+0.35*math.abs(math.sin(GetTime()*4))) or 1)
    local n=0; local nextMark,nextSeconds; b.nextTick=nil
    if S.db.dotTicks and a.interval and a.duration and a.duration>0 then
        for i=1,math.min(30,a.channel and (a.count-1) or (math.ceil(a.duration/a.interval)-1)) do
            local seconds=a.channel and (a.expires-a.tickStart-i*a.interval) or i*a.interval
            local pixels=b.timeScale and b.timeScale>0 and seconds/b.timeScale*b.fullWidth or 0
            if pixels>0 and pixels<b:GetWidth() then
                n=n+1; local mark=b.marks[n]
                if not mark then mark=b:CreateTexture(nil,'ARTWORK'); mark:SetColorTexture(1,1,1,0.5); b.marks[n]=mark end
                mark:ClearAllPoints(); mark:SetPoint('BOTTOMLEFT',b,'BOTTOMLEFT',pixels,0); mark:SetSize(2,b:GetHeight()); mark:SetColorTexture(0.94,0.94,1,0.8); mark:Show()
                if remaining and seconds>=remaining then mark:SetColorTexture(0.45,0.48,0.56,0.35) end
                if remaining and seconds<remaining and (not nextSeconds or seconds>nextSeconds) then nextMark=mark; nextSeconds=seconds end
            end
        end
    end
    for i=n+1,#b.marks do b.marks[i]:Hide() end
    if nextMark then nextMark:SetSize(3,b:GetHeight()); nextMark:SetColorTexture(1,0.78,0.22,1); b.nextTick=remaining-nextSeconds end
    -- Final tick at the left boundary, only if it is part of the known schedule.
    local final=0
    if a.channel then final=a.count and a.tickStart and a.interval and a.expires-a.tickStart-a.count*a.interval or -1 end
    local last=S.db.dotTicks and a.interval and a.duration and a.duration>0 and b.timeScale and b.timeScale>0 and remaining and remaining>0 and not nextMark and final>=0 and final<remaining
    if b.lastTick then
        b.lastTick:SetShown(last==true)
        if last then
            b.lastTick:ClearAllPoints(); b.lastTick:SetPoint('BOTTOMLEFT',math.max(1,final/(b.timeScale or a.duration)*b.fullWidth),0); b.lastTick:SetHeight(b:GetHeight())
        end
    end
    if last then b.nextTick=remaining-final end
end
function U.animate(now)
    if not U.enemy or not U.enemy:IsShown() then return end
    if S.NativeDots.active or S.NativeDots.previewActive then S.NativeDots.animate(now); return end
    for _,r in ipairs(U.enemy.rows) do
        for _,b in ipairs(r.effects) do
            local a=b.aura
            if a and b:IsShown() and a.expires then
                local remaining=math.max(0,a.expires-now)
                if remaining==0 then b:Hide()
                else b:SetValue(a.duration and a.duration>0 and math.min(1,remaining/a.duration) or 0) end
            end
        end
    end
end
function U.tick(now,alreadyAnimated)
    if not alreadyAnimated then U.animate(now) end
    S.Ticks.render(S.channel,now)
    if U.enemy:IsShown() and not S.NativeDots.active and not S.NativeDots.previewActive then
        for _,r in ipairs(U.enemy.rows) do
            for _,b in ipairs(r.effects) do
                local a=b.aura
                if a and b:IsShown() and a.native then U.nativeDotText(b,a)
                elseif a and b:IsShown() and a.expires then
                    local remaining=math.max(0,a.expires-now)
                    if remaining<=0 then b:Hide() else
                        local text=string.format('%.1fs',remaining)
                        if b.timer and text~=b.lastTimeText then b.timer:SetText(text); b.lastTimeText=text end
                        U.dotStyle(b,a,remaining)
                    end
                end
            end
        end
    end
end
