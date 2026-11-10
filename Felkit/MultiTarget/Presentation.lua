-- Original Warlock All-in-One presentation adapter (MIT).
-- Identity, retention and damage estimates remain in the Warlock HUD engine.
-- 0.7.0: one health bar style, two DoT styles (Warlock HUD icons or equal-width
-- bars), both drawn by ONE native aura group per enemy, sorted by the game
-- from the soonest to the latest expiry. The Does It Die marker (S.DID) sits
-- on every health bar. Never query native aura slots, their text, visibility
-- or geometry.
-- 0.7.1: denser rows (margins follow the health height, adjustable spacing),
-- adjustable bar height, and equal-width rows whose height follows the real
-- number of DoTs: each row hangs below the previous row's native group, which
-- the game sizes itself (the 0.5.1 chain), so nothing is measured in Lua.
local addonName, S = ...
local WH = S.WH
local P = {current={enemy='aio',dots='hud',healthHeight=20,barHeight=16,spacing=3}, pending=false}
WH.Presentation = P
local WHITE='Interface\\Buttons\\WHITE8X8'
local TEMPLATE='DisableUntrustedLayoutScriptsTemplate'
local SELECT,ICON_GAP,BAR_GAP=3,3,2
local MAX_FRAMES=10 -- one native allocation batch (FrameCreationBatchSize)
local SORT_EXPIRATION,SORT_NORMAL=5,0 -- validated in game since 0.5.5
local ICON_CROP=(1-1/1.3)/2
local GOLD={1,.82,0}
local FONT='FelkitWHDotFont'
-- Felkit 'kit' bars: one native group per DoT family, in a fixed order, each
-- filled in its family's colour. Slots are Warlock HUD effect slots.
local MEDIA='Interface\\AddOns\\'..addonName..'\\Media\\'
local KIT_ORDER={3,2,1,5,6,4,7}
local KIT_COLORS={[1]={.86,.60,.20},[2]={.70,.22,.62},[3]={.56,.32,.90},[4]={.36,.76,.30},
    [5]={.88,.26,.14},[6]={.20,.74,.64},[7]={.92,.46,.10}}
P.KIT_COLORS=KIT_COLORS
local PARKED=-20000 -- absent chained rows wait far below, invisible
local function frame(kind,parent) return CreateFrame(kind,nil,parent,TEMPLATE) end
-- Felkit: the DoT window's font (its own face, size and outline, or the general ones).
local function font(t,size)
    local path,outline,override=S.Media.barFont()
    t:SetFont(path,override or size,outline)
end
local function text(parent,size)
    local t=parent:CreateFontString(nil,'OVERLAY')
    -- Native slots can set text during creation: the font comes first.
    font(t,size or 11)
    t:SetJustifyH('LEFT'); return t
end
local rowSource=function() return {} end
function P.SetRowSource(fn) rowSource=fn end

function P.Settings()
    local p=S.db.multiTarget
    local c={enemy='aio',dots=(p.dotStyle=='equal' or p.dotStyle=='kit') and 'equal' or 'hud',
        barStyle=p.dotStyle=='kit' and 'kit' or 'flat',kitColors=p.kitColors~=false,kitRings=p.kitRings~=false,
        kitEdges=p.kitEdges~=false,effects={},spells={},
        healthHeight=p.healthHeight,showName=p.showName,showPortrait=p.showPortrait,
        execute=p.execute,didBars=p.didBars,transparent=p.transparent,header=p.header,
        spacing=p.spacing,barHeight=p.barHeight,clickTarget=p.clickTarget,healthColor=p.healthColor,locked=p.locked~=false,
        selectStyle=p.selectStyle,selectColor=p.selectColor,selectSize=p.selectSize,
        multiDotAlpha=p.multiDotAlpha,multiDotHideOutOfCombat=p.multiDotHideOutOfCombat,
        multiDotEnabled=p.multiDotEnabled,addonEnabled=WH.API.IsAddonEnabled(),ids={},
        iconPlace=p.iconPlace=='below' and 'below' or 'right',iconShape=p.iconShape or 'square',
        iconBorder=p.iconBorder or 'none',iconSize=tonumber(p.iconSize) or 0,iconTimeBar=p.iconTimeBar==true}
    local order=WH.API.GetMultiTargetEffectOrder()
    for _,key in ipairs(order) do c.effects[key]=true end
    c.slots=math.max(1,math.min(MAX_FRAMES,#order))
    local names={}
    for _,spell in ipairs(WH.API.Spells) do
        local on=spell.group~=2 and c.effects[WH.API.MainKeys[spell.slot]]
            and p.enabled[spell.name]~=false or false
        c.spells[spell.name]=on
        if on then names[#names+1]=spell.name; for _,id in ipairs(spell.ids) do c.ids[id]=true end end
    end
    c.idsKey=table.concat(names,',')
    c.fontKey=S.Media.barFontKey(); c.healthTexture=p.healthTexture==true
    -- Kit bars: the enabled spells of each effect slot.
    c.slotIds={}
    for _,spell in ipairs(WH.API.Spells) do
        if spell.group~=2 and c.spells[spell.name] then
            local ids=c.slotIds[spell.slot] or {}; c.slotIds[spell.slot]=ids
            for _,id in ipairs(spell.ids) do ids[id]=true end
        end
    end
    return c
end
-- Public geometry, all derived from the applied settings.
function P.Pad(c) local h=c.healthHeight; return h<=12 and 1 or h<=18 and 2 or 4 end
function P.Portrait(c) return c.showPortrait and c.healthHeight+(c.healthHeight<=14 and 2 or 6) or 0 end
-- HUD icons: beside the health bar (right) or in a line under it (below),
-- each optionally with a thin time bar under it.
local TIMEBAR=5
function P.IconsBelow(c) c=c or P.current; return c.dots=='hud' and c.iconPlace=='below' end
function P.IconSize(c)
    c=c or P.current
    if (c.iconSize or 0)>0 then return c.iconSize end
    if c.iconPlace=='below' then return math.max(16,c.healthHeight+2) end
    local h=math.max(12,math.max(P.Portrait(c),c.healthHeight))
    return c.iconTimeBar and math.max(10,h-TIMEBAR) or h
end
function P.IconCell(c) c=c or P.current; return P.IconSize(c)+(c.iconTimeBar and TIMEBAR or 0) end
function P.Header(c)
    local h=math.max(P.Portrait(c),c.healthHeight)
    if c.dots=='hud' and c.iconPlace~='below' then h=math.max(h,P.IconCell(c)) end
    return h+2*P.Pad(c)
end
function P.TopInset(c) c=c or P.current; return c.header==false and 6 or 50 end
function P.Inner(c) return P.Pad(c)+SELECT+2 end
function P.HealthLeft(c) local ps=P.Portrait(c); return P.Inner(c)+(ps>0 and ps+4 or 0) end
function P.BackgroundAlpha(c)
    if c.transparent then return 0 end
    return math.max(.3,math.min(1,tonumber(c.multiDotAlpha) or 1))
end
function P.IconsWidth(c,slots)
    if c.dots~='hud' or c.iconPlace=='below' then return 0 end
    return 6+(slots or c.slots or 1)*(P.IconSize(c)+ICON_GAP)
end
-- Where the first icon's top left corner goes, from the row's display frame.
function P.IconOrigin(c)
    if c.iconPlace=='below' then return P.HealthLeft(c),-P.Header(c)-1,'TOPLEFT' end
    return 6,-math.floor((P.Header(c)-P.IconCell(c))/2),'TOPRIGHT'
end
function P.MinimumWidth(c,slots)
    return math.max(260,P.HealthLeft(c)+120+P.Pad(c)+38+P.IconsWidth(c,slots))
end
-- Equal-width rows hang from each other (Chained); HUD rows have fixed steps.
function P.Chained(row) return P.current.dots=='equal' and not row.preview and row.tail~=nil end
-- With click targeting, HUD rows keep their places during combat so the
-- secure click zones placed before combat stay on their enemies.
function P.Frozen() return P.current.dots=='hud' and P.current.clickTarget==true end
-- Reserved step (HUD rows, preview rows, scroll range estimate of chained rows).
function P.Step(row)
    local c=P.current
    local header=P.Header(c)
    local extra=0
    if c.dots=='equal' then
        extra=row.source=='ghost' and (c.barHeight+BAR_GAP)
            or (c.slots or 1)*(c.barHeight+BAR_GAP)+P.Pad(c)
    elseif P.IconsBelow(c) then
        extra=P.IconCell(c)+P.Pad(c)+2
    end
    return header+extra+c.spacing,header
end
-- Native filter: the personal harmful auras of the enabled, known families.
local function filters(c) return {includeSpellIDs=c.ids} end
local function layout(width,height,gap)
    return {elementWidth=width,elementHeight=height,elementSpacing=gap,lineSpacing=gap,groupSpacing=0}
end
local function countdownFont()
    if P.font or not CreateFont then return P.font end
    local f=CreateFont(FONT)
    if f then f:SetShadowColor(0,0,0,1); f:SetShadowOffset(1,-1) end
    P.font=f; P.SyncCountdownFont(); return f
end
function P.SyncCountdownFont()
    if not P.font then return end
    local path,outline,override=S.Media.barFont()
    P.font:SetFont(path,override or 11,outline)
end
local TIMEBAR_COLOR={.66,.42,1}
local shapeParts=function(...) return S.Media.shapeParts(...) end
local function applyShape(s,c,size,cooldown) S.Media.applyShape(s,c.iconShape,c.iconBorder,size,cooldown) end
local function timeBar(parent)
    local b=frame('StatusBar',parent); b:SetStatusBarTexture(WHITE); b:SetMinMaxValues(0,1)
    b:SetStatusBarColor(TIMEBAR_COLOR[1],TIMEBAR_COLOR[2],TIMEBAR_COLOR[3],1)
    b.bg=b:CreateTexture(nil,'BACKGROUND'); b.bg:SetAllPoints(b); b.bg:SetColorTexture(.04,.03,.06,.9)
    return b
end
local function placeTimeBar(b,icon,size,on)
    b:ClearAllPoints(); b:SetPoint('TOP',icon,'BOTTOM',0,-2); b:SetSize(math.max(4,math.floor(size*.8)),TIMEBAR-2)
    b:SetAlpha(on and 1 or 0)
end
-- Out of restrictions: the icon's shape, size and time bar follow the settings.
local function styleIcon(v,c,size)
    v.icon:ClearAllPoints(); v.icon:SetPoint('TOPLEFT',v.button,'TOPLEFT'); v.icon:SetSize(size,size)
    applyShape(v.shape,c,size,v.cooldown)
    if v.timeBar then placeTimeBar(v.timeBar,v.icon,size,c.iconTimeBar) end
end
-- Warlock HUD icon: spell icon, reversed swipe, game countdown, stack count.
local function makeIcon(button,row,c)
    -- Runs before native access restrictions are applied to the slot.
    button:SetAlpha(1)
    local v={button=button}
    v.icon=button:CreateTexture(nil,'ARTWORK')
    button:SetIcon(v.icon)
    v.cooldown=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
    local overlay=frame('Frame',button); overlay:SetAllPoints(button); overlay:SetFrameLevel(v.cooldown:GetFrameLevel()+1)
    v.shape=shapeParts(button,v.icon,overlay)
    local bar=timeBar(button)
    if button.SetDurationBar and pcall(button.SetDurationBar,button,bar,{direction=1,interpolation=0}) then v.timeBar=bar
    else bar:Hide() end
    styleIcon(v,c,P.IconSize(c))
    v.cooldown:SetDrawBling(false); v.cooldown:SetDrawEdge(false); v.cooldown:SetReverse(true)
    v.cooldown:SetCountdownMillisecondsThreshold(10)
    if v.cooldown.SetCountdownAbbrevThreshold then v.cooldown:SetCountdownAbbrevThreshold(60) end
    if v.cooldown.SetSwipeColor then v.cooldown:SetSwipeColor(0,0,0,.58) end
    local f=countdownFont()
    if f and v.cooldown.SetCountdownFont then v.cooldown:SetCountdownFont(FONT) end
    button:SetDurationCooldown(v.cooldown)
    if button.SetApplicationCount then
        v.count=button:CreateFontString(nil,'OVERLAY'); font(v.count,9)
        v.count:SetPoint('TOPLEFT',button,'TOPLEFT',1,0)
        button:SetApplicationCount(v.count,{})
    end
    row.iconVisuals[#row.iconVisuals+1]=v
end
-- Equal-width bar: icon, then a full-width bar with the name and the time inside.
local function barGeometry(v,h)
    v.icon:SetWidth(h)
    v.bar:ClearAllPoints(); v.bar:SetPoint('TOPLEFT',v.button,'TOPLEFT',h+3,0); v.bar:SetPoint('BOTTOMRIGHT',v.button,'BOTTOMRIGHT')
    local size=math.max(7,math.min(11,h-3))
    v.name:SetHeight(h); font(v.name,size); v.time:SetSize(36,h); font(v.time,size)
end
local function makeBar(button,row,c)
    button:SetAlpha(1)
    local v={button=button}
    v.icon=button:CreateTexture(nil,'ARTWORK'); v.icon:SetTexCoord(.08,.92,.08,.92)
    v.icon:SetPoint('TOPLEFT',button,'TOPLEFT'); v.icon:SetPoint('BOTTOMLEFT',button,'BOTTOMLEFT')
    v.tex=S.Media.barTexture('flat')
    v.bar=frame('StatusBar',button); v.bar:SetStatusBarTexture(v.tex); v.bar:SetMinMaxValues(0,1)
    v.bar:SetStatusBarColor(.58,.36,.92,.95)
    v.bg=v.bar:CreateTexture(nil,'BACKGROUND'); v.bg:SetAllPoints(v.bar); v.bg:SetColorTexture(.10,.09,.14,.85)
    local overlay=frame('Frame',button); overlay:SetAllPoints(button); overlay:SetFrameLevel(v.bar:GetFrameLevel()+2)
    v.name=text(overlay,11); v.name:SetPoint('LEFT',v.bar,'LEFT',4,0); v.name:SetPoint('RIGHT',v.bar,'RIGHT',-40,0)
    v.time=text(overlay,11); v.time:SetJustifyH('RIGHT'); v.time:SetPoint('RIGHT',v.bar,'RIGHT',-4,0)
    barGeometry(v,c.barHeight); v.height=c.barHeight..(c.fontKey or '')
    button:SetIcon(v.icon); button:SetSpellName(v.name)
    button:SetDurationBar(v.bar,{direction=1,interpolation=0})
    button:SetDurationText(v.time,{})
    row.barVisuals[#row.barVisuals+1]=v
end
-- Kit bar: a round icon in a gold ring heading a dark, gold-edged bar filled
-- in the family's colour, its name on the left and its time on the right.
local function kitGeometry(v,h)
    v.icon:SetSize(h+2,h+2)
    v.ring:SetSize((h+2)*1.24,(h+2)*1.24)
    v.bar:ClearAllPoints(); v.bar:SetPoint('TOPLEFT',v.button,'TOPLEFT',h+6,-1); v.bar:SetPoint('BOTTOMRIGHT',v.button,'BOTTOMRIGHT',-1,1)
    local size=math.max(7,math.min(11,h-3))
    v.name:SetHeight(h); font(v.name,size); v.time:SetSize(36,h); font(v.time,size)
end
local function kitEdges(parent,anchor)
    local e={}
    for i=1,4 do e[i]=parent:CreateTexture(nil,'OVERLAY'); e[i]:SetColorTexture(.84,.65,.28,1) end
    e[1]:SetPoint('TOPLEFT',anchor,'TOPLEFT',-1,1); e[1]:SetPoint('TOPRIGHT',anchor,'TOPRIGHT',1,1); e[1]:SetHeight(1)
    e[2]:SetPoint('BOTTOMLEFT',anchor,'BOTTOMLEFT',-1,-1); e[2]:SetPoint('BOTTOMRIGHT',anchor,'BOTTOMRIGHT',1,-1); e[2]:SetHeight(1)
    e[3]:SetPoint('TOPLEFT',anchor,'TOPLEFT',-1,1); e[3]:SetPoint('BOTTOMLEFT',anchor,'BOTTOMLEFT',-1,-1); e[3]:SetWidth(1)
    e[4]:SetPoint('TOPRIGHT',anchor,'TOPRIGHT',1,1); e[4]:SetPoint('BOTTOMRIGHT',anchor,'BOTTOMRIGHT',1,-1); e[4]:SetWidth(1)
    return e
end
local function makeKitBar(button,row,c,slot)
    button:SetAlpha(1)
    local v={button=button,slot=slot}
    v.icon=button:CreateTexture(nil,'ARTWORK'); v.icon:SetTexCoord(.08,.92,.08,.92)
    v.icon:SetPoint('LEFT',button,'LEFT',0,0)
    v.mask=button:CreateMaskTexture(); v.mask:SetTexture(MEDIA..'fk_mask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
    v.mask:SetAllPoints(v.icon); v.icon:AddMaskTexture(v.mask)
    v.tex=S.Media.barTexture('kit')
    v.bar=frame('StatusBar',button); v.bar:SetStatusBarTexture(v.tex); v.bar:SetMinMaxValues(0,1)
    local color=c.kitColors and KIT_COLORS[slot] or KIT_COLORS[3]
    v.bar:SetStatusBarColor(color[1],color[2],color[3],.95)
    v.bg=v.bar:CreateTexture(nil,'BACKGROUND'); v.bg:SetAllPoints(v.bar); v.bg:SetColorTexture(.04,.025,.06,.92)
    local overlay=frame('Frame',button); overlay:SetAllPoints(button); overlay:SetFrameLevel(v.bar:GetFrameLevel()+2)
    v.edges=kitEdges(overlay,v.bar)
    v.ring=overlay:CreateTexture(nil,'OVERLAY',nil,2); v.ring:SetTexture(MEDIA..'fk_ring'); v.ring:SetPoint('CENTER',v.icon,'CENTER')
    v.name=text(overlay,11); v.name:SetPoint('LEFT',v.bar,'LEFT',5,0); v.name:SetPoint('RIGHT',v.bar,'RIGHT',-40,0)
    v.time=text(overlay,11); v.time:SetJustifyH('RIGHT'); v.time:SetPoint('RIGHT',v.bar,'RIGHT',-5,0)
    kitGeometry(v,c.barHeight); v.height=c.barHeight..(c.fontKey or '')
    button:SetIcon(v.icon); button:SetSpellName(v.name)
    button:SetDurationBar(v.bar,{direction=1,interpolation=0})
    button:SetDurationText(v.time,{})
    row.kitVisuals[#row.kitVisuals+1]=v
end
local function kitFilters(c,slot)
    local ids=c.slotIds and c.slotIds[slot]
    if ids and next(ids) then return {includeSpellIDs=ids} end
    return {includeSpellIDs={[1]=true}} -- nothing of this family is tracked
end
local function kitLayout(width,height)
    return {elementWidth=width,elementHeight=height,elementSpacing=BAR_GAP,lineSpacing=BAR_GAP,groupSpacing=BAR_GAP}
end
local function addKitGroups(container,c,row)
    container:SetFlowLayoutAxis(1)
    container:SetFlowLayoutAnchorPoint('TOPLEFT'); container:SetFlowLayoutGrowthDirection(1,-1)
    for _,slot in ipairs(KIT_ORDER) do
        container:AddAuraGroup('kit'..slot,'HARMFUL|PLAYER',{maxFrameCount=1,sortMethod=SORT_NORMAL,
            sortDirection=SORT_NORMAL,candidateFilters=kitFilters(c,slot),layout=kitLayout(200,c.barHeight),
            initializeFrame=function(button) makeKitBar(button,row,c,slot) end})
    end
end
local function addGroup(container,c,horizontal,init)
    container:SetFlowLayoutAxis(horizontal and 0 or 1)
    container:SetFlowLayoutAnchorPoint('TOPLEFT'); container:SetFlowLayoutGrowthDirection(1,-1)
    container:AddAuraGroup('dots','HARMFUL|PLAYER',{maxFrameCount=c.slots,sortMethod=SORT_EXPIRATION,
        sortDirection=SORT_NORMAL,candidateFilters=filters(c),
        layout=horizontal and layout(P.IconSize(c),P.IconCell(c),ICON_GAP) or layout(200,c.barHeight,BAR_GAP),
        initializeFrame=init})
end
-- Out of restrictions only: native groups, built once per renderer.
function P.EnsureGroups(row,c)
    if row.preview or row.source=='ghost' then return end
    row.iconVisuals=row.iconVisuals or {}; row.barVisuals=row.barVisuals or {}
    if not row.iconGroup then
        local container=row.auras
        container:SetUnit('none')
        addGroup(container,c,true,function(button) makeIcon(button,row,P.current) end)
        row.iconGroup=true
        container:SetUnit(row.unit)
    end
    if c.barStyle=='kit' and not row.kitGroup then
        row.kitVisuals=row.kitVisuals or {}
        local container=row.kitContainer or CreateFrame('AuraContainer',nil,row.icons,'CustomAuraContainerTemplate')
        row.kitContainer=container
        container:SetUnit('none')
        addKitGroups(container,c,row)
        row.kitGroup=true; row.kitAuras=container
        container:SetUnit(row.unit); container:Show()
    end
    if c.dots=='equal' and c.barStyle~='kit' and not row.barGroup then
        -- A failed first allocation keeps its container for the retry; the
        -- renderer is published only once its group exists. Its height is the
        -- game's: the flow layout grows with the shown DoTs (empty = 1 px).
        local container=row.barContainer or CreateFrame('AuraContainer',nil,row.icons,'CustomAuraContainerTemplate')
        row.barContainer=container
        container:SetUnit('none')
        addGroup(container,c,false,function(button) makeBar(button,row,c) end)
        row.barGroup=true; row.barAuras=container
        container:SetUnit(row.unit); container:Show()
    end
end
-- Native reconfiguration only when its inputs change (resizing calls Row often).
local function configureGroup(container,c,width,height,gap)
    if not container then return end
    local signature=width..':'..height..':'..c.slots..':'..(c.idsKey or '')
    if container.aioSignature==signature then return end
    container.aioSignature=signature
    if container.SetAuraGroupLayout then container:SetAuraGroupLayout('dots',layout(width,height,gap)) end
    if container.SetAuraGroupMaxFrameCount then container:SetAuraGroupMaxFrameCount('dots',c.slots) end
    if container.SetAuraGroupCandidateFilters then container:SetAuraGroupCandidateFilters('dots',filters(c)) end
end
-- Public, synthetic rows of the settings preview: no native binding at all.
local function previewVisuals(row)
    if row.previewVisuals then return end
    row.previewVisuals={}
    for _,spell in ipairs(row.presentationSpells) do
        local v={spell=spell,duration=(P.Timing(spell.ids[1]))}
        local name,icon=S.API.spell(spell.ids[1])
        v.icon=row.icons:CreateTexture(nil,'ARTWORK'); v.icon:SetTexture(icon)
        v.shape=shapeParts(row.icons,v.icon,row.icons); v.timeBar=timeBar(row.icons)
        v.timer=text(row.icons,11); v.timer:SetJustifyH('CENTER')
        v.lane=frame('Frame',row.icons)
        v.barIcon=v.lane:CreateTexture(nil,'ARTWORK'); v.barIcon:SetTexture(icon); v.barIcon:SetTexCoord(.08,.92,.08,.92)
        v.bar=frame('StatusBar',v.lane); v.bar:SetStatusBarTexture(WHITE); v.bar:SetMinMaxValues(0,1)
        v.bar:SetStatusBarColor(.58,.36,.92,.95)
        v.bg=v.bar:CreateTexture(nil,'BACKGROUND'); v.bg:SetAllPoints(v.bar); v.bg:SetColorTexture(.10,.09,.14,.85)
        local overlay=frame('Frame',v.lane); overlay:SetAllPoints(v.lane); overlay:SetFrameLevel(v.bar:GetFrameLevel()+2)
        v.name=text(overlay,11); v.name:SetText(name)
        v.time=text(overlay,11); v.time:SetJustifyH('RIGHT')
        row.previewVisuals[#row.previewVisuals+1]=v
    end
end
-- Test bars in the kit look: public textures only, switched in place.
function P.PreviewKit(v,on,bh)
    if not v.kitRing then
        v.kitRing=v.lane:CreateTexture(nil,'OVERLAY',nil,3); v.kitRing:SetTexture(MEDIA..'fk_ring')
        v.kitMask=v.lane:CreateMaskTexture(); v.kitMask:SetTexture(MEDIA..'fk_mask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
        v.kitMask:SetAllPoints(v.barIcon)
        v.kitEdges=kitEdges(v.bar,v.bar)
    end
    if v.kitOn~=on then
        if on then v.barIcon:AddMaskTexture(v.kitMask) else v.barIcon:RemoveMaskTexture(v.kitMask) end
        v.kitOn=on
    end
    v.kitRing:ClearAllPoints(); v.kitRing:SetPoint('CENTER',v.barIcon,'CENTER'); v.kitRing:SetSize(bh*1.24,bh*1.24)
    local c=P.current
    v.kitRing:SetShown(on and c.kitRings~=false)
    for _,e in ipairs(v.kitEdges) do e:SetShown(on and c.kitEdges~=false) end
    local color=on and (c.kitColors~=false and KIT_COLORS[v.spell.slot] or KIT_COLORS[3]) or nil
    v.bar:SetStatusBarTexture(S.Media.barTexture(on and 'kit' or 'flat'))
    if color then v.bar:SetStatusBarColor(color[1],color[2],color[3],.95) else v.bar:SetStatusBarColor(.58,.36,.92,.95) end
    if on then v.bg:SetColorTexture(.04,.025,.06,.92) else v.bg:SetColorTexture(.10,.09,.14,.85) end
end
function P.Timing(id)
    local t=S.DotTiming and S.DotTiming[id]
    if t and t.count then return t.duration,t.count end
    local spec=S.SpellData and S.SpellData.spells[id]
    local count=S.Ticks and S.Ticks.counts[id]
    local e=spec and spec.effects and spec.effects[1]
    if count and e and e.duration then return e.duration,count end
end
function P.Prepare(rows,settings)
    local c=settings or P.Settings()
    local ok=pcall(function()
        for _,row in ipairs(rows) do
            if row.preview then previewVisuals(row) else P.EnsureGroups(row,c) end
        end
    end)
    if not ok then
        P.error=S.L.mtBarsUnavailable; P.pending=true
        -- Do not print arbitrary native payloads or lose the working view.
        S.API.chat(P.error)
        return false
    end
    for _,row in ipairs(rows) do
        if row.preview then
            local shown=0
            for _,v in ipairs(row.previewVisuals) do
                v.on=c.spells[v.spell.name]==true
                if v.on then shown=shown+1 end
            end
            row.visibleSpellCount=shown
        end
    end
    P.current=c; P.pending=false; P.error=nil
    P.SyncCountdownFont()
    return true
end
-- Enables only the renderer of the chosen style (tracking work stays bounded).
function P.Enable(row,enabled)
    local c=P.current
    if row.auras and row.auras.SetEnabled then row.auras:SetEnabled(enabled and c.dots=='hud') end
    if row.barAuras then row.barAuras:SetEnabled(enabled and c.dots=='equal' and c.barStyle~='kit') end
    if row.kitAuras then row.kitAuras:SetEnabled(enabled and c.barStyle=='kit') end
end
-- The bar container the current style draws with (chain anchor).
function P.ActiveBars(row)
    local c=P.current
    if c.dots~='equal' then return nil end
    if c.barStyle=='kit' then return row.kitAuras end
    return row.barAuras
end
-- Public, synthetic durations only; the preview sorts like the game does.
function P.AnimatePreview(rows,now)
    local c=P.current
    local pad=P.Pad(c)
    for r,row in ipairs(rows) do
        local list={}
        for i,v in ipairs(row.previewVisuals or {}) do
            if v.on then
                local duration=v.duration or 30
                v.remaining=duration-((now+r*2+i*3)%duration)
                v.fraction=v.remaining/duration
                list[#list+1]=v
            end
        end
        if c.barStyle=='kit' and c.dots=='equal' then
            local rank={}; for i,slot in ipairs(KIT_ORDER) do rank[slot]=i end
            table.sort(list,function(a,b)
                local ra,rb=rank[a.spell.slot] or 99,rank[b.spell.slot] or 99
                if ra~=rb then return ra<rb end
                return a.remaining<b.remaining
            end)
        else table.sort(list,function(a,b) return a.remaining<b.remaining end) end
        for position,v in ipairs(list) do
            local label=v.remaining<10 and string.format('%.1f',v.remaining) or tostring(math.ceil(v.remaining))
            local placed=c.dots..position..'/'..tostring(c)
            if c.dots=='hud' then
                if v.placed~=placed then
                    local size=P.IconSize(c)
                    local x,y,relative=P.IconOrigin(c)
                    v.icon:ClearAllPoints(); v.icon:SetPoint('TOPLEFT',row.display,relative,x+(position-1)*(size+ICON_GAP),y)
                end
                v.timeBar:SetValue(v.fraction)
                if v.label~=label then v.timer:SetText(label) end
            else
                if v.placed~=placed then
                    local header=P.Header(c)
                    v.lane:ClearAllPoints(); v.lane:SetPoint('TOPLEFT',row.display,'TOPLEFT',P.Inner(c),-header-(position-1)*(c.barHeight+BAR_GAP))
                end
                v.bar:SetValue(v.fraction)
                if v.label~=label then v.time:SetText(label) end
            end
            v.label,v.placed=label,placed
        end
    end
    if not P.markersAt or now-P.markersAt>=0.1 or now<P.markersAt then P.markersAt=now; P.UpdateMarkers() end
end
-- 0.7.2: how the targeted enemy stands out. line = the yellow line on the left;
-- outline = the whole row (DoT bars included) framed; fill = a lit background;
-- health = a border around the health bar.
local SELECT_COLORS={white={1,1,1},gold={1,.82,0},purple={.7,.3,1},red={1,.2,.2},orange={1,.55,.1},
    green={.3,1,.3},cyan={.2,.9,1},pink={1,.45,.6},black={0,0,0}}
local function selection(row)
    if row.sel then return row.sel end
    local sel={edges={}}
    for i=1,4 do sel.edges[i]=row.display:CreateTexture(nil,'OVERLAY',nil,6) end
    sel.fill=row.display:CreateTexture(nil,'BACKGROUND',nil,2)
    sel.health=row.display:CreateTexture(nil,'OVERLAY',nil,5)
    row.sel=sel; return sel
end
local function selectionTextures(row)
    local style=P.current.selectStyle or 'line'
    local sel=row.sel
    if style=='outline' and sel then return sel.edges end
    if style=='fill' and sel then return {sel.fill} end
    if style=='health' and sel then return {sel.health} end
    return {row.target}
end
local function allSelection(row)
    local list={row.target}
    if row.sel then
        for _,t in ipairs(row.sel.edges) do list[#list+1]=t end
        list[#list+1]=row.sel.fill; list[#list+1]=row.sel.health
    end
    return list
end
function P.Selection(row,selected)
    row.selected=selected==true
    if not row.target then return end
    -- Same answer and style as last time: the textures already show it.
    local key=(row.selected and 'y' or 'n')..(P.current.selectStyle or 'line')
    if row.selKey==key then return end
    row.selKey=key
    for _,t in ipairs(allSelection(row)) do t:SetAlpha(0) end
    if row.selected then for _,t in ipairs(selectionTextures(row)) do t:SetAlpha(1) end end
end
-- Restricted selection: the game may answer UnitIsUnit with a hidden boolean.
function P.SecretSelection(row,selected)
    if not row.target or not row.target.SetAlphaFromBoolean then return false end
    row.selKey=nil
    for _,t in ipairs(allSelection(row)) do t:SetAlpha(0) end
    for _,t in ipairs(selectionTextures(row)) do
        if not pcall(t.SetAlphaFromBoolean,t,selected,1,0) then return false end
    end
    return true
end
-- Health bar colour: green, red, or by the enemy's reaction to the player.
local REACTION={{.70,.16,.14},{.70,.16,.14},{.70,.16,.14},{.80,.66,.12},{.20,.55,.36},{.20,.55,.36},{.20,.55,.36},{.20,.55,.36}}
local PREVIEW_REACTION={1,4,2}
function P.HealthColor(row)
    local mode=P.current.healthColor or 'green'
    local bar=row.healthBar
    -- Green and red never change: set once per row and mode.
    if mode~='reaction' or row.preview then
        if row.colorKey==mode then return end
        row.colorKey=mode
    else row.colorKey=nil end
    if mode=='red' then bar:SetStatusBarColor(.70,.16,.14,1); return end
    if mode=='reaction' then
        local reaction
        if row.preview then reaction=PREVIEW_REACTION[row.previewIndex or 1]
        elseif row.unit and UnitReaction then
            local ok,value=pcall(UnitReaction,row.unit,'player')
            reaction=ok and S.API.public(value) or nil
            if reaction==nil and ok and value~=nil and UnitSelectionColor then
                -- Hidden reaction: the game's own selection colour, passed as is.
                local okColor,r,g,b=pcall(UnitSelectionColor,row.unit)
                if okColor and r~=nil and pcall(bar.SetStatusBarColor,bar,r,g,b,1) then return end
            end
        end
        local color=type(reaction)=='number' and REACTION[math.max(1,math.min(8,reaction))]
        if color then bar:SetStatusBarColor(color[1],color[2],color[3],1); return end
    end
    bar:SetStatusBarColor(.20,.55,.36,1)
end
function P.HealthText(row,health,maximum,percent)
    if not pcall(row.healthText.SetFormattedText,row.healthText,'%d (%.0f%%)',health,percent) then
        row.healthText:SetText('?')
    end
    return true
end
function P.HealthAvailable(row,available)
    row.healthAvailable=available
    local c=P.current
    -- These alphas only depend on availability and the 20% option.
    local key=(available and 1 or 0)+(c.execute and 2 or 0)
    if row.healthKey==key then return end
    row.healthKey=key
    local alpha=available and 1 or 0
    row.healthBar:SetAlpha(alpha)
    row.healthEdge:SetAlpha(0)
    for _,t in ipairs({row.damageMarker,row.baneMarker,row.siphonMarker,row.immolateMarker}) do t:SetAlpha(0) end
    row.damageEdge:SetAlpha(0)
    for _,t in ipairs({row.executeOutline,row.executeLine}) do t:SetAlpha(c.execute and alpha or 0) end
    if not available and row.didWidgets and S.DID and S.DID.barMarker then
        S.DID.barMarker.hide(row.didWidgets); row.didShown=false
    end
end
function P.RefreshAuras(row)
    if row.barAuras then pcall(row.barAuras.UpdateAllAuras,row.barAuras) end
    if row.kitAuras then pcall(row.kitAuras.UpdateAllAuras,row.kitAuras) end
end
function P.Retire(row)
    if row.barAuras then row.barAuras:SetEnabled(false); row.barAuras:Hide() end
    if row.kitAuras then row.kitAuras:SetEnabled(false); row.kitAuras:Hide() end
end
-- Ghost (last seen) rows: the families with remaining estimated damage, no timer.
function P.GhostIcons(row,byKey)
    local c=P.current
    row.ghostIcons=row.ghostIcons or {}
    local position=0
    for _,key in ipairs(WH.API.MainKeys) do
        local t=row.ghostIcons[key]
        if not t then
            local spell=WH.Effects.PreviewSpellIDs[key]
            t=row.icons:CreateTexture(nil,'ARTWORK')
            t:SetTexture(spell and select(2,S.API.spell(spell)) or nil); t:SetDesaturated(true)
            t.shape=shapeParts(row.icons,t,row.icons)
            row.ghostIcons[key]=t
        end
        local shown=byKey and c.dots=='hud' and c.effects[key] and (byKey[key] or 0)>0
        if shown then
            position=position+1
            local size=P.IconSize(c)
            local x,y,relative=P.IconOrigin(c)
            t:ClearAllPoints(); t:SetPoint('TOPLEFT',row.display,relative,x+(position-1)*(size+ICON_GAP),y)
            t:SetSize(size,size); t:SetAlpha(.85); applyShape(t.shape,c,size); t.shape.frame:Show()
        else t:SetAlpha(0); t.shape.frame:Hide() end
    end
end
-- Does It Die marker on the row's health bar: the same widgets as the
-- nameplates, in the look chosen in the options; the kill icon covers the portrait.
local look={plateDashLength=4,plateOutlineOpacity=85,nameplateIconPosition='left',plateIconOffsetY=0,
    showMarkers=true,nameplateMode='markerIcon'}
P.markerLook=look
local function markerWidgets(row)
    local DID=S.DID
    if not DID or not DID.barMarker or row.source=='ghost' then return end
    local w=DID.barMarker.widgetsFor(row.display,row.healthBar)
    if not row.didWidgets then
        DID.barMarker.pin(row.display)
        row.didWidgets=w
    end
    -- Texts stay above the marker; the kill icon above the portrait.
    local level=row.healthBar:GetFrameLevel()
    w.marker:SetFrameLevel(level+4); w.iconWindow:SetFrameLevel(level+20); w.iconBar:SetFrameLevel(level+21)
    DID.barMarker.hide(w); row.didShown=false
end
local PREVIEW_DOTS={{{name='Corruption',school=32,damage=180},{name='Immolate',school=4,damage=120}},
    {{name='Corruption',school=32,damage=150},{name='Bane of Agony',school=32,damage=110}},
    {{name='Corruption',school=32,damage=110},{name='Immolate',school=4,damage=90}}}
local PREVIEW_HEALTH={820,460,150}
function P.UpdateMarkers()
    local DID=S.DID
    if not DID or not DID.barMarker then return end
    local c=P.current
    if look.version~=S.settingsVersion or look.current~=c then
        if DID.applyLook then DID.applyLook(look) end
        local ps=P.Portrait(c)
        look.nameplateIconSize=ps>0 and ps or c.healthHeight+4
        -- Over the portrait, or over the bar's left end without a portrait.
        look.plateIconOffsetX=ps>0 and 0 or look.nameplateIconSize+4
        look.version,look.current=S.settingsVersion,c
        look.styleVersion=(look.styleVersion or 0)+1
    end
    local on=DID.barsEnabled()
    local live,preview=rowSource()
    for _,row in ipairs(live or {}) do
        local w=row.didWidgets
        if w then
            local drawn=false
            if on and row.present and row.source~='ghost' and row.healthAvailable~=false then
                local entries,total=DID.dotBreakdownForUnit(row.unit)
                if total>0 then
                    drawn=DID.barMarker.draw(w,entries,total,UnitHealthMax(row.unit),UnitHealth(row.unit),look)
                end
            end
            -- Hidden once, not on every pass: up to 61 rows run every 0.1 s.
            if drawn then row.didShown=true
            elseif row.didShown~=false then DID.barMarker.hide(w); row.didShown=false end
        end
    end
    for i,row in ipairs(preview or {}) do
        local w=row.didWidgets
        if w then
            if on then
                local entries,total=PREVIEW_DOTS[i] or {},0
                for _,e in ipairs(entries) do total=total+e.damage end
                DID.barMarker.draw(w,entries,total,1000,PREVIEW_HEALTH[i] or 500,look)
                row.didShown=true
            elseif row.didShown~=false then DID.barMarker.hide(w); row.didShown=false end
        end
    end
end
-- Chain links: tail(n) sits under the bottom of row n's native group; row n+1
-- hangs from tail(n). Every frame in the chain uses the layout template and no
-- geometry is read back; nothing anchors up the chain (no cycle).
function P.EnsureTail(row)
    if not row.preview then row.tail=row.tail or frame('Frame',row.display) end
end
local function tail(row,c,header)
    if row.preview then return end
    P.EnsureTail(row)
    local t=row.tail
    t:ClearAllPoints(); t:SetSize(1,1)
    local pad=P.Pad(c)
    local bars=P.ActiveBars(row)
    if bars then
        t:SetPoint('TOP',bars,'BOTTOM',0,-pad); t:SetPoint('LEFT',row.display,'LEFT',0,0)
    else
        local below=row.source=='ghost' and c.dots=='equal' and (c.barHeight+BAR_GAP) or 0
        t:SetPoint('TOPLEFT',row.display,'TOPLEFT',0,-header-below)
    end
end
function P.Row(row,width,_,panelWidth)
    local c=P.current
    row.selKey,row.colorKey,row.healthKey=nil,nil,nil
    local step,header=P.Step(row)
    local alpha=P.BackgroundAlpha(c)
    local fullWidth=panelWidth or width
    local ps=P.Portrait(c)
    local hh=c.healthHeight
    local pad=P.Pad(c)
    local inner=P.Inner(c)
    local size=P.IconSize(c)
    local cell=P.IconCell(c)
    row.presentationCustom=true
    row.display:SetHeight(header)
    tail(row,c,header)
    local chained=P.Chained(row)
    -- Background and target line: down to the tail when chained, else the step.
    row.background:ClearAllPoints(); row.background:SetPoint('TOPLEFT',row.display,'TOPLEFT')
    row.target:ClearAllPoints(); row.target:SetPoint('TOPLEFT',row.display,'TOPLEFT',0,0)
    if chained then
        row.background:SetPoint('BOTTOMLEFT',row.tail,'BOTTOMLEFT'); row.background:SetWidth(fullWidth)
        row.target:SetPoint('BOTTOMLEFT',row.tail,'BOTTOMLEFT')
    else
        row.background:SetSize(fullWidth,step-c.spacing)
    end
    row.background:SetColorTexture(.085,.070,.12,alpha)
    -- The targeted enemy: line, frame, lit background or health border.
    local color=SELECT_COLORS[c.selectColor] or GOLD
    local sz=c.selectSize or 3
    row.target:SetWidth(sz); row.target:SetColorTexture(color[1],color[2],color[3],1)
    if not chained then row.target:SetSize(sz,step-c.spacing) end
    local sel=selection(row)
    local e=sel.edges
    for i,t in ipairs(e) do t:ClearAllPoints(); t:SetColorTexture(color[1],color[2],color[3],1) end
    e[1]:SetPoint('TOPLEFT',row.background,'TOPLEFT'); e[1]:SetPoint('TOPRIGHT',row.background,'TOPRIGHT'); e[1]:SetHeight(sz)
    e[2]:SetPoint('BOTTOMLEFT',row.background,'BOTTOMLEFT'); e[2]:SetPoint('BOTTOMRIGHT',row.background,'BOTTOMRIGHT'); e[2]:SetHeight(sz)
    e[3]:SetPoint('TOPLEFT',row.background,'TOPLEFT'); e[3]:SetPoint('BOTTOMLEFT',row.background,'BOTTOMLEFT'); e[3]:SetWidth(sz)
    e[4]:SetPoint('TOPRIGHT',row.background,'TOPRIGHT'); e[4]:SetPoint('BOTTOMRIGHT',row.background,'BOTTOMRIGHT'); e[4]:SetWidth(sz)
    sel.fill:ClearAllPoints(); sel.fill:SetAllPoints(row.background); sel.fill:SetColorTexture(color[1],color[2],color[3],.18)
    sel.health:ClearAllPoints()
    sel.health:SetPoint('TOPLEFT',row.healthBar,'TOPLEFT',-sz,sz); sel.health:SetPoint('BOTTOMRIGHT',row.healthBar,'BOTTOMRIGHT',sz,-sz)
    sel.health:SetColorTexture(color[1],color[2],color[3],1)
    P.Selection(row,row.selected)
    row.portrait:ClearAllPoints(); row.portrait:SetPoint('TOPLEFT',row.display,'TOPLEFT',inner,-pad)
    row.portrait:SetSize(math.max(1,ps),math.max(1,ps)); row.portrait:SetTexCoord(.08,.92,.08,.92)
    row.portrait:SetAlpha(ps>0 and 1 or 0)
    row.portraitCover:SetAlpha(0); row.portraitWarning:SetAlpha(0)
    local left=P.HealthLeft(c)
    local healthWidth=math.max(60,width-left-pad)
    local top=(header-hh)/2
    row.healthBar:ClearAllPoints(); row.healthBar:SetPoint('TOPLEFT',row.display,'TOPLEFT',left,-top)
    row.healthBar:SetSize(healthWidth,hh)
    row.healthBar:SetStatusBarTexture(c.healthTexture and S.Media.barTexture('flat') or WHITE)
    if row.source~='ghost' then P.HealthColor(row) end
    row.healthTrack:SetColorTexture(.025,.025,.03,.85)
    -- Raid marker: on the portrait, or at the bar's left end without one.
    row.marker:ClearAllPoints()
    local markerSize=math.max(10,math.min(18,hh))
    row.marker:SetSize(markerSize,markerSize)
    if ps>0 then row.marker:SetPoint('TOPRIGHT',row.portrait,'TOPRIGHT',3,3)
    else row.marker:SetPoint('LEFT',row.healthBar,'LEFT',2,0) end
    local fontSize=math.max(7,math.min(12,hh-4))
    local nameLeft=ps>0 and 4 or markerSize+5
    row.name:ClearAllPoints(); row.name:SetPoint('LEFT',row.healthBar,'LEFT',nameLeft,0)
    row.name:SetSize(math.max(1,math.floor(healthWidth*.58)-nameLeft),hh); font(row.name,fontSize)
    row.name:SetAlpha(c.showName and 1 or 0)
    row.healthText:ClearAllPoints(); row.healthText:SetPoint('RIGHT',row.healthBar,'RIGHT',-4,0)
    row.healthText:SetSize(math.max(1,math.floor(healthWidth*.42)-4),hh); font(row.healthText,fontSize)
    row.healthText:SetJustifyH('RIGHT'); row.healthText:SetAlpha(1)
    P.HealthAvailable(row,row.healthAvailable~=false)
    -- Native renderers: only the chosen one is visible.
    if row.auras and not row.preview and row.source~='ghost' then
        local x,y,relative=P.IconOrigin(c)
        row.auras:ClearAllPoints(); row.auras:SetPoint('TOPLEFT',row.display,relative,x,y)
        row.auras:SetSize(c.slots*(size+ICON_GAP),cell); row.auras:SetAlpha(c.dots=='hud' and 1 or 0)
        configureGroup(row.auras,c,size,cell,ICON_GAP)
        for _,v in ipairs(row.iconVisuals or {}) do v.button:SetSize(size,cell); pcall(styleIcon,v,c,size) end
    end
    local barWidth=math.max(60,fullWidth-inner-pad)
    local bh=c.barHeight
    if row.barAuras then
        -- No height: the game sizes the group to the DoTs it shows.
        row.barAuras:ClearAllPoints(); row.barAuras:SetPoint('TOPLEFT',row.display,'TOPLEFT',inner,-header)
        row.barAuras:SetWidth(barWidth); row.barAuras:SetAlpha(c.dots=='equal' and c.barStyle~='kit' and 1 or 0)
        configureGroup(row.barAuras,c,barWidth,bh,BAR_GAP)
        for _,v in ipairs(row.barVisuals or {}) do
            v.button:SetSize(barWidth,bh)
            if v.height~=bh..(c.fontKey or '') then barGeometry(v,bh); v.height=bh..(c.fontKey or '') end
            local tex=S.Media.barTexture('flat')
            if v.tex~=tex and pcall(v.bar.SetStatusBarTexture,v.bar,tex) then v.tex=tex end
        end
    end
    if row.kitAuras then
        row.kitAuras:ClearAllPoints(); row.kitAuras:SetPoint('TOPLEFT',row.display,'TOPLEFT',inner,-header)
        row.kitAuras:SetWidth(barWidth); row.kitAuras:SetAlpha(c.barStyle=='kit' and 1 or 0)
        local signature=barWidth..':'..bh..':'..(c.idsKey or '')
        if row.kitAuras.kitSignature~=signature then
            row.kitAuras.kitSignature=signature
            for _,slot in ipairs(KIT_ORDER) do
                local key='kit'..slot
                if row.kitAuras.SetAuraGroupLayout then row.kitAuras:SetAuraGroupLayout(key,kitLayout(barWidth,bh)) end
                if row.kitAuras.SetAuraGroupCandidateFilters then row.kitAuras:SetAuraGroupCandidateFilters(key,kitFilters(c,slot)) end
            end
        end
        for _,v in ipairs(row.kitVisuals or {}) do
            v.button:SetSize(barWidth,bh)
            if v.height~=bh..(c.fontKey or '') then kitGeometry(v,bh); v.height=bh..(c.fontKey or '') end
            local tex=S.Media.barTexture('kit')
            if v.tex~=tex and pcall(v.bar.SetStatusBarTexture,v.bar,tex) then v.tex=tex end
            pcall(v.ring.SetShown,v.ring,c.kitRings)
            for _,e in ipairs(v.edges) do pcall(e.SetShown,e,c.kitEdges) end
        end
    end
    for _,v in ipairs(row.previewVisuals or {}) do
        P.PreviewKit(v,c.barStyle=='kit',bh)
        local hud=c.dots=='hud' and v.on
        v.icon:SetSize(size,size); v.icon:SetAlpha(hud and 1 or 0)
        applyShape(v.shape,c,size); v.shape.frame:SetShown(hud==true)
        placeTimeBar(v.timeBar,v.icon,size,hud and c.iconTimeBar)
        v.timer:ClearAllPoints(); v.timer:SetPoint('CENTER',v.icon,'CENTER'); v.timer:SetSize(size+4,size)
        v.timer:SetAlpha(hud and 1 or 0)
        v.lane:SetSize(barWidth,bh); v.lane:SetAlpha(c.dots=='equal' and v.on and 1 or 0)
        v.barIcon:ClearAllPoints(); v.barIcon:SetPoint('TOPLEFT',v.lane,'TOPLEFT'); v.barIcon:SetSize(bh,bh)
        local kitOffset=c.barStyle=='kit' and 3 or 0
        v.bar:ClearAllPoints(); v.bar:SetPoint('TOPLEFT',v.lane,'TOPLEFT',bh+3+kitOffset,0); v.bar:SetSize(barWidth-bh-3-kitOffset,bh)
        local fs=math.max(7,math.min(11,bh-3))
        v.name:ClearAllPoints(); v.name:SetPoint('LEFT',v.bar,'LEFT',4,0); v.name:SetSize(math.max(1,barWidth-bh-47),bh); font(v.name,fs)
        v.time:ClearAllPoints(); v.time:SetPoint('RIGHT',v.bar,'RIGHT',-4,0); v.time:SetSize(36,bh); font(v.time,fs)
    end
    if row.source=='ghost' then
        if not row.barNotice then row.barNotice=text(row.icons,11); row.barNotice:SetText(S.L.mtGhostTimers) end
        row.barNotice:ClearAllPoints(); row.barNotice:SetPoint('TOPLEFT',row.display,'TOPLEFT',inner,-header)
        row.barNotice:SetSize(barWidth,bh); row.barNotice:SetAlpha(c.dots=='equal' and 1 or 0)
        P.GhostIcons(row,row.ghostEstimates)
    end
    markerWidgets(row)
    return healthWidth,step
end
