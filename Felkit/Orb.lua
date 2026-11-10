local addon,S=...
-- Orb layout: the shard counter becomes a glass orb, the main tools sit on an
-- arc round its top, the talent buttons sit small under it, and the everyday
-- buffs make a row under a fel divider. Original Felkit code and artwork.
local O={}; S.Orb=O
local A=S.API
local MEDIA='Interface\\AddOns\\'..addon..'\\Media\\'
O.MEDIA=MEDIA
O.ARC={'health','soul','curse1','curse2','demon','ward'}
O.SMALL={'sacrifice','link','domination'}
O.ROW={'armor','weapon','drain','summon','utility'}
O.ORB_SIZE=58
local GOLD={0.84,0.65,0.28}
local where={}
for _,k in ipairs(O.ARC) do where[k]='arc' end
for _,k in ipairs(O.SMALL) do where[k]='small' end
for _,k in ipairs(O.ROW) do where[k]='row' end
O.where=where

function O.on() return S.db and S.db.kit and S.db.kit.layout=='orb' end

-- Kit buttons -------------------------------------------------------------------
-- Every button gets both looks; the layout decides which one shows.
local function build(b)
    if b.orbRing then return end
    b.orbMask=b:CreateMaskTexture()
    b.orbMask:SetTexture(MEDIA..'fk_mask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
    b.orbMask:SetAllPoints(b)
    b.orbBack=b:CreateTexture(nil,'BACKGROUND',nil,-2)
    b.orbBack:SetTexture(MEDIA..'fk_mask'); b.orbBack:SetVertexColor(0.04,0.02,0.07,0.95)
    b.orbBack:SetPoint('CENTER'); b.orbBack:Hide()
    local ringHost=CreateFrame('Frame',nil,b); ringHost:SetAllPoints(b); ringHost:EnableMouse(false)
    ringHost:SetFrameLevel(b:GetFrameLevel()+2); b.orbRingHost=ringHost
    b.orbRing=ringHost:CreateTexture(nil,'OVERLAY')
    b.orbRing:SetTexture(MEDIA..'fk_ring'); b.orbRing:SetPoint('CENTER')
    b.orbHighlight=b:CreateTexture(nil,'HIGHLIGHT')
    b.orbHighlight:SetTexture(MEDIA..'fk_glow_fel'); b.orbHighlight:SetBlendMode('ADD'); b.orbHighlight:SetPoint('CENTER')
    b.orbHighlight:SetAlpha(0.55)
end
-- Texts ride above the ring in the orb look, on the button otherwise.
local function texts(b,parent)
    for _,key in ipairs({'time','count','statusMark','queueCode','queueCount'}) do
        if b[key] then b[key]:SetParent(parent) end
    end
end
function O.skin(b,size)
    build(b)
    local on=O.on()
    b.orbSkin=on
    b.orbRingHost:SetShown(on); b.orbBack:SetShown(on)
    texts(b,on and b.orbRingHost or b)
    if on then
        b:SetBackdropColor(0,0,0,0); b:SetBackdropBorderColor(0,0,0,0)
        -- The icon fills the button; the round mask leaves it just inside the ring.
        b.icon:ClearAllPoints(); b.icon:SetAllPoints(b)
        if not b.orbMasked then b.icon:AddMaskTexture(b.orbMask); b.orbMasked=true end
        b.orbBack:SetSize(size,size); b.orbRing:SetSize(size*1.18,size*1.18)
        b.orbHighlight:SetSize(size*1.5,size*1.5); b.orbHighlight:Show()
        b:SetHighlightTexture(b.orbHighlight)
        if b.cooldown.SetSwipeTexture then pcall(b.cooldown.SetSwipeTexture,b.cooldown,MEDIA..'fk_mask') end
        if b.cooldown.SetUseCircularEdge then pcall(b.cooldown.SetUseCircularEdge,b.cooldown,true) end
        if b.halo then
            b.halo:SetTexture(MEDIA..'fk_glow'); b.halo:SetDrawLayer('BACKGROUND',-3)
        end
        b.time:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',math.max(9,math.floor(size*0.3)),'OUTLINE')
        b.time:ClearAllPoints(); b.time:SetPoint('CENTER',0,0)
        b.count:ClearAllPoints(); b.count:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',2,-2)
        O.border(b,'normal')
    else
        if b.orbMasked then b.icon:RemoveMaskTexture(b.orbMask); b.orbMasked=nil end
        b.orbHighlight:Hide()
        b.icon:ClearAllPoints(); b.icon:SetPoint('TOPLEFT',2,-2); b.icon:SetPoint('BOTTOMRIGHT',-2,2)
        b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
        b:SetBackdropColor(0.035,0.025,0.055,0.96)
        if b.cooldown.SetSwipeTexture then pcall(b.cooldown.SetSwipeTexture,b.cooldown,'Interface\\Buttons\\WHITE8X8') end
        if b.cooldown.SetUseCircularEdge then pcall(b.cooldown.SetUseCircularEdge,b.cooldown,false) end
        if b.halo then
            b.halo:SetTexture('Interface\\Buttons\\UI-ActionButton-Border'); b.halo:SetDrawLayer('OVERLAY')
        end
        b.time:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',10,'OUTLINE')
        b.time:ClearAllPoints(); b.time:SetPoint('BOTTOM',0,2)
        b.count:ClearAllPoints(); b.count:SetPoint('TOPRIGHT',-2,-2)
    end
end
-- Border states: 'normal', 'soul' (soulstone out), 'missing' (reminder),
-- 'active' (a buff from the Buffs slot is on).
local STATES={
    normal={square={0.43,0.24,0.60},ring=GOLD},
    soul={square={0.3,0.9,0.45},ring={0.45,1,0.55}},
    missing={square={1,0.7,0.2},ring={1,0.55,0.15}},
    active={square={0.3,0.9,0.45},ring={0.45,1,0.55}},
}
function O.border(b,state)
    local s=STATES[state] or STATES.normal
    if b.orbSkin then
        b.orbRing:SetVertexColor(s.ring[1],s.ring[2],s.ring[3])
        b:SetBackdropBorderColor(0,0,0,0)
    else
        b:SetBackdropBorderColor(s.square[1],s.square[2],s.square[3],1)
    end
end

-- The counter as an orb ------------------------------------------------------------
function O.skinCounter()
    local c=S.UI.counter; if not c or A.combat() then return end
    local shard=c.icon
    if not c.orbRing then
        local host=CreateFrame('Frame',nil,shard); host:SetAllPoints(shard); host:EnableMouse(false)
        host:SetFrameLevel(shard:GetFrameLevel()+1); c.orbHost=host
        c.orbRing=host:CreateTexture(nil,'OVERLAY'); c.orbRing:SetTexture(MEDIA..'fk_orb_ring'); c.orbRing:SetPoint('CENTER')
        c.orbHalo=shard:CreateTexture(nil,'BACKGROUND',nil,-4); c.orbHalo:SetTexture(MEDIA..'fk_glow_fel')
        c.orbHalo:SetBlendMode('ADD'); c.orbHalo:SetPoint('CENTER'); c.orbHalo:SetAlpha(0.35)
        -- Centre art over the glass: drawn on the button, under the ring and the count.
        c.orbArt=shard:CreateTexture(nil,'ARTWORK',nil,2); c.orbArt:SetPoint('CENTER')
        c.orbArtMask=shard:CreateMaskTexture()
        c.orbArtMask:SetTexture(MEDIA..'fk_mask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
        c.orbArtMask:SetAllPoints(c.orbArt)
    end
    local on=O.on()
    c.orbHost:SetShown(on); c.orbHalo:SetShown(on and S.db.kit.orbGlow~=false)
    if on then
        local size=S.db.kit.orbSize or O.ORB_SIZE
        c:SetSize(size,size)
        shard:SetNormalTexture(MEDIA..'fk_orb')
        shard:SetHighlightTexture(MEDIA..'fk_glow_fel'); shard:GetHighlightTexture():SetBlendMode('ADD')
        shard:GetHighlightTexture():SetAlpha(0.4)
        c.orbRing:SetSize(size*1.16,size*1.16); c.orbHalo:SetSize(size*1.9,size*1.9)
        c.text:SetParent(c.orbHost)
        if c.halo then c.halo:SetTexture(MEDIA..'fk_glow'); c.halo:SetDrawLayer('BACKGROUND',-3) end
        O.centreArt(c,size)
        O.countPosition(c,size)
    else
        c.orbArt:Hide()
        c.text:ClearAllPoints(); c.text:SetPoint('CENTER',0,0); c.text:SetAlpha(1)
        if c.text.SetTextScale then pcall(c.text.SetTextScale,c.text,1) end
        c:SetSize(46,46)
        local icon=C_Item and A.call(C_Item.GetItemIconByID,6265)
        shard:SetNormalTexture(icon or 'Interface\\Icons\\INV_Misc_Gem_Amethyst_02')
        shard:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
        c.text:SetParent(shard)
        if c.halo then c.halo:SetTexture('Interface\\Buttons\\UI-ActionButton-Border'); c.halo:SetDrawLayer('OVERLAY') end
    end
end

-- Centre art: Felkit's own crystal shards, or the game's Soul Shard or class icon.
function O.centreArt(c,size)
    local art=S.db.kit.orbArt or 'fel'
    local t=c.orbArt
    if c.orbArtMasked then t:RemoveMaskTexture(c.orbArtMask); c.orbArtMasked=nil end
    t:SetTexCoord(0,1,0,1); t:SetVertexColor(1,1,1)
    if art=='fel' or art=='shadow' then
        t:SetTexture(MEDIA..'fk_shard_'..art); t:SetSize(size*1.05,size*1.05)
    elseif art=='item' then
        local icon=C_Item and A.call(C_Item.GetItemIconByID,6265)
        t:SetTexture(icon or 'Interface\\Icons\\INV_Misc_Gem_Amethyst_02'); t:SetSize(size*0.72,size*0.72)
        t:SetTexCoord(0.07,0.93,0.07,0.93); t:AddMaskTexture(c.orbArtMask); c.orbArtMasked=true
    elseif art=='class' then
        local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS.WARLOCK
        t:SetTexture('Interface\\TargetingFrame\\UI-Classes-Circles'); t:SetSize(size*0.74,size*0.74)
        if coords then t:SetTexCoord(coords[1],coords[2],coords[3],coords[4]) end
    else t:Hide(); return end
    t:Show()
end
-- Shard count: in the middle, small in the bottom-right corner, or hidden.
function O.countPosition(c,size)
    local pos=S.db.kit.countPos or 'middle'
    c.text:ClearAllPoints()
    if pos=='corner' then
        c.text:SetPoint('CENTER',c.icon,'BOTTOMRIGHT',-size*0.12,size*0.14)
        if c.text.SetTextScale then pcall(c.text.SetTextScale,c.text,0.62) end
    else
        c.text:SetPoint('CENTER',0,0)
        if c.text.SetTextScale then pcall(c.text.SetTextScale,c.text,1) end
    end
    c.text:SetAlpha(pos=='hidden' and 0 or 1)
end

-- Placement --------------------------------------------------------------------------
-- visible: the kit buttons to place, any order. Positions are in kit units,
-- relative to the orb's centre (the kit body carries the kit scale).
function O.place(visible,cfg)
    local scale=cfg.scale or 1
    local size=cfg.size
    local small=math.floor(size*(cfg.smallScale or 62)/100+0.5)
    local r0=((cfg.orbSize or O.ORB_SIZE)/2)/scale
    local gap=cfg.orbGap or 7
    local byKey={}
    for _,b in ipairs(visible) do byKey[b.group.key]=b end
    local function pick(list)
        local out={}
        for _,k in ipairs(list) do if byKey[k] then out[#out+1]=byKey[k] end end
        return out
    end
    local arc,smalls,row=pick(O.ARC),pick(O.SMALL),pick(O.ROW)
    local function put(b,x,y,s,flyUp)
        b:ClearAllPoints(); b:SetPoint('CENTER',S.UI.counter,'CENTER',x,y); b:SetSize(s,s)
        O.skin(b,s)
        b.flyout:ClearAllPoints()
        if flyUp then b.flyout:SetPoint('BOTTOM',b,'TOP',0,8) else b.flyout:SetPoint('TOP',b,'BOTTOM',0,-8) end
    end
    -- Arc: up to 220 degrees over the top, spread evenly; fewer slots close up.
    local ra=r0+size/2+gap
    local n=#arc
    local chord=math.deg(2*math.asin(math.min(1,(size+4)/(2*ra))))
    local arcSpan=cfg.orbArc or 220
    local step=n>1 and math.min(math.max(chord+4,arcSpan/5),arcSpan/(n-1)) or 0
    local start=90+step*(n-1)/2
    for i,b in ipairs(arc) do
        local a=math.rad(start-(i-1)*step)
        put(b,math.cos(a)*ra,math.sin(a)*ra,size,true)
    end
    local y=-(r0+small/2+gap+3)
    local smallGap=small+5
    for i,b in ipairs(smalls) do put(b,(i-(#smalls+1)/2)*smallGap,y,small,false) end
    local bottom=#smalls>0 and (y-small/2) or -r0
    local divY=bottom-8
    local rowGap=size+(cfg.rowGap or 7)
    local rowY=divY-8-size/2
    for i,b in ipairs(row) do put(b,(i-(#row+1)/2)*rowGap,rowY,size,false) end
    if not O.divider then
        O.divider=S.Kit.body:CreateTexture(nil,'ARTWORK')
        O.divider:SetTexture(MEDIA..'fk_divider')
    end
    O.divider:ClearAllPoints(); O.divider:SetPoint('CENTER',S.UI.counter,'CENTER',0,divY)
    O.divider:SetSize(math.max(3,#row)*rowGap+24,12)
    O.divider:SetShown(#row>0 and cfg.divider~=false)
end
function O.hideExtras()
    if O.divider then O.divider:Hide() end
end
