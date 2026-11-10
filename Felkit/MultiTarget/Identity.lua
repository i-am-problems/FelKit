-- Vendored from Warlock HUD 0.43.0 (Warlock_Hud_MultiTargetIdentity.lua), Apache License 2.0:
-- see MultiTarget/LICENSE. Modified for Warlock All-in-One, see MultiTarget/NOTICE.txt.
local _, S = ...
S.WH = S.WH or {}
local WH = S.WH
-- Unit identity and row presentation for the Multi-Target tracker.
-- Native aura containers remain owned by Warlock_Hud_MultiTarget.lua.
WH.MultiTargetIdentity = {}

function WH.MultiTargetIdentity.FormatNumber(value)
    if issecretvalue and issecretvalue(value) then
        if AbbreviateNumbers then
            local ok, abbreviated = pcall(AbbreviateNumbers, value)
            if ok then return abbreviated end
        end
        return nil
    end
    if type(value) ~= "number" then return nil end
    if value >= 1000000000 then return string.format("%.2fB", value / 1000000000) end
    if value >= 1000000 then return string.format("%.2fM", value / 1000000) end
    if value >= 1000 then return string.format("%.2fk", value / 1000) end
    return string.format("%.0f", value)
end

function WH.MultiTargetIdentity.New(getRows, spells, rowLimit, plain,
    rememberSeen, hasTrackedDamage)
    local SPELLS, ROWS, Plain = spells, rowLimit, plain
    -- Kept between passes: markers only change with the events that clear it.
    local markerCache={}
    -- Per pass: the group's existing members and their public GUIDs (one read
    -- per member instead of one per member and per enemy row).
    local group
    -- Per frame: a token's GUID is read once (events that move tokens forget it).
    local guidMemo,guidFrame={},nil
    local healthColorCurve
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor
        and Enum and Enum.LuaCurveType then
        local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
        if ok and curve then
            curve:SetType(Enum.LuaCurveType.Linear)
            curve:AddPoint(0, CreateColor(0.88, 0.12, 0.12, 0.9))
            curve:AddPoint(0.5, CreateColor(0.95, 0.72, 0.16, 0.9))
            curve:AddPoint(1, CreateColor(0.2, 0.72, 0.3, 0.9))
            healthColorCurve = curve
        end
    end

    local function ClearIdentity(row)
        if row.present==false and row.eligible==false and row.lastGuid==nil then return end
        row.present = false
        row.eligible = false
        row.relevant = false
        row.lastGuid = nil
        row.snapshotHealth = nil
        row.snapshotMaximum = nil
        row.snapshotPercent = nil
        row.snapshotPortrait = nil
        -- Alpha also hides native aura children without changing protected
        -- visibility or anchors during combat.
        row.display:SetAlpha(0)
        row.name:SetText(""); row.nameText = nil
        if row.healthBar then
            pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, 1)
            pcall(row.healthBar.SetValue, row.healthBar, 0)
        end
        if row.healthText then row.healthText:SetText("") end
        row.name:SetTextColor(0.94, 0.94, 0.92); row.nameColored = nil
        row.portrait:SetTexture(nil)
        row.portraitReady = false
        if row.portraitWarning then row.portraitWarning:SetTexture(nil) end
        row.portraitWarningReady = false
        row.portraitCoverReady = false
        if row.portraitWarning then row.portraitWarning:SetAlpha(0) end
        row.marker:Hide()
        row.markerMode = "none"
        WH.Presentation.Selection(row,false)
    end

    local function UpdateHealth(row, name, healthOnly)
        if not healthOnly then
            -- A hidden name is passed on as is; a readable one is set only when it changes.
            if not Plain(name) then row.name:SetText(name); row.nameText = nil
            elseif row.nameText ~= name then row.name:SetText(name); row.nameText = name end
        end
        if not UnitHealth or not UnitHealthMax or not UnitHealthPercent
            or not CurveConstants or not CurveConstants.ScaleTo100 then
            WH.Presentation.HealthAvailable(row, false)
            row.healthText:SetText(WH.Presentation.current.enemy == 'aio' and '?' or '')
            return
        end
        local healthOK, health = pcall(UnitHealth, row.unit, true)
        local maxOK, maximum = pcall(UnitHealthMax, row.unit)
        local percentOK, percent = pcall(UnitHealthPercent, row.unit, true,
            CurveConstants.ScaleTo100)
        if not healthOK or not maxOK or not percentOK then
            WH.Presentation.HealthAvailable(row, false)
            row.healthText:SetText(WH.Presentation.current.enemy == 'aio' and '?' or '')
            return
        end
        local function Numeric(value)
            return (issecretvalue and issecretvalue(value))
                or type(value) == "number"
        end
        if not Numeric(health) or not Numeric(maximum) or not Numeric(percent) then
            WH.Presentation.HealthAvailable(row, false)
            row.healthText:SetText(WH.Presentation.current.enemy == 'aio' and '?' or '')
            return
        end
        row.snapshotHealth = health
        row.snapshotMaximum = maximum
        row.snapshotPercent = percent
        -- These values may be secret. Native widgets accept them directly; Lua
        -- never compares, divides, concatenates, or formats them.
        pcall(row.healthBar.SetMinMaxValues, row.healthBar, 0, maximum)
        pcall(row.healthBar.SetValue, row.healthBar, health)
        WH.Presentation.HealthAvailable(row, true)
        if WH.Presentation.HealthText(row, health, maximum, percent) then
            if not healthOnly then WH.Presentation.HealthColor(row) end
            return
        end
        if healthColorCurve then
            local colorOK, color = pcall(UnitHealthPercent, row.unit, true,
                healthColorCurve)
            if colorOK and color then
                pcall(function()
                    row.healthBar:SetStatusBarColor(color:GetRGBA())
                end)
            end
        elseif not (issecretvalue and issecretvalue(percent)) then
            local fraction = math.max(0, math.min(1, percent / 100))
            row.healthBar:SetStatusBarColor(1 - 0.8 * fraction,
                0.12 + 0.6 * fraction, 0.12 + 0.18 * fraction, 0.9)
        end
        local healthLabel = WH.MultiTargetIdentity.FormatNumber(health)
        local formatted
        if healthLabel then
            formatted = pcall(row.healthText.SetFormattedText,
                row.healthText, "%s %.0f%%", healthLabel, percent)
        else
            formatted = pcall(row.healthText.SetFormattedText,
                row.healthText, "%.0f %.0f%%", health, percent)
        end
        if not formatted then row.healthText:SetText("") end
    end

    local function ReadableGuid(unit)
        if not UnitGUID then return "unavailable" end
        local now = GetTime and GetTime()
        if guidFrame ~= now then guidMemo, guidFrame = {}, now end
        local saved = guidMemo[unit]
        if saved then return saved end
        local ok, guid = pcall(UnitGUID, unit)
        saved = ok and Plain(guid) and type(guid) == "string"
            and guid or "unavailable"
        guidMemo[unit] = saved
        return saved
    end

    -- Per pass: whether a group token exists, asked once (true, false or nil
    -- when the answer is hidden).
    local function Exists(token)
        local known = group.exists[token]
        if known ~= nil then return known ~= "unknown" and known or nil end
        local existsOK, exists = pcall(UnitExists, token)
        if not existsOK or not Plain(exists) then group.exists[token] = "unknown"; return nil end
        group.exists[token] = exists and true or false
        return group.exists[token]
    end

    local function Group()
        if group then return group end
        local members, candidates = { "player", "pet" }, { "pettarget" }
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do
                members[#members + 1] = "raid" .. i
                members[#members + 1] = "raidpet" .. i
                candidates[#candidates + 1] = "raid" .. i .. "target"
            end
        elseif IsInGroup and IsInGroup() then
            for i = 1, 4 do
                members[#members + 1] = "party" .. i
                members[#members + 1] = "partypet" .. i
                candidates[#candidates + 1] = "party" .. i .. "target"
            end
        end
        group = { exists = {}, tokens = { members = members, candidates = candidates }, lists = {} }
        return group
    end

    -- Existing tokens of a group list, split by whether their GUID is public:
    -- built the first time a row needs it in this pass.
    local function Snapshot(name)
        local g = Group()
        if g.lists[name] then return g.lists[name] end
        local list = { all = {}, guids = {}, hidden = {} }
        for _, token in ipairs(g.tokens[name]) do
            if Exists(token) then
                list.all[#list.all + 1] = token
                local guid = ReadableGuid(token)
                if guid ~= "unavailable" then list.guids[guid] = true
                else list.hidden[#list.hidden + 1] = token end
            end
        end
        g.lists[name] = list
        return list
    end

    local function GroupThreat(unit)
        if not UnitThreatSituation then return nil end
        local unknown = false
        for _, member in ipairs(Group().tokens.members) do
            local exists = Exists(member)
            if exists == nil then
                unknown = true
            elseif exists then
                local threatOK, status = pcall(UnitThreatSituation, member, unit)
                if not threatOK or (issecretvalue and issecretvalue(status)) then
                    unknown = true
                elseif type(status) == "number" then
                    return true
                end
            end
        end
        return unknown and nil or false
    end

    -- Is `unit` one of the group list's tokens? Public GUIDs answer at once;
    -- UnitIsUnit is asked only for the tokens a GUID cannot settle.
    local function Among(unit, name)
        local list = Snapshot(name)
        local guid = ReadableGuid(unit)
        local ask = list.all
        if guid ~= "unavailable" then
            if list.guids[guid] then return true end
            ask = list.hidden
        end
        for _, other in ipairs(ask) do
            local sameOK, same = pcall(UnitIsUnit, unit, other)
            if sameOK and Plain(same) and same then return true end
        end
        return false
    end

    local function TargetsGroup(unit)
        if not UnitIsUnit or not UnitExists then return false end
        local target = unit .. "target"
        local targetOK, exists = pcall(UnitExists, target)
        if not targetOK or not Plain(exists) or not exists then return false end
        return Among(target, "members")
    end

    local function TargetedByGroup(unit)
        if not UnitIsUnit then return false end
        return Among(unit, "candidates")
    end

    local function OwnDot(unit)
        -- Native slots render combat auras. Lua only checks presence while the
        -- aura APIs are unrestricted, never their protected duration fields.
        if InCombatLockdown() or not C_UnitAuras
            or not C_UnitAuras.GetAuraDataBySpellID
            or (C_Secrets and C_Secrets.ShouldAurasBeSecret
                and C_Secrets.ShouldAurasBeSecret()) then return nil end
        for _, spell in ipairs(SPELLS) do
            if spell.group ~= 2 then for _, id in ipairs(spell.ids) do
                local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellID,
                    unit, id, "HARMFUL|PLAYER")
                if not ok or (issecretvalue and issecretvalue(aura)) then return nil end
                if aura then return true end
            end end
        end
        return false
    end

    local function UpdatePortrait(row)
        if row.present and SetPortraitTexture then
            row.portraitReady = pcall(SetPortraitTexture, row.portrait, row.unit)
            if row.portraitReady and row.portrait.GetTexture then
                local ok, texture = pcall(row.portrait.GetTexture, row.portrait)
                if ok and Plain(texture)
                    and (type(texture) == "string" or type(texture) == "number") then
                    row.snapshotPortrait = texture
                end
            end
            if WH.Presentation.current.enemy == 'aio' then return end
            if row.portraitWarning then
                row.portraitWarningReady = pcall(SetPortraitTexture,
                    row.portraitWarning, row.unit)
            end
            if row.portraitCover then
                row.portraitCoverReady = pcall(SetPortraitTexture,
                    row.portraitCover:GetStatusBarTexture(), row.unit)
            end
        end
    end

    local function ReadRaidMarker(unit)
        if not GetRaidTargetIndex then return nil end
        local ok, index = pcall(GetRaidTargetIndex, unit)
        if ok and Plain(index) and type(index) == "number"
            and index >= 1 and index <= 8 then return index end
    end

    local function ReadGuidRaidMarker(unit)
        if not UnitGUID then return nil end
        local ok, guid = pcall(UnitGUID, unit)
        if not ok or not Plain(guid) or type(guid) ~= "string" then return nil end
        return ReadRaidMarker(guid)
    end

    local function MarkerProbeResult(unit)
        if not GetRaidTargetIndex then return "API unavailable" end
        local ok, index = pcall(GetRaidTargetIndex, unit)
        if not ok then return "error" end
        if issecretvalue and issecretvalue(index) then return "restricted" end
        if index == nil then return "nil" end
        return tostring(index)
    end

    local function ReadMarkerFor(unit)
        local index = ReadRaidMarker(unit)
        if index then return index, unit end
        index = ReadGuidRaidMarker(unit)
        if index then return index, unit .. " GUID" end
        local alternatives = { "target", "focus", "pettarget" }
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do alternatives[#alternatives + 1] = "raid" .. i .. "target" end
        elseif IsInGroup and IsInGroup() then
            for i = 1, 4 do alternatives[#alternatives + 1] = "party" .. i .. "target" end
        end
        for _, other in ipairs(alternatives) do
            local sameOK, same = pcall(UnitIsUnit, unit, other)
            if sameOK and Plain(same) and same then
                index = ReadRaidMarker(other)
                if index then return index, other end
                index = ReadGuidRaidMarker(other)
                if index then return index, other .. " GUID" end
            end
        end
    end

    local function RaidMarkerFor(unit)
        local guid=ReadableGuid(unit)
        local saved=guid~='unavailable' and markerCache[guid]
        if saved then return saved.index,saved.source end
        local index,source=ReadMarkerFor(unit)
        -- "None" is kept only when the direct read was readable (a real absence,
        -- which only RAID_TARGET_UPDATE changes); a restricted read is asked again.
        local known=index~=nil
        if not known and GetRaidTargetIndex then
            local ok,direct=pcall(GetRaidTargetIndex,unit)
            known=ok and not (issecretvalue and issecretvalue(direct))
        end
        if guid~='unavailable' and known then markerCache[guid]={index=index,source=source} end
        return index,source
    end

    local function UpdateIdentity(row)
        if row.source == "ghost" then return end
        local unit = row.unit
        local source = row.source
        if source == "party" and (not IsInGroup or not IsInGroup()
            or (IsInRaid and IsInRaid())) then ClearIdentity(row); return end
        if source == "raid" and (not IsInRaid or not IsInRaid()) then
            ClearIdentity(row); return
        end
        local existsOK, exists = pcall(UnitExists, unit)
        if not existsOK or not Plain(exists) or not exists then
            ClearIdentity(row)
            return
        end
        if UnitIsDeadOrGhost then
            local deadOK, dead = pcall(UnitIsDeadOrGhost, unit)
            if deadOK and Plain(dead) and dead then
                ClearIdentity(row)
                return
            end
        end
        if source ~= "nameplate" then
            local attackOK, attackable = pcall(UnitCanAttack, "player", unit)
            if not attackOK or not Plain(attackable) or not attackable then
                ClearIdentity(row); return
            end
        end
        if source == "nameplate" or source == "target" then
            local threat = GroupThreat(unit)
            local dot
            if threat~=true then dot=OwnDot(unit) end
            local targetingGroup = threat~=true and dot~=true and TargetsGroup(unit)
            local groupTarget = threat~=true and dot~=true and not targetingGroup and TargetedByGroup(unit)
            local tracked = false
            if source == "target" and hasTrackedDamage and threat~=true and dot~=true
                and not targetingGroup and not groupTarget then
                local guid = ReadableGuid(unit)
                tracked = guid ~= "unavailable" and hasTrackedDamage(guid)
            end
            -- A row confirmed before combat stays visible while DoT evidence is
            -- restricted. New rows still need confirmation, and safe reads recheck it.
            local retainConfirmed = row.eligible and InCombatLockdown() and dot == nil
            if threat ~= true and dot ~= true and not targetingGroup
                and not groupTarget and not tracked
                and not retainConfirmed then
                ClearIdentity(row)
                return
            end
        end
        row.present = true
        row.eligible = true
        row.relevant = true
        row.display:SetAlpha(1)
        if not row.nameColored then row.name:SetTextColor(0.96, 0.96, 0.94); row.nameColored = true end
        if not row.portraitReady then UpdatePortrait(row) end
        local ok, name = pcall(UnitName, unit)
        if ok then
            UpdateHealth(row, name)
            if rememberSeen and Plain(name) and type(name) == "string" then
                local guid = ReadableGuid(unit)
                if guid ~= "unavailable" then
                    row.lastGuid = guid
                    rememberSeen(guid, name, row)
                end
            end
        end
        local index = RaidMarkerFor(unit)
        if index then
            if row.markerMode ~= "readable" or row.markerIndex ~= index then
                local column = (index - 1) % 4
                local line = math.floor((index - 1) / 4)
                row.marker:SetTexCoord(column * 0.25, (column + 1) * 0.25,
                    line * 0.25, (line + 1) * 0.25)
                row.marker:Show()
                row.markerMode, row.markerIndex = "readable", index
            end
        else
            -- Blizzard's untainted renderer may accept a restricted marker index
            -- even though addon Lua cannot compare or calculate with it.
            local markerOK, restrictedIndex = pcall(GetRaidTargetIndex, unit)
            local rendered = false
            if markerOK and issecretvalue and issecretvalue(restrictedIndex)
                and SetRaidTargetIconTexture then
                rendered = pcall(SetRaidTargetIconTexture, row.marker, restrictedIndex)
            end
            if rendered then
                row.marker:Show()
                row.markerMode = "native"
            elseif row.markerMode ~= "none" then
                row.marker:Hide()
                row.markerMode = "none"
            end
        end
        local targetOK, selected = pcall(UnitIsUnit, unit, "target")
        -- In combat the game may answer with a hidden boolean: readable GUIDs
        -- decide when both are public, else the yellow target line takes the
        -- hidden value natively, without any comparison.
        if targetOK and selected ~= nil and not Plain(selected) then
            local mine, theirs = ReadableGuid(unit), ReadableGuid("target")
            if mine ~= "unavailable" and theirs ~= "unavailable" then selected = mine == theirs end
        end
        if not (targetOK and selected ~= nil and not Plain(selected)
            and WH.Presentation.SecretSelection(row, selected)) then
            WH.Presentation.Selection(row,targetOK and Plain(selected) and selected == true)
        end
        -- Match the HUD's full/half icon alpha for an attackable target while
        -- leaving row text and health legible. The parent also carries native aura
        -- buttons, so Blizzard continues to control their visibility and timers.
        local iconsAlpha = (row.relevant == true
            or (targetOK and Plain(selected) and selected == true)) and 1 or 0.5
        if row.iconsAlpha ~= iconsAlpha then row.icons:SetAlpha(iconsAlpha); row.iconsAlpha = iconsAlpha end
    end

    local function NormalizeRows()
        local seen, accepted, count = {}, {}, 0
        for _, row in ipairs(getRows()) do
            if row.eligible then
                local guid = ReadableGuid(row.unit)
                local duplicate = guid ~= "unavailable" and seen[guid]
                if not duplicate and UnitIsUnit then
                    for _, prior in ipairs(accepted) do
                        -- Distinct public GUIDs already prove distinct units.
                        local ok, same = false,false
                        if guid=='unavailable' or prior.guid=='unavailable' then
                            ok,same=pcall(UnitIsUnit, row.unit, prior.unit)
                        end
                        if ok and Plain(same) and same then
                            duplicate = true
                            break
                        end
                    end
                end
                if duplicate or count >= ROWS then
                    row.present = false
                    row.display:SetAlpha(0)
                else
                    row.present = true
                    row.display:SetAlpha(1)
                    if guid ~= "unavailable" then seen[guid] = true end
                    accepted[#accepted + 1] = {unit=row.unit,guid=guid}
                    count = count + 1
                end
            end
        end
    end
    return {
        BeginUpdate = function() group = nil; guidMemo, guidFrame = {}, GetTime and GetTime() end,
        ClearMarkers = function() markerCache = {} end,
        ClearIdentity = ClearIdentity,
        GroupThreat = GroupThreat,
        TargetsGroup = TargetsGroup,
        TargetedByGroup = TargetedByGroup,
        UpdatePortrait = UpdatePortrait,
        MarkerProbeResult = MarkerProbeResult,
        ReadableGuid = ReadableGuid,
        RaidMarkerFor = RaidMarkerFor,
        UpdateIdentity = UpdateIdentity,
        RefreshHealth = function(row) UpdateHealth(row, nil, true) end,
        NormalizeRows = NormalizeRows,
    }
end
