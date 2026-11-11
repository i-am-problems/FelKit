local addon,S=...
-- Fonts and bar textures (original FelKit code). The game's own fonts and a
-- few textures ship with FelKit; anything another addon registered with
-- LibSharedMedia-3.0 is offered too.
local M={}; S.Media=M
local MEDIA='Interface\\AddOns\\'..addon..'\\Media\\'

M.FONTS={
    {value='friz',label='Friz Quadrata',path='Fonts\\FRIZQT__.TTF'},
    {value='arialn',label='Arial Narrow',path='Fonts\\ARIALN.TTF'},
    {value='morpheus',label='Morpheus',path='Fonts\\MORPHEUS.TTF'},
    {value='skurri',label='Skurri',path='Fonts\\SKURRI.TTF'},
}
M.TEXTURES={
    {value='felkit',label='FelKit sheen',path=MEDIA..'fk_bar'},
    {value='glass',label='FelKit glass',path=MEDIA..'fk_bar_glass'},
    {value='gradient',label='FelKit gradient',path=MEDIA..'fk_bar_gradient'},
    {value='stripes',label='FelKit stripes',path=MEDIA..'fk_bar_stripes'},
    {value='flat',label='Flat',path='Interface\\Buttons\\WHITE8X8'},
    {value='blizzard',label='Blizzard',path='Interface\\TargetingFrame\\UI-StatusBar'},
    {value='raid',label='Blizzard raid',path='Interface\\RaidFrame\\Raid-Bar-Hp-Fill'},
    {value='skills',label='Blizzard skills',path='Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar'},
}
M.OUTLINES={
    {value='',label='None'},{value='OUTLINE',label='Outline'},{value='THICKOUTLINE',label='Thick'},
    {value='MONOCHROME,OUTLINE',label='Pixel'},
}

local function lsm()
    return LibStub and LibStub('LibSharedMedia-3.0',true)
end
-- The full list of a kind ('font' or 'statusbar'): built-ins, then LibSharedMedia.
local function list(kind)
    local base=kind=='font' and M.FONTS or M.TEXTURES
    local out={}
    for _,o in ipairs(base) do out[#out+1]=o end
    local L=lsm()
    if L then
        local ok,names=pcall(L.List,L,kind)
        if ok and type(names)=='table' then
            for _,name in ipairs(names) do
                local okPath,path=pcall(L.Fetch,L,kind,name)
                if okPath and type(path)=='string' then out[#out+1]={value='lsm:'..name,label=name,path=path} end
            end
        end
    end
    return out
end
function M.fonts() return list('font') end
function M.textures() return list('statusbar') end
local function find(kind,value)
    if type(value)~='string' then return nil end
    if value:sub(1,4)=='lsm:' then
        local L=lsm()
        if L then local ok,path=pcall(L.Fetch,L,kind,value:sub(5),true); if ok and type(path)=='string' then return path end end
        return nil
    end
    for _,o in ipairs(kind=='font' and M.FONTS or M.TEXTURES) do if o.value==value then return o.path end end
end

-- General font: every FelKit text that has no override.
function M.fontPath()
    return find('font',S.db and S.db.fontFace) or STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF'
end
function M.outline()
    local o=S.db and S.db.fontOutline
    if type(o)=='string' then return o end
    return 'OUTLINE'
end
-- The settings window and in-world frames call S.font(); it now follows the setting.
S.font=function() return M.fontPath() end
S.fontOutline=function() return M.outline() end

-- DoT bars: their own face, size and outline, or the general ones.
function M.barFont()
    local p=S.db and S.db.multiTarget or {}
    local path=p.barFont and p.barFont~='general' and find('font',p.barFont) or M.fontPath()
    local outline=(p.barFontOutline and p.barFontOutline~='general') and p.barFontOutline or M.outline()
    local size=tonumber(p.barFontSize) or 0
    return path,outline,size>0 and size or nil
end
function M.barFontKey()
    local path,outline,size=M.barFont()
    return path..'|'..outline..'|'..tostring(size)
end
-- Icon shapes: a mask clips the spell icon, a neutral bevelled frame is tinted
-- in the border colour. The masks fill MASK_EXTENT of their texture, the
-- frame's inner edge sits just inside that.
M.SHAPES={'square','rounded','round','diamond','hexagon'}
M.BORDERS={'none','gold','purple','silver','black','red','fel'}
M.BORDER_COLORS={gold={1,.80,.42},purple={.66,.42,1},silver={.86,.88,.95},black={.10,.10,.12},
    red={1,.25,.22},fel={.45,1,.35}}
local MASK_EXTENT,ICON_CROP=.88,(1-1/1.3)/2
function M.shapeParts(owner,icon,layer)
    local s={icon=icon}
    s.mask=owner:CreateMaskTexture(); icon:AddMaskTexture(s.mask)
    s.frame=layer:CreateTexture(nil,'OVERLAY',nil,1)
    return s
end
function M.applyShape(s,shape,borderKey,size,cooldown)
    shape=shape or 'square'
    local border=M.BORDER_COLORS[borderKey]
    local key=shape..':'..tostring(borderKey)..':'..size
    if s.key==key then return end
    s.key=key
    local plain=shape=='square' and not border
    local o=border and 0 or math.floor(size*(1/MASK_EXTENT-1)/2+.5)
    s.mask:SetTexture(MEDIA..'fk_mask_'..shape,'CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
    s.mask:ClearAllPoints(); s.mask:SetPoint('TOPLEFT',s.icon,'TOPLEFT',-o,o); s.mask:SetPoint('BOTTOMRIGHT',s.icon,'BOTTOMRIGHT',o,-o)
    if plain then s.icon:SetTexCoord(ICON_CROP,1-ICON_CROP,ICON_CROP,1-ICON_CROP) else s.icon:SetTexCoord(.08,.92,.08,.92) end
    s.frame:SetTexture(MEDIA..'fk_frame_'..shape); s.frame:ClearAllPoints(); s.frame:SetAllPoints(s.icon)
    if border then s.frame:SetVertexColor(border[1],border[2],border[3],1); s.frame:SetAlpha(1) else s.frame:SetAlpha(0) end
    if cooldown then
        cooldown:ClearAllPoints()
        if plain then cooldown:SetAllPoints(s.icon)
        else cooldown:SetPoint('TOPLEFT',s.mask,'TOPLEFT'); cooldown:SetPoint('BOTTOMRIGHT',s.mask,'BOTTOMRIGHT') end
        if cooldown.SetSwipeTexture then
            pcall(cooldown.SetSwipeTexture,cooldown,plain and 'Interface\\Buttons\\WHITE8X8' or MEDIA..'fk_mask_'..shape)
        end
    end
end

-- DoT bar texture; 'auto' keeps each style's own look.
function M.barTexture(style)
    local p=S.db and S.db.multiTarget or {}
    local chosen=p.barTexture and p.barTexture~='auto' and find('statusbar',p.barTexture)
    if chosen then return chosen end
    return style=='kit' and MEDIA..'fk_bar' or 'Interface\\Buttons\\WHITE8X8'
end
