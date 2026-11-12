-- Warlock All-in-One glue for the vendored Warlock HUD Multi-Target DoTs window
-- (original code, MIT). Replaces the parts of Warlock HUD's core the window uses:
-- profile, spell catalogue, known-spell checks and the enable switch. Settings
-- live in FelkitDB.multiTarget; the window's on/off is the Enemies &
-- DoTs module switch (S.db.enemies).
local _, S = ...
local WH = S.WH
local E = WH.Effects
local MAIN = {}
for _, key in ipairs(E.MainKeys) do MAIN[key] = true end
local BRAND = 1293696

local function known(id)
    if type(IsPlayerSpell) == 'function' then
        local ok, value = pcall(IsPlayerSpell, id)
        if ok and value == true then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, value = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and value == true then return true end
    end
    return false
end
local function knownSpell(spell)
    for _, id in ipairs(spell.ids) do if known(id) then return true end end
    return false
end
-- Passive talents may be missing from the spellbook. Compare the talent name
-- with the client's own (localized) name of the Brand effect, never English.
local function knowsBrand()
    if known(BRAND) then return true end
    if not GetNumTalents or not GetTalentInfo then return false end
    local brand = C_Spell and C_Spell.GetSpellName and S.API.public(S.API.call(C_Spell.GetSpellName, BRAND))
    if type(brand) ~= 'string' or brand == '' then return false end
    local ok, count = pcall(GetNumTalents, 2)
    if not ok or type(count) ~= 'number' then return false end
    for index = 1, math.min(count, 60) do
        local found, name, _, _, _, rank = pcall(GetTalentInfo, 2, index)
        if found and name == brand then return type(rank) == 'number' and rank > 0 end
    end
    return false
end

local function refreshOptions()
    if S.Options and S.Options.frame and S.Options.frame:IsShown() then pcall(S.Options.refresh) end
end
-- multiDotEnabled is the module switch itself, so the window's close button,
-- the settings page and the home tiles always agree. With instances turned off
-- the module rests inside dungeons, raids and scenarios.
local function inInstance()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    return inside == true and (kind == 'party' or kind == 'raid' or kind == 'scenario')
end
local profileMeta = {
    __index = function(t, key)
        if key == 'multiDotEnabled' then
            return S.db ~= nil and S.db.enemies == true and not (rawget(t, 'instances') == false and inInstance())
        end
    end,
    __newindex = function(t, key, value)
        if key == 'multiDotEnabled' then
            if S.db then S.db.enemies = value == true; refreshOptions() end
        else rawset(t, key, value) end
    end,
}

local API = {Spells = E.Spells, MainKeys = E.MainKeys}
WH.API = API
function API.GetProfile()
    local db = S.db
    if not db or type(db.multiTarget) ~= 'table' then return nil end
    local p = db.multiTarget
    if getmetatable(p) ~= profileMeta then setmetatable(p, profileMeta) end
    return p
end
function API.InitializeProfiles() end
function API.IsAddonEnabled()
    return S.ready == true and not S.legacyEnemies and S.db ~= nil and S.db.enabled == true
end
function API.GetDotDefaultSpell() return nil end
local function on(p, key) return p.enabled[key] ~= false end
function API.HasMultiTargetEffect(key)
    local p=API.GetProfile()
    if not p then return false end
    if key=='demonicbrand' then return knowsBrand() end
    if MAIN[key] then
        for _,spell in ipairs(E.Spells) do
            if spell.group~=2 and E.MainKeys[spell.slot]==key and knownSpell(spell) then return true end
        end
    end
    return false
end
function API.GetMultiTargetEffectOrder()
    local p = API.GetProfile()
    if not p then return {} end
    local visible = {}
    for _, key in ipairs(p.mainOrder) do
        local has=false
        if key=='demonicbrand' then has=on(p,'Demonic Brand') and knowsBrand()
        elseif MAIN[key] then
            for _,spell in ipairs(E.Spells) do
                if spell.group~=2 and E.MainKeys[spell.slot]==key and on(p,spell.name) and knownSpell(spell) then has=true; break end
            end
        end
        if has and on(p,key) then visible[#visible + 1] = key end
    end
    return visible
end
API.knownSpell, API.knowsBrand = knownSpell, knowsBrand

-- Called by the add-on after any settings change (S.refreshAll).
function WH.refresh()
    if WH.MultiTarget and WH.MultiTarget.Refresh then WH.MultiTarget.Refresh() end
end
