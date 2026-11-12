-- Vendored from Warlock HUD 0.43.0 (Warlock_Hud_MultiTarget.lua), Apache License 2.0:
-- see MultiTarget/LICENSE. Modified for Warlock All-in-One, see MultiTarget/NOTICE.txt.
local _, S = ...
S.WH = S.WH or {}
local WH = S.WH
local presentation = WH.Presentation
-- Fixed nameplate and group-target display sources, with up to sixteen visible
-- rows. Aura slots are built only outside combat. The view is not clickable.
local api = WH.API
local rows = {}
local root
local windowBackground
local status
local damageDebug = true
local mover
local unlockOverlay
local scrollFrame, scrollContent, scrollBar
local liveContent, previewContent
local previewOn, previewRows = false, {}
local title, close, resize
local BuildRow, RefreshPreview, SetPreview
local layingOutLive=false
local visibilityDriver = false
local built, pending, auraWarning, failed = false, false, false, false
local buildCount = 0
local ROWS = 16
local SOURCE_UNITS = {}
for i = 1, ROWS do SOURCE_UNITS[#SOURCE_UNITS + 1] = "nameplate" .. i end
SOURCE_UNITS[#SOURCE_UNITS + 1] = "target"
local LIVE_UNITS = #SOURCE_UNITS
for i = 1, ROWS do SOURCE_UNITS[#SOURCE_UNITS + 1] = "ghost" .. i end
local ICON_SIZE = 24
local ROW_HEIGHT = 29
local PORTRAIT_SIZE = 26
local BASE_WIDTH, BASE_HEIGHT = 430, 548
local COUNTDOWN_FONT = "FelkitWHMultiDotCountdownFont"
local countdownFontReady = false
local SPELLS = api.Spells
local DOT_KEYS = {}
local DOT_SLOTS = 0
local SLOT_KEYS = api.MainKeys
local ICON_CROP = (1 - 1 / 1.3) / 2
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local function ClampScale(value)
    return math.max(0.7, math.min(1.6, tonumber(value) or 1))
end

local function ClampWidth(value)
    local minimum=presentation.MinimumWidth(presentation.current,DOT_SLOTS)
    return math.max(minimum, math.min(700, tonumber(value) or BASE_WIDTH))
end

local function ClampHeight(value)
    return math.max(150, math.min(800, tonumber(value) or BASE_HEIGHT))
end

local function Safe()
    return not InCombatLockdown() and not (C_Secrets
        and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
end

local function Plain(value)
    return (not issecretvalue or not issecretvalue(value)) and value ~= nil
end

local function Profile()
    if not api.GetProfile() then api.InitializeProfiles() end
    return api.GetProfile()
end

-- Visibility is independent of tracking: hiding outside combat must preserve
-- casts/ghosts. Explicitly disabling the module stops its event/timer work.
local function Enabled()
    local p=api.GetProfile()
    return api.IsAddonEnabled() and p and p.multiDotEnabled==true
end
local dirtyAll,dirtyUnits,dirtyElapsed=false,{},0
-- Only the enemy rows whose eligibility reads the group (threat, targets).
local dirtyMobs=false
-- Last applied settings (Refresh skips a rebuild when nothing changed).
local appliedSignature
local SyncEvents

local function ApplyAppearance()
    if not root then return false end
    local p = presentation.current
    if not p then return false end
    root:SetAlpha(1)
    if windowBackground then windowBackground:SetColorTexture(.025,.026,.035,presentation.BackgroundAlpha(p)) end
    -- Unlocked: shown out of combat as well, so it can be placed.
    local unlocked = p.locked == false
    local wantsDriver = not previewOn and not unlocked and p.multiDotEnabled and p.multiDotHideOutOfCombat
        and p.addonEnabled
    if wantsDriver ~= visibilityDriver then
        if Safe() then
            local ok
            if wantsDriver and RegisterStateDriver then
                ok = pcall(RegisterStateDriver, root, "visibility",
                    "[combat] show; hide")
            elseif not wantsDriver and UnregisterStateDriver then
                ok = pcall(UnregisterStateDriver, root, "visibility")
            end
            if ok then
                visibilityDriver = wantsDriver
                if not wantsDriver then root:SetAttribute("statehidden",nil) end
            else
                pending = true
                if WH.TraceHUD then
                    WH.TraceHUD("Multi-Target: combat visibility driver was blocked")
                end
            end
        else
            pending = true
        end
    end
    if visibilityDriver and wantsDriver then return true end
    local shown = p.multiDotEnabled and p.addonEnabled
        and (previewOn or unlocked or not p.multiDotHideOutOfCombat or InCombatLockdown())
    local ok = pcall(root.SetShown, root, shown)
    if not ok then pending = true end
    return ok
end

local function Position()
    if not root then return end
    local p = Profile()
    local width, height = root:GetSize()
    local ratio=root:GetEffectiveScale()/UIParent:GetEffectiveScale()
    root:ClearAllPoints()
    if type(p.multiDotX) == "number" and type(p.multiDotY) == "number" then
        root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            p.multiDotX * UIParent:GetWidth()/ratio - width / 2,
            p.multiDotY * UIParent:GetHeight()/ratio + height / 2)
    else
        root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            (UIParent:GetWidth() / 2 + 320)/ratio - width / 2,
            UIParent:GetHeight() / 2/ratio + height / 2)
    end
end
local function SavePosition()
    WH.Click.Touch()
    local x,y=root:GetCenter()
    if Plain(x) and Plain(y) then
        local p=Profile()
        local ratio=root:GetEffectiveScale()/UIParent:GetEffectiveScale()
        p.multiDotX=math.max(0,math.min(1,x*ratio/UIParent:GetWidth()))
        p.multiDotY=math.max(0,math.min(1,y*ratio/UIParent:GetHeight()))
    end
end

local lastSeen = {}
local damage
local identity = WH.MultiTargetIdentity.New(function() return rows end,
    SPELLS, ROWS, Plain, function(guid, name, row)
        lastSeen[guid] = { name = name, seen = GetTime(),
            health = row.snapshotHealth, maximum = row.snapshotMaximum,
            percent = row.snapshotPercent, portrait = row.snapshotPortrait }
    end, function(guid)
        return damage and damage.RemainingForGuid(guid) > 0
    end)
local ClearIdentity = identity.ClearIdentity
local GroupThreat = identity.GroupThreat
local TargetsGroup = identity.TargetsGroup
local TargetedByGroup = identity.TargetedByGroup
local UpdatePortrait = identity.UpdatePortrait
local MarkerProbeResult = identity.MarkerProbeResult
local ReadableGuid = identity.ReadableGuid
local RaidMarkerFor = identity.RaidMarkerFor
local UpdateIdentity = identity.UpdateIdentity
local NormalizeRows = identity.NormalizeRows
damage = WH.MultiTargetDamage.New(function() return rows end,
    ReadableGuid,Enabled)

local function UpdateGhostRows()
    local ghostRows, liveGuids, liveCount = {}, {}, 0
    local changed = false
    if not InCombatLockdown() then
        -- No estimates out of combat: only clear what is still shown.
        for _, row in ipairs(rows) do
            if row.source == "ghost" and row.present then
                changed = true
                row.ghostGuid, row.ghostEstimates, row.ghostKey = nil, nil, nil
                presentation.GhostIcons(row, nil)
                ClearIdentity(row)
            end
        end
        return changed
    end
    for _, row in ipairs(rows) do
        if row.source == "ghost" then
            ghostRows[#ghostRows + 1] = row
        elseif row.present then
            liveCount = liveCount + 1
            local guid = ReadableGuid(row.unit)
            if guid == "unavailable" and row.source == "nameplate" then
                guid = row.lastGuid
            end
            if guid then liveGuids[guid] = true end
        end
    end
    local candidates = {}
    if InCombatLockdown() then
        for guid, seen in pairs(lastSeen) do
            local remaining = damage.RemainingForGuid(guid)
            if remaining <= 0 and not liveGuids[guid] then
                lastSeen[guid] = nil
            elseif remaining > 0 and not liveGuids[guid] then
                candidates[#candidates + 1] = {
                    guid = guid, name = seen.name, seen = seen.seen,
                    remaining = remaining, health = seen.health,
                    maximum = seen.maximum, percent = seen.percent,
                    portrait = seen.portrait }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.seen == b.seen then return a.guid < b.guid end
        return a.seen > b.seen
    end)
    for i, row in ipairs(ghostRows) do
        local ghost = i <= ROWS - liveCount and candidates[i]
        if ghost then
            -- Name, health and portrait are the last-seen snapshot: set once per ghost.
            local fresh = row.ghostGuid ~= ghost.guid or not row.present
            if fresh then
                changed = true
                row.ghostGuid = ghost.guid
                row.present = true
                row.display:SetAlpha(0.55)
                row.name:SetText(ghost.name)
                row.name:SetTextColor(0.62, 0.62, 0.62); row.nameColored = nil
                local healthOK = ghost.maximum and ghost.health
                    and pcall(row.healthBar.SetMinMaxValues, row.healthBar,
                        0, ghost.maximum)
                healthOK = healthOK and pcall(row.healthBar.SetValue,
                    row.healthBar, ghost.health)
                if not healthOK then row.healthBar:SetValue(0) end
                row.healthBar:SetStatusBarColor(0.5, 0.5, 0.5, 0.8); row.colorKey = nil
                row.icons:SetAlpha(0.65); row.iconsAlpha = nil
                row.portrait:SetTexture(ghost.portrait
                    or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.portraitCover:SetAlpha(0)
                presentation.HealthAvailable(row,healthOK==true)
                presentation.HealthText(row, ghost.health, ghost.maximum, ghost.percent)
                row.ghostKey = nil
            end
            -- The icons follow the families that still have estimated damage.
            local estimates = damage.EstimatesForGuid(ghost.guid)
            local byKey = {
                corruption = estimates["Corruption"] or 0,
                bane = estimates["Bane of Agony"] or 0,
                siphonlife = estimates["Siphon Life"] or 0,
                immolate = estimates["Immolate"] or 0,
                curse = estimates["Curse of the Elements"] or 0,
            }
            row.ghostEstimates = byKey
            local key = (byKey.corruption > 0 and "c" or "") .. (byKey.bane > 0 and "b" or "")
                .. (byKey.siphonlife > 0 and "s" or "") .. (byKey.immolate > 0 and "i" or "")
                .. (byKey.curse > 0 and "e" or "")
            if row.ghostKey ~= key then presentation.GhostIcons(row, byKey); row.ghostKey = key end
        elseif row.present then
            changed = true
            row.ghostGuid = nil
            row.ghostKey = nil
            row.ghostEstimates = nil
            presentation.GhostIcons(row, nil)
            ClearIdentity(row)
        end
    end
    return changed
end

local statusText
local function UpdateStatus()
    if not status then return end
    local text
    if previewOn then text = S.L.mtPreviewStatus
    else
        local count = 0
        for _, row in ipairs(rows) do
            if row.present then count = count + 1 end
        end
        text = count == 0 and S.L.mtNone
            or string.format(count == 1 and S.L.mtCountOne or S.L.mtCount, count)
    end
    if text ~= statusText then status:SetText(text); statusText = text end
end

local CompactRows = WH.MultiTargetLayout.New(function() return previewOn and not layingOutLive and previewRows or rows end,
    function() return DOT_SLOTS end, ICON_SIZE,
    ROW_HEIGHT, Profile, function() return scrollFrame, scrollContent, scrollBar end,
    function() pending = true end)

-- 0.7.0: the header (title, count, X, grip) can be hidden; the rows then
-- start at the top. Without it the window cannot be dragged.
-- 0.7.5: moving and resizing only while unlocked; then a veil over the whole
-- window can be dragged, header or not.
local function ApplyHeader()
    local shown = presentation.current.header ~= false
    local unlocked = presentation.current.locked == false
    local inset = presentation.TopInset()
    title:SetAlpha(shown and 1 or 0); status:SetAlpha(shown and 1 or 0)
    close:SetAlpha(shown and 1 or 0); close:EnableMouse(shown)
    resize:SetAlpha(unlocked and 1 or 0); resize:EnableMouse(unlocked)
    mover:EnableMouse(shown and unlocked)
    if unlockOverlay then unlockOverlay:SetShown(unlocked) end
    scrollFrame:ClearAllPoints(); scrollFrame:SetPoint("TOPLEFT", root, "TOPLEFT", 7, -inset)
    scrollBar:ClearAllPoints(); scrollBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -1, -inset)
end

local function ApplyLayout(width, height)
    local view = height - presentation.TopInset() - 7
    root:SetSize(width, height)
    if mover then mover:SetWidth(width - 35) end
    ApplyHeader()
    scrollFrame:SetWidth(width - 27)
    scrollFrame:SetHeight(view)
    scrollContent:SetWidth(width - 27)
    scrollBar:SetHeight(view)
    if previewOn then
        layingOutLive=true; CompactRows(width,height); layingOutLive=false
    end
    CompactRows(width, height)
    WH.Click.Touch()
end

local function ReflowRows()
    WH.Click.Touch()
    local width, height = root:GetSize()
    -- Full geometry/font/style work belongs to Build/Refresh settings only.
    -- Existing rows already have their dimensions; membership only moves them.
    CompactRows(width, height, true)
end

local function FlushIdentity()
    if not dirtyAll and not dirtyMobs and not next(dirtyUnits) then return end
    identity.BeginUpdate()
    for _,row in ipairs(rows) do
        if dirtyAll or dirtyUnits[row.unit]
            or (dirtyMobs and (row.source=="nameplate" or row.source=="target")) then UpdateIdentity(row) end
    end
    dirtyAll,dirtyMobs,dirtyUnits=false,false,{}
    NormalizeRows(); UpdateGhostRows(); UpdateStatus(); ReflowRows(); damage.Update()
end

local function RefreshSourceAuras(unit)
    for _, row in ipairs(rows) do
        if row.unit == unit and row.auras and row.auras.UpdateAllAuras then
            pcall(row.auras.UpdateAllAuras, row.auras)
            presentation.RefreshAuras(row)
            break
        end
    end
end

-- 0.7.0: one native group per renderer, sorted by expiry and filtered by the
-- enabled families (Presentation.lua). Built once, out of combat; a preference
-- change reconfigures it and never rebuilds identity or retention.
local function EnsureRowEffects(row)
    -- The applied view (the HUD fallback while building): bars come from Prepare.
    if row.source~='ghost' and not row.preview then presentation.EnsureGroups(row,presentation.current) end
end

BuildRow = function(i,unit,parent,width,size,synthetic)
        -- Rows may hang from a native group (0.7.1 chain): layout template.
        local display = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
        display:SetSize(width - (DOT_SLOTS * (size + 3) + 38), size + 5)
        display:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0,
            -(i - 1) * ROW_HEIGHT)
        local background = display:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(display)
        background:SetColorTexture(0.055, 0.055, 0.065, 0.9)
        local portrait = display:CreateTexture(nil, "ARTWORK")
        portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
        portrait:SetPoint("LEFT", display, "LEFT", 8, 0)
        local portraitWarning = display:CreateTexture(nil, "OVERLAY")
        portraitWarning:SetAllPoints(portrait)
        portraitWarning:SetVertexColor(1, 0.06, 0.06, 1)
        portraitWarning:SetAlpha(0)
        -- The native fill hides the warning while health exceeds the plain
        -- damage estimate. No Lua comparison or position read is involved.
        local portraitCover = CreateFrame("StatusBar", nil, display)
        portraitCover:SetAllPoints(portrait)
        portraitCover:SetFrameLevel(display:GetFrameLevel() + 1)
        portraitCover:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        portraitCover:SetMinMaxValues(0, 1)
        portraitCover:SetValue(1)
        local marker = portraitCover:CreateTexture(nil, "OVERLAY")
        marker:SetSize(16, 16)
        marker:SetPoint("TOPRIGHT", portrait, "TOPRIGHT", 2, 2)
        marker:SetTexture(RAID_ICONS)
        marker:Hide()
        local healthBar = CreateFrame("StatusBar", nil, display)
        healthBar:SetPoint("BOTTOMLEFT", display, "BOTTOMLEFT", 44, 3)
        healthBar:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", 7, 3)
        healthBar:SetHeight(11)
        healthBar:SetFrameLevel(display:GetFrameLevel())
        healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        healthBar:SetStatusBarColor(0.5, 0.15, 0.17, 0.9)
        local healthTrack = healthBar:CreateTexture(nil, "BACKGROUND")
        healthTrack:SetAllPoints(healthBar)
        healthTrack:SetColorTexture(0.025, 0.025, 0.03, 0.95)
        local executeLayer = CreateFrame("Frame", nil, display)
        executeLayer:SetAllPoints(healthBar)
        executeLayer:SetFrameLevel(healthBar:GetFrameLevel() + 5)
        local executeOutline = executeLayer:CreateTexture(nil, "OVERLAY", nil, -2)
        executeOutline:SetSize(4, 15)
        executeOutline:SetColorTexture(0, 0, 0, 1)
        local executeLine = executeLayer:CreateTexture(nil, "OVERLAY", nil, -1)
        executeLine:SetSize(2, 15)
        executeLine:SetColorTexture(0.78, 0.43, 0.20, 1)
        healthBar:SetMinMaxValues(0, 1)
        healthBar:SetValue(0)
        local healthText = executeLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        healthText:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 13)
        healthText:SetSize(128, 12)
        healthText:SetJustifyH("RIGHT")
        healthText:SetTextColor(0.96, 0.96, 0.94)
        healthText:SetShadowColor(0, 0, 0, 1)
        healthText:SetShadowOffset(1, -1)
        healthText:SetText("")
        local function DamageSegment(level, red, green, blue, previous)
            local bar = CreateFrame("StatusBar", nil, display)
            if previous then
                bar:SetPoint("TOPLEFT", previous:GetStatusBarTexture(),
                    "TOPRIGHT", 0, 0)
            else
                bar:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
            end
            bar:SetWidth(width - (DOT_SLOTS * (size + 3) + 75))
            bar:SetHeight(4)
            bar:SetFrameLevel(healthBar:GetFrameLevel() + level)
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetStatusBarColor(red, green, blue, 0.95)
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            return bar
        end
        local damageMarker = DamageSegment(4, 1, 0.66, 0.2)
        local baneMarker = DamageSegment(3, 0.7, 0.38, 0.9, damageMarker)
        local siphonMarker = DamageSegment(2, 0.24, 0.75, 0.68, baneMarker)
        local immolateMarker = DamageSegment(1, 1, 0.29, 0.13, siphonMarker)
        -- Anchor these ticks once, while the row is built safely. The native
        -- status bars move their fill textures as health and estimates change;
        -- Lua never reads back their protected widths or positions.
        local healthEdge = executeLayer:CreateTexture(nil, "OVERLAY", nil, 1)
        healthEdge:SetSize(2, 11)
        healthEdge:SetPoint("CENTER", healthBar:GetStatusBarTexture(), "RIGHT", 0, 0)
        healthEdge:SetColorTexture(1, 1, 1, 1)
        local damageEdge = executeLayer:CreateTexture(nil, "OVERLAY", nil, 2)
        damageEdge:SetSize(3, 8)
        damageEdge:SetPoint("CENTER", immolateMarker:GetStatusBarTexture(),
            "RIGHT", 0, 0)
        damageEdge:SetColorTexture(1, 0.93, 0.28, 1)
        damageEdge:SetAlpha(0)
        local name = executeLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", display, "TOPLEFT", 45, -2)
        name:SetWidth(math.max(42, width - (DOT_SLOTS * (size + 3) + 206)))
        name:SetJustifyH("LEFT")
        name:SetTextColor(0.96, 0.96, 0.94)
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        if name.SetWordWrap then name:SetWordWrap(false) end
        local iconHolder = CreateFrame("Frame", nil, display)
        iconHolder:SetAllPoints(display)
        local selection = display:CreateTexture(nil, "OVERLAY")
        selection:SetSize(4, size + 5)
        selection:SetPoint("LEFT", display, "LEFT", 0, 0)
        selection:SetColorTexture(0.86, 0.66, 0.25, 0)
        local source = synthetic and "preview" or (i > LIVE_UNITS and "ghost" or (i <= ROWS and "nameplate" or "target"))
        local auras
        if source == "ghost" or synthetic then
            auras = CreateFrame("Frame", nil, iconHolder)
        else
            auras = CreateFrame("AuraContainer", nil, iconHolder,
                "CustomAuraContainerTemplate")
        end
        auras:SetSize(math.max(1, DOT_SLOTS * (size + 3)), size)
        auras:SetPoint("LEFT", display, "RIGHT", 14, 0)
        local row = { unit = unit, source = source, preview=synthetic,
            display = display, background = background, icons = iconHolder, name = name,
            healthBar = healthBar, healthText = healthText, healthTrack=healthTrack,
            damageMarker = damageMarker, baneMarker = baneMarker,
            siphonMarker = siphonMarker, immolateMarker = immolateMarker,
            healthEdge = healthEdge, damageEdge = damageEdge,
            executeOutline = executeOutline, executeLine = executeLine,
            portrait = portrait, portraitWarning = portraitWarning,
            portraitCover = portraitCover, marker = marker,
            target = selection, auras = auras,
            dotVisuals = {}, presentationSpells = {} }
        return row
end

local function Build()
    if built or not Safe() then pending = true; return false end
    local p = Profile()
    if not p or not api.IsAddonEnabled() then return false end
    DOT_KEYS = api.GetMultiTargetEffectOrder()
    DOT_SLOTS = #DOT_KEYS
    if not C_AddOns or not C_AddOns.LoadAddOn then return false end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local loaded = C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        if not loaded then return false end
    end
    if CreateFont and not countdownFontReady then
        local font = CreateFont(COUNTDOWN_FONT)
        if font then
            font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            font:SetShadowColor(0, 0, 0, 1)
            font:SetShadowOffset(1, -1)
            countdownFontReady = true
        end
    end

    -- A first-load bar API failure must keep a usable icon window. Do not
    -- discard the root and allocate another set of native containers on retry.
    local fallback=presentation.Settings(); fallback.dots='hud'
    presentation.Prepare({},fallback)

    local size = ICON_SIZE
    local width = ClampWidth(p.multiDotWidth)
    local height = ClampHeight(p.multiDotHeight)
    buildCount = buildCount + 1
    local function FrameName(name)
        return buildCount == 1 and name or nil
    end
    root = CreateFrame("Frame", FrameName("FelkitWHMultiTargetWindow"), UIParent)
    root:SetSize(width, height)
    root:SetScale(ClampScale(p.multiDotScale))
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    -- Built-in visibility is resolved natively by SecureStateDriver. A custom
    -- secure snippet cannot Show/Hide this ordinary frame handle in combat.
    Position()
    windowBackground = root:CreateTexture(nil, "BACKGROUND")
    windowBackground:SetAllPoints(root)
    root.background=windowBackground
    title = root:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 9, -8)
    title:SetText(S.L.mtTitle)
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    status = root:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -30)
    status:SetText(S.L.mtNone)
    status:SetShadowColor(0, 0, 0, 1)
    status:SetShadowOffset(1, -1)
    mover = CreateFrame("Button", FrameName("FelkitWHMultiTargetMove"), root)
    mover:SetSize(width - 35, 28)
    mover:SetPoint("TOPLEFT", root, "TOPLEFT")
    mover:SetFrameLevel(root:GetFrameLevel() + 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function()
        if Safe() then root:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        root:StopMovingOrSizing()
        if not Safe() then return end
        SavePosition(); Position()
    end)
    unlockOverlay = CreateFrame("Button", nil, root)
    unlockOverlay:SetAllPoints(root)
    unlockOverlay:SetFrameLevel(root:GetFrameLevel() + 40)
    unlockOverlay:EnableMouse(true)
    unlockOverlay:RegisterForDrag("LeftButton")
    local veil = unlockOverlay:CreateTexture(nil, "BACKGROUND")
    veil:SetAllPoints(); veil:SetColorTexture(.45, .22, .75, .28)
    local hint = unlockOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("LEFT", 20, 0); hint:SetPoint("RIGHT", -20, 0); hint:SetText(S.L.mtMoveHint)
    unlockOverlay:SetScript("OnDragStart", function()
        if Safe() then root:StartMoving() end
    end)
    unlockOverlay:SetScript("OnDragStop", function()
        root:StopMovingOrSizing()
        if not Safe() then return end
        SavePosition(); Position()
    end)
    unlockOverlay:Hide()
    close = CreateFrame("Button", FrameName("FelkitWHMultiTargetClose"), root)
    close:SetSize(27, 27)
    close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -3, -2)
    close:SetFrameLevel(root:GetFrameLevel() + 5)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeText:SetAllPoints(close)
    closeText:SetText("X")
    close:SetScript("OnClick", function()
        if not Safe() then return end
        if previewOn then SetPreview(false); return end
        Profile().multiDotEnabled = false
        WH.refresh()
    end)
    resize = CreateFrame("Button", FrameName("FelkitWHMultiTargetResize"), root)
    resize:SetSize(19, 19)
    resize:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -2, 2)
    resize:SetFrameLevel(root:GetFrameLevel() + 45) -- above the unlock veil
    resize:EnableMouse(true)
    resize:RegisterForDrag("LeftButton")
    local grip = resize:CreateTexture(nil, "ARTWORK")
    grip:SetAllPoints(resize)
    grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    local resizing, startX, startY, startWidth, startHeight = false
    resize:SetScript("OnDragStart", function()
        if not Safe() then return end
        resizing = true
        startX, startY = GetCursorPosition()
        startWidth, startHeight = root:GetSize()
    end)
    local lastResize = 0
    resize:SetScript("OnUpdate", function()
        if not resizing then return end
        local now = GetTime()
        if now - lastResize < 0.05 then return end
        lastResize = now
        if not Safe() then resizing = false; pending=true; presentation.pending=true; return end
        local x, y = GetCursorPosition()
        if not Plain(x) or not Plain(y) then return end
        local scale = root:GetEffectiveScale()
        local newWidth = ClampWidth(startWidth + (x - startX) / scale)
        local newHeight = ClampHeight(startHeight - (y - startY) / scale)
        local currentWidth, currentHeight = root:GetSize()
        if newWidth == currentWidth and newHeight == currentHeight then return end
        local applied = pcall(ApplyLayout, newWidth, newHeight)
        if not applied then
            pending = true
            resizing = false
            return
        end
        local current = Profile()
        current.multiDotWidth, current.multiDotHeight = math.min(700,newWidth), newHeight
        SavePosition()
    end)
    resize:SetScript("OnDragStop", function()
        -- The last movement before release is applied even inside the 50 ms throttle.
        lastResize = 0
        local update = resize:GetScript("OnUpdate")
        if update then update(resize) end
        resizing = false
    end)
    scrollFrame = CreateFrame("ScrollFrame", FrameName("FelkitWHMultiTargetScroll"), root)
    scrollFrame:SetPoint("TOPLEFT", root, "TOPLEFT", 7, -50)
    scrollFrame:SetSize(width - 27, height - 57)
    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(width - 27, ROWS * ROW_HEIGHT)
    scrollFrame:SetScrollChild(scrollContent)
    liveContent=CreateFrame("Frame",nil,scrollContent); liveContent:SetAllPoints(scrollContent)
    previewContent=CreateFrame("Frame",nil,scrollContent); previewContent:SetAllPoints(scrollContent); previewContent:SetAlpha(0)
    scrollFrame:EnableMouseWheel(true)
    scrollBar = CreateFrame("Slider", FrameName("FelkitWHMultiTargetScrollBar"), root,
        "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -1, -50)
    scrollBar:SetHeight(height - 57)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(ROW_HEIGHT)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        WH.Click.Touch()
        local ok = pcall(scrollFrame.SetVerticalScroll, scrollFrame, value)
        if not ok then pending = true end
    end)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        -- Click zones are placed before combat: the list holds still with them.
        if InCombatLockdown() and presentation.current.clickTarget then return end
        scrollBar:SetValue(scrollBar:GetValue() - delta * ROW_HEIGHT)
    end)
    scrollBar:Hide()
    for i, unit in ipairs(SOURCE_UNITS) do
        local row = BuildRow(i,unit,liveContent,width,size,false)
        rows[i] = row
        local auras,source=row.auras,row.source
        EnsureRowEffects(row)
        if source ~= "ghost" then
            auras:SetUnit(unit)
            auras:Show()
            auras:UpdateAllAuras()
        else
            auras:Hide()
        end
        ClearIdentity(row)
        UpdateIdentity(row)
    end
    NormalizeRows()
    UpdateGhostRows()
    local prepared=presentation.Prepare(rows)
    UpdateStatus()
    width=ClampWidth(p.multiDotWidth)
    ApplyLayout(width, height)
    damage.SetDebugEnabled(damageDebug)
    built, pending = true, not prepared
    ApplyAppearance()
    return prepared
end

RefreshPreview = function()
    if #previewRows==0 then
        for i=1,3 do
            local row=BuildRow(i,nil,previewContent,root:GetWidth(),ICON_SIZE,true)
            row.present=true; row.display:SetAlpha(1); row.previewIndex=i
            row.presentationSpells={}
            for _,key in ipairs(SLOT_KEYS) do
                local chosen
                for _,spell in ipairs(SPELLS) do
                    if spell.group~=2 and SLOT_KEYS[spell.slot]==key then
                        chosen=chosen or spell
                        if api.knownSpell(spell) then chosen=spell; break end
                    end
                end
                if chosen then row.presentationSpells[#row.presentationSpells+1]=chosen end
            end
            row.healthBar:SetMinMaxValues(0,1000); row.healthBar:SetValue(({820,460,150})[i])
            row.portrait:SetTexture((({"Interface\\Icons\\Ability_Hunter_Pet_Wolf","Interface\\Icons\\Ability_Hunter_Pet_Bear","Interface\\Icons\\Ability_Hunter_Pet_Boar"}))[i])
            row.portraitCover:SetAlpha(0)
            previewRows[i]=row
        end
    end
    presentation.Prepare(previewRows,presentation.current)
    for i,row in ipairs(previewRows) do
        row.name:SetText(string.format(S.L.mtPreviewEnemy,i))
        presentation.Selection(row,i==1)
        presentation.HealthText(row,({820,460,150})[i],1000,({82,46,15})[i])
    end
end
SetPreview = function(on)
    on=on==true
    if on==previewOn then return true end
    if on and (not Safe() or not api.IsAddonEnabled() or not Profile().multiDotEnabled) then return false end
    if on and not built then return false end
    previewOn=on
    liveContent:SetAlpha(on and 0 or 1); previewContent:SetAlpha(on and 1 or 0)
    if on then RefreshPreview() end
    if Safe() then
        local p=Profile(); ApplyLayout(ClampWidth(p.multiDotWidth),ClampHeight(p.multiDotHeight))
    else pending=true end
    scrollBar:SetValue(0)
    UpdateStatus(); ApplyAppearance()
    if S.Options and S.Options.refresh then S.Options.refresh() end
    return true
end

-- Every saved setting of the window, the spell order and the states a refresh
-- depends on, as one string.
local function Flat(value, out)
    if type(value) ~= "table" then out[#out + 1] = tostring(value); return end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        out[#out + 1] = tostring(k)
        Flat(value[k], out)
    end
end
local function Signature(p)
    local out = {}
    Flat(p, out)
    Flat(api.GetMultiTargetEffectOrder(), out)
    out[#out + 1] = tostring(previewOn); out[#out + 1] = tostring(Enabled())
    out[#out + 1] = tostring(api.IsAddonEnabled()); out[#out + 1] = tostring(S.db and S.db.language)
    return table.concat(out, "\31")
end

local function Refresh()
    local p = Profile()
    if not p then return false end
    -- Unit events follow the on/off state at once (allowed in combat), even
    -- when the rest of the refresh has to wait.
    if SyncEvents then SyncEvents() end
    if previewOn and (not api.IsAddonEnabled() or not p.multiDotEnabled) then SetPreview(false) end
    if not Safe() then pending = true; presentation.pending = true; return false end
    if not built then return Build() end
    local signature = Signature(p)
    if signature == appliedSignature and not pending and not presentation.pending then
        ApplyAppearance()
        return true
    end
    local previousKeys,previousSlots=DOT_KEYS,DOT_SLOTS
    DOT_KEYS=api.GetMultiTargetEffectOrder(); DOT_SLOTS=#DOT_KEYS
    for _,row in ipairs(rows) do EnsureRowEffects(row) end
    if not presentation.Prepare(rows) then DOT_KEYS,DOT_SLOTS=previousKeys,previousSlots; return false end
    root:SetScale(ClampScale(p.multiDotScale))
    local width = ClampWidth(p.multiDotWidth)
    local height = ClampHeight(p.multiDotHeight)
    if previewOn then RefreshPreview() end
    ApplyLayout(width, height)
    Position()
    ApplyAppearance()
    if not Enabled() then
        lastSeen={}; dirtyAll,dirtyUnits=false,{}
        damage.Reset()
        for _,row in ipairs(rows) do ClearIdentity(row) end
    else
        -- Reactivation cannot reuse identities/estimates from a disabled gap.
        dirtyAll=true; FlushIdentity()
    end
    for _,row in ipairs(rows) do
        if row.source~='ghost' then presentation.Enable(row,Enabled()==true) end
    end
    UpdateGhostRows()
    UpdateStatus()
    pending = false
    appliedSignature = signature
    if SyncEvents then SyncEvents() end
    return true
end

local function GuardedRefresh()
    if failed then return false end
    local ok, result = pcall(Refresh)
    if ok then
        if S.Options and S.Options.pages and S.Options.pages.enemies and S.Options.syncMultiTarget then
            S.Options.syncMultiTarget(S.Options.pages.enemies)
        end
        return result
    end
    failed = true
    if root and not InCombatLockdown() then root:Hide() end
    S.API.chat(S.L.mtInitFailed .. " " .. tostring(result))
    return false
end

-- Live markers are not drawn while the window is hidden (they redraw within 0.1 s).
presentation.SetRowSource(function()
    return (not root or root:IsShown()) and rows or nil, previewOn and previewRows or nil
end)
WH.Click.SetSource(function()
    local p = api.GetProfile()
    -- No target buttons while the window is unlocked: the veil takes the drags.
    return rows, scrollFrame, root, built and not failed and Enabled() and not previewOn
        and presentation.current.clickTarget == true and presentation.current.locked ~= false,
        p and p.multiDotHideOutOfCombat == true
end)

local probe = WH.MultiTargetProbe.New(function() return rows end, ROWS,
    Plain, GroupThreat, TargetsGroup, TargetedByGroup)

WH.MultiTarget = {
    Refresh = GuardedRefresh,
    SetPreview = function(on) if on and not built then GuardedRefresh() end; return SetPreview(on) end,
    PreviewActive = function() return previewOn end,
    State = function() return built, failed end,
    UpdateAppearance = ApplyAppearance,
    Toggle = function()
        if InCombatLockdown() then return false end
        local p = Profile()
        if not p then return false end
        p.multiDotEnabled = not p.multiDotEnabled
        return GuardedRefresh()
    end,
    ProbeRunning = probe.IsRunning,
    Probe = probe.Command,
    DamageDebugRunning = function() return damageDebug end,
    DamageSnapshot = function()
        if WH.OpenDebugTrace then WH.OpenDebugTrace() end
        if WH.TraceHUD then
            WH.TraceHUD("Multi-Target ratios: "
                .. damage.DebugSnapshot())
        end
    end,
    ToggleDamageDebug = function()
        damageDebug = not damageDebug
        if damageDebug and not built then GuardedRefresh() end
        damage.SetDebugEnabled(damageDebug)
        if damageDebug then
            WH.MultiTarget.DamageSnapshot()
        end
        S.API.chat("Multi-Target ratio debug "
            .. (damageDebug and "on" or "off") .. ".")
    end,
    PrintTargets = function()
        if WH.OpenDebugTrace then WH.OpenDebugTrace() end
        if not WH.TraceHUD then return end
        local targetOK, targetExists = pcall(UnitExists, "target")
        if targetOK and Plain(targetExists) and targetExists then
            local nameOK, targetName = pcall(UnitName, "target")
            WH.TraceHUD("Multi-Target target: "
                .. (nameOK and Plain(targetName) and type(targetName) == "string"
                    and targetName or "name unavailable")
                .. "; GUID=" .. ReadableGuid("target")
                .. "; marker=" .. MarkerProbeResult("target"))
        end
        local count = 0
        for _, row in ipairs(rows) do
            if row.present then
                local ok, name = pcall(UnitName, row.unit)
                if not ok or not Plain(name) or type(name) ~= "string" then
                    name = "name unavailable"
                end
                local index, source = RaidMarkerFor(row.unit)
                WH.TraceHUD("Multi-Target: " .. row.unit .. " = " .. name
                    .. "; GUID=" .. ReadableGuid(row.unit)
                    .. "; direct marker=" .. MarkerProbeResult(row.unit)
                    .. "; raid marker=" .. (index and tostring(index) or "none/read restricted")
                    .. "; render=" .. tostring(row.markerMode)
                    .. (source and (" via " .. source) or ""))
                count = count + 1
            end
        end
        if count == 0 then
            WH.TraceHUD("Multi-Target: no visible rows")
        end
    end,
    Debug = function()
        local output = WH.TraceHUD
        if not output then return end
        output("Multi-Target: " .. (built and "built" or "not built")
            .. "; read-only; combat: " .. tostring(InCombatLockdown()))
        for _, row in ipairs(rows) do
            if row.present then
                local ok, name = pcall(UnitName, row.unit)
                if not ok or not Plain(name) or type(name) ~= "string" then
                    name = "name unavailable"
                end
                output(row.unit .. " = " .. name
                    .. "; relevant=" .. tostring(row.relevant))
            end
        end
    end,
}

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
    "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_PORTRAIT_UPDATE", "PORTRAITS_UPDATED",
    "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
    "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS",
    "UNIT_TARGET" }) do
    events:RegisterEvent(event)
end
local UNIT_EVENTS = { "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE",
    "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS", "UNIT_TARGET",
    "UNIT_PORTRAIT_UPDATE" }
local unitEventsOn = true
SyncEvents = function()
    local on = Enabled() == true
    if on == unitEventsOn then return end
    for _, event in ipairs(UNIT_EVENTS) do
        if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
    unitEventsOn = on
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" then
        if pending or event ~= "PLAYER_REGEN_ENABLED" then GuardedRefresh() end
    end
    if not built then return end
    if not Enabled() then return end
    if event == "PLAYER_REGEN_DISABLED" then
        if previewOn then SetPreview(false) end
        ApplyAppearance()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        lastSeen = {}
        ApplyAppearance()
        identity.ClearMarkers()
        identity.BeginUpdate()
        for _, row in ipairs(rows) do UpdateIdentity(row) end
        NormalizeRows()
        UpdateGhostRows()
        UpdateStatus()
        ReflowRows()
        damage.Update()
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "PORTRAITS_UPDATED" then
        if event == "PORTRAITS_UPDATED" then
            for _, row in ipairs(rows) do UpdatePortrait(row) end
        elseif Plain(unit) and type(unit) == "string" then
            for _, row in ipairs(rows) do
                if row.unit == unit then UpdatePortrait(row); break end
            end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" or event == "NAME_PLATE_UNIT_ADDED" then
        if not Plain(unit) then return end
        identity.BeginUpdate()
        for _, row in ipairs(rows) do
            if row.unit == unit then
                -- A newly assigned token may refer to a different mob.
                ClearIdentity(row)
                damage.Clear(row)
                if event == "NAME_PLATE_UNIT_ADDED" then UpdateIdentity(row) end
                -- The token may now denote another creature. Ask Blizzard's
                -- container to discard any aura display from its old occupant.
                if row.auras and row.auras.UpdateAllAuras then
                    local refreshed = pcall(row.auras.UpdateAllAuras, row.auras)
                    if not refreshed and not auraWarning then
                        auraWarning = true
                        S.API.chat(S.L.mtAuraBlocked)
                    end
                    presentation.RefreshAuras(row)
                end
                break
            end
        end
        NormalizeRows()
        UpdateGhostRows()
        UpdateStatus()
        ReflowRows()
        damage.Update()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "RAID_TARGET_UPDATE"
        or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_AURA"
        or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
        or event == "UNIT_FLAGS" or event == "UNIT_TARGET" then
        if (event == "UNIT_AURA" or event == "UNIT_HEALTH"
            or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS"
            or event == "UNIT_TARGET")
            and (not Plain(unit) or type(unit) ~= "string"
            or (event ~= "UNIT_TARGET" and not unit:match("^nameplate%d+$")
                and unit ~= "target"))
            then return end
        if event=='UNIT_TARGET' and unit~='player' and unit~='pet' and unit~='target'
            and not unit:match('^raid%d+$') and not unit:match('^party%d+$')
            and not unit:match('^nameplate%d+$') then return end
        if event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH" then
            for _,row in ipairs(rows) do
                if row.unit==unit and row.present then
                    local ok,dead=false,false
                    if UnitIsDeadOrGhost then ok,dead=pcall(UnitIsDeadOrGhost,unit) end
                    if ok and Plain(dead) and dead then
                        UpdateIdentity(row); NormalizeRows(); UpdateGhostRows(); UpdateStatus(); ReflowRows(); damage.Update()
                    else identity.RefreshHealth(row) end
                    break
                end
            end
            return
        end
        if event == "PLAYER_TARGET_CHANGED" then
            RefreshSourceAuras("target")
        end
        local token = Plain(unit) and type(unit) == "string" and unit or nil
        if event == "UNIT_TARGET" and token then
            if token:match("^nameplate%d+$") or token == "target" then
                -- The enemy's own target: only its row.
                dirtyUnits[token] = true
            elseif token:match("^raid%d+$") or token:match("^party%d+$") then
                -- A member's target: the enemy rows that read who the group targets.
                dirtyMobs = true
            else
                dirtyAll = true
            end
        elseif (event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE")
            and token and not token:match("^nameplate%d+$") then
            -- Threat between the group and enemies: the enemy rows only.
            dirtyMobs = true
        elseif token and event ~= "PLAYER_TARGET_CHANGED" and event ~= "RAID_TARGET_UPDATE"
            and event ~= "GROUP_ROSTER_UPDATE" then
            dirtyUnits[token] = true
        else
            if event == "RAID_TARGET_UPDATE" or event == "GROUP_ROSTER_UPDATE" then identity.ClearMarkers() end
            identity.BeginUpdate()
            dirtyAll = true
        end
    end
end)
local ghostElapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    if not built then return end
    if not Enabled() then return end
    dirtyElapsed=dirtyElapsed+delta
    if dirtyElapsed>=.1 then dirtyElapsed=0; FlushIdentity() end
    if previewOn then
        if not Safe() then SetPreview(false)
        else presentation.AnimatePreview(previewRows,GetTime()) end
    end
    ghostElapsed=ghostElapsed+delta
    if ghostElapsed<.2 then return end
    ghostElapsed=0
    if (pending or presentation.pending) and not presentation.error and Safe() then
        GuardedRefresh()
        if S.Options and S.Options.frame and S.Options.frame:IsShown() then S.Options.refresh() end
    end
    if UpdateGhostRows() then
        UpdateStatus()
        ReflowRows()
    end
end)
