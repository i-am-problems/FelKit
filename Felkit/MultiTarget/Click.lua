-- Original Warlock All-in-One code (MIT): click a health bar of the DoT table
-- to target that enemy.
--
-- Targeting needs secure buttons, and the game lets no add-on move a secure
-- button, resize it or change its unit in combat. Each live row therefore gets
-- one button for its own unit token (never changed), laid over its health bar
-- out of combat from the public layout, on a holder of its own on UIParent (a
-- secure frame anchored to a row would lock the whole table in combat).
--   * Warlock HUD rows keep their places during combat (Layout freezes them),
--     so the buttons stay on their enemies: clicking works in combat too. A row
--     that appears in combat takes the free place its button already covers;
--     a secure state driver shows that button only while its unit exists.
--   * Equal-width rows change height with their DoTs in combat (the native
--     chain), so their buttons hide from the start of combat until its end.
local _, S = ...
local WH = S.WH
local C = {buttons={}, placed=0, shown=0}
-- Placement runs every 0.2 s while something moves, every second once a pass
-- changed nothing, and at once when the table says its layout changed (Touch).
local IDLE = 1
WH.Click = C
local INTERVAL = 0.2
local source = function() return {}, nil, nil, false end
function C.SetSource(fn) source = fn end
function C.Touch() C.dirty = true end

local function lockdown() return InCombatLockdown and InCombatLockdown() and true or false end
local function number(v) v = S.API.public(v); return type(v) == 'number' and v or nil end
-- Rectangle in UIParent units, or nil when hidden, unplaced or secret.
local function rect(f,hidden)
    if not f or not (hidden or f:IsVisible()) then return end
    local ok, l, b, w, h = pcall(function() return f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight() end)
    if not ok then return end
    l, b, w, h = number(l), number(b), number(w), number(h)
    if not (l and b and w and h) or w <= 0 or h <= 0 then return end
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * s, b * s, (l + w) * s, (b + h) * s
end
local function holder()
    if C.holder or lockdown() then return C.holder end
    local h = CreateFrame('Frame', 'FelkitWHClick', UIParent, 'SecureHandlerStateTemplate')
    h:SetAllPoints(UIParent); h:SetFrameStrata('MEDIUM'); h:Hide()
    C.holder = h; return h
end
local function button(row)
    local b = C.buttons[row]
    if b then return b end
    b = CreateFrame('Button', nil, C.holder, 'SecureActionButtonTemplate,SecureHandlerStateTemplate')
    b:RegisterForClicks('AnyUp'); b:SetAttribute('useOnKeyDown', false)
    b:SetAttribute('type1', 'target'); b:SetAttribute('unit', row.unit)
    -- In combat only: shown while the unit exists, hidden otherwise.
    b:SetAttribute('_onstate-clickunit', [[ if newstate == 'on' then self:Show() elseif newstate == 'off' then self:Hide() end ]])
    local glow = b:CreateTexture(nil, 'HIGHLIGHT'); glow:SetAllPoints(); glow:SetColorTexture(1, 1, 1, .08)
    b:EnableMouseWheel(true)
    b:SetScript('OnMouseWheel', function(_, delta)
        local _, scroll = source()
        local handler = scroll and scroll:GetScript('OnMouseWheel')
        if handler then handler(scroll, delta) end
    end)
    b:Hide()
    C.buttons[row] = b; return b
end
local function drive(b, unit, on)
    if b.driven == (on and unit or false) then return end
    if on and RegisterStateDriver then
        RegisterStateDriver(b, 'clickunit', '[nocombat] idle; [@' .. unit .. ',exists] on; off')
    elseif b.driven and UnregisterStateDriver then
        UnregisterStateDriver(b, 'clickunit')
    end
    b.driven = on and unit or false
end
local function holderRule(h, rule)
    if C.rule == rule then return end
    if C.rule and UnregisterStateDriver then UnregisterStateDriver(h, 'visibility') end
    if rule and RegisterStateDriver then RegisterStateDriver(h, 'visibility', rule) end
    C.rule = rule
end
-- Out of combat only: positions, visibility and combat rules from the layout.
local function show(b, on)
    if b.on == on then return end
    if on then b:Show() else b:Hide() end
    b.on = on
end
function C.Place()
    C.placed, C.dirty = GetTime(), false
    if lockdown() then return end
    local rows, scroll, root, enabled, combatOnly = source()
    local P = WH.Presentation
    local hud = P.current.dots == 'hud'
    -- Window shown in combat only: HUD buttons come with it, bars never.
    local hidden = combatOnly and root and not root:IsShown()
    if not enabled or not root or (combatOnly and not hud) or not (hidden or root:IsVisible()) then
        -- Hidden once; nothing to do on the next passes until it comes back.
        if not C.off and C.holder then
            holderRule(C.holder, nil); C.holder:Hide()
            for _, b in pairs(C.buttons) do drive(b, nil, false); show(b, false) end
        end
        C.off, C.idle, C.shown = true, true, 0; return
    end
    local h = holder()
    if not h then return end
    local changed = C.off ~= false
    C.off = false
    -- HUD: buttons through combat; equal-width: hidden from combat start.
    if combatOnly then holderRule(h, '[combat] show; hide')
    else holderRule(h, hud and '[combat] show; show' or '[combat] hide; show'); h:Show() end
    local okLevel, level = pcall(root.GetFrameLevel, root)
    level = (okLevel and number(level) or 1) + 30
    if C.level ~= level then h:SetFrameLevel(level); C.level = level end
    local cl, cb, cr, ct = rect(scroll, hidden)
    local shown = 0
    for _, row in ipairs(rows or {}) do
        if row.source ~= 'ghost' and row.unit then
            local b = button(row)
            local l, bottom, r, top
            if cl and (row.present or hud) then l, bottom, r, top = rect(row.healthBar, hidden) end
            -- Whole bar inside the visible part of the list, or no button.
            local inside = l and bottom >= cb - 1 and top <= ct + 1 and l >= cl - 1 and r <= cr + 1
            -- Moved only when its place changed (setters are not free).
            if inside and (b.l ~= l or b.b ~= bottom or b.r ~= r or b.t ~= top) then
                b:ClearAllPoints(); b:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', l, bottom)
                b:SetSize(r - l, top - bottom)
                b.l, b.b, b.r, b.t = l, bottom, r, top
                changed = true
            end
            drive(b, row.unit, inside and hud)
            local on = inside and row.present and true or false
            if b.on ~= on then changed = true end
            show(b, on)
            if on then shown = shown + 1 end
        end
    end
    C.shown, C.idle = shown, not changed
end
local ticker = CreateFrame('Frame')
ticker:RegisterEvent('PLAYER_REGEN_DISABLED')
-- Last placement before the lockdown starts: the layout is final for combat.
ticker:RegisterEvent('PLAYER_REGEN_ENABLED')
ticker:SetScript('OnEvent', function(_, event)
    if event == 'PLAYER_REGEN_ENABLED' then
        -- The state driver showed and hid buttons in combat: forget what we set.
        for _, b in pairs(C.buttons) do b.on = nil end
        C.dirty = true; return
    end
    pcall(C.Place)
end)
ticker:SetScript('OnUpdate', function()
    local wait = C.dirty and 0 or C.idle and IDLE or INTERVAL
    if GetTime() - C.placed >= wait then pcall(C.Place) end
end)
