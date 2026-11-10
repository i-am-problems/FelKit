-- Warlock All-in-One glue for the vendored Does It Die tracking and nameplates.
-- Original code (MIT), except the look tables and the three small helpers below,
-- copied unchanged from DoesItDie v0.8.2 Display.lua (MIT, Joe Greive): Display.lua
-- itself (the marker on Blizzard's target frame) is not used. Loaded after
-- Tracking.lua (which creates ns.lists) and before Nameplates.lua.
local addon, S = ...
local ns = S.DID

-- From Display.lua --------------------------------------------------------------
local COLOR_PRESETS = {
    { id = "purple", label = "Purple", rgb = { 0.7, 0.3, 1 } },
    { id = "gold",   label = "Gold",   rgb = { 1, 0.85, 0.1 } },
    { id = "white",  label = "White",  rgb = { 1, 1, 1 } },
    { id = "red",    label = "Red",    rgb = { 1, 0.2, 0.2 } },
    { id = "orange", label = "Orange", rgb = { 1, 0.55, 0.1 } },
    { id = "green",  label = "Green",  rgb = { 0.3, 1, 0.3 } },
    { id = "cyan",   label = "Cyan",   rgb = { 0.2, 0.9, 1 } },
    { id = "pink",   label = "Pink",   rgb = { 1, 0.45, 0.6 } },
    { id = "black",  label = "Black",  rgb = { 0, 0, 0 } },
}
local COLOR_BY_ID = {}
for _, preset in ipairs(COLOR_PRESETS) do COLOR_BY_ID[preset.id] = preset.rgb end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TEXTURE_DIR = "Interface\\AddOns\\" .. addon .. "\\DoesItDie\\Textures\\"

local SKULL_ICONS = {
    { id = "skull",  label = "Raid skull",      path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    { id = "cross",  label = "Red X",           path = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    { id = "check",  label = "Green checkmark", path = "Interface\\RaidFrame\\ReadyCheck-Ready" },
    { id = "boss",   label = "Boss skull",      path = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
}

local FILL_STYLES = {
    { id = "none",     label = "None" },
    { id = "flat",     label = "Flat",               path = WHITE },
    { id = "smooth",   label = "Health bar texture", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { id = "raid",     label = "Raid bar texture",   path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { id = "stripes",  label = "Diagonal stripes",   path = TEXTURE_DIR .. "Stripes", tiled = true },
    { id = "gradient", label = "Fade in from left",  path = WHITE, gradient = true },
}

-- "By spell school" colors, keyed by school mask (Frostfire = Fire + Frost).
local SCHOOL_COLORS = {
    [1] = { 1, 0.3, 0.3 },      -- Physical (bleeds)
    [2] = { 1, 0.9, 0.45 },     -- Holy
    [4] = { 1, 0.55, 0.15 },    -- Fire
    [8] = { 0.35, 1, 0.35 },    -- Nature
    [16] = { 0.45, 0.8, 1 },    -- Frost
    [20] = { 0.75, 0.6, 1 },    -- Frostfire
    [32] = { 0.7, 0.35, 1 },    -- Shadow
    [64] = { 1, 0.55, 1 },      -- Arcane
}

local DOT_PALETTE = {
    { 0.95, 0.3, 0.3 }, { 0.3, 0.75, 1 }, { 1, 0.8, 0.2 }, { 0.45, 1, 0.45 },
    { 0.85, 0.4, 1 }, { 1, 0.55, 0.15 }, { 0.3, 1, 0.9 }, { 1, 0.45, 0.75 },
}
local paletteIndexByName, nextPaletteIndex = {}, 1

local function dotColor(entry, mode)
    if mode == "school" then
        return SCHOOL_COLORS[entry.school] or COLOR_BY_ID.white
    end
    local index = paletteIndexByName[entry.name]
    if not index then
        index = (nextPaletteIndex - 1) % #DOT_PALETTE + 1
        paletteIndexByName[entry.name], nextPaletteIndex = index, nextPaletteIndex + 1
    end
    return DOT_PALETTE[index]
end

local function findById(list, id)
    for _, entry in ipairs(list) do
        if entry.id == id then return entry end
    end
    return list[1]
end

local function colorOf(id, opacityPercent)
    local rgb = COLOR_BY_ID[id] or COLOR_BY_ID.white
    return rgb[1], rgb[2], rgb[3], (opacityPercent or 100) / 100
end
-- End of Display.lua copies ------------------------------------------------------

ns.lists.colors, ns.lists.icons, ns.lists.fills = COLOR_PRESETS, SKULL_ICONS, FILL_STYLES
ns.dotColor, ns.colorOf, ns.findById, ns.textureDir = dotColor, colorOf, findById, TEXTURE_DIR
-- No target frame display: these are what Tracking.lua calls on it.
ns.display = {
    schoolColors = SCHOOL_COLORS,
    setDb = function() end,
    attach = function() return true end,
    animate = function() end,
    forgetTracedDamage = function() end,
    hasHealthBar = function() return false end,
}
ns.playFlash = function() end

-- The original add-on, when it is installed and loaded too, already draws on
-- nameplates: ours stay off then, so a plate never gets two markers.
-- Known for good once every add-on has loaded (asked 10 times a second).
local externalLoaded
function ns.external()
    if externalLoaded ~= nil then return externalLoaded end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DoesItDie") == true or false
    if IsLoggedIn and IsLoggedIn() then externalLoaded = loaded end
    return loaded
end
local function settings()
    local db = S.db
    return S.ready and db and db.enabled and type(db.multiTarget) == "table" and db.multiTarget or nil
end
function ns.platesEnabled()
    local p = settings()
    return p ~= nil and p.didPlates == true and not ns.external()
end
function ns.barsEnabled()
    local p = settings()
    return p ~= nil and S.db.enemies == true and p.didBars == true
end
-- Tracking only runs while the bars or the nameplates use it.
function ns.anyEnabled()
    return ns.barsEnabled() or ns.platesEnabled()
end

local LOOK_KEYS = { "plateFillTexture", "plateFillColor", "plateFillOpacity", "plateDotColors",
    "plateOutlineStyle", "plateOutlineColor", "plateOutlineThickness", "plateIcon" }
-- 0.7.1: one look chosen in the options for the DoT table rows and the
-- nameplates (the nameplates keep their own icon size and position).
function ns.applyLook(look)
    local p = settings()
    if not p then return end
    look.plateFillTexture, look.plateFillColor, look.plateFillOpacity = p.didFill, p.didColor, p.didOpacity
    look.plateDotColors, look.plateOutlineStyle = p.didDotColors, p.didOutline
    look.plateOutlineColor, look.plateOutlineThickness, look.plateIcon = p.didOutlineColor, p.didOutlineSize, p.didIcon
    local db = ns.db
    if db then
        for _, key in ipairs(LOOK_KEYS) do db[key] = look[key] end
        -- The plates compare this number before rebuilding their style.
        db.styleVersion = (db.styleVersion or 0) + 1
        db.nameplateIconSize, db.nameplateIconPosition = p.didPlateIconSize, p.didPlateIconPos
        -- Clear of the level badge on the left (Does It Die's default), none elsewhere.
        db.plateIconOffsetY = p.didPlateIconPos == "left" and 15 or 0
    end
end

-- Total, school mask, duration and tick interval of a periodic spell, from the
-- add-on's spell data (no description text): used when no language reads it.
function ns.spellData(spellID)
    local spec = S.SpellData and S.SpellData.spells[spellID]
    local data = spec and S.Spells and S.Spells.periodic and S.Spells.periodic(spellID)
    if not data or type(data.total) ~= "number" or data.total <= 0 then return nil end
    local school = spec.school and 2 ^ (spec.school - 1) or 32
    return data.total, school, data.duration, data.interval
end

-- Tracking.lua calls this every 0.1 s and after casts and ticks: expire DoTs,
-- then let the DoT table redraw its markers (the nameplates have their own timer).
function ns.refresh()
    if ns.tracking and ns.tracking.housekeep then ns.tracking.housekeep(GetTime()) end
    local P = S.WH and S.WH.Presentation
    if P and P.UpdateMarkers then pcall(P.UpdateMarkers) end
end
