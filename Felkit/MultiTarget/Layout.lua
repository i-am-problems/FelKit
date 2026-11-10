-- Vendored from Warlock HUD 0.43.0 (Warlock_Hud_MultiTargetLayout.lua), Apache License 2.0:
-- see MultiTarget/LICENSE. Modified for Warlock All-in-One, see MultiTarget/NOTICE.txt.
local _, S = ...
S.WH = S.WH or {}
local WH = S.WH
-- Multi-Target row compaction and scroll range.
WH.MultiTargetLayout = {}

function WH.MultiTargetLayout.New(getRows, dotSlots, iconSize, rowHeight,
    profile, getScrollFrames, markPending)
    local ICON_SIZE, ROW_HEIGHT = iconSize, rowHeight
    local Profile = profile

    local function UpdateScrollRange(height, contentHeight)
        local scrollFrame, _, scrollBar = getScrollFrames()
        local viewportHeight = height - WH.Presentation.TopInset() - 7
        local maxScroll = math.max(0, contentHeight - viewportHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollBar:SetShown(maxScroll > 0)
        if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
        if maxScroll == 0 then scrollFrame:SetVerticalScroll(0) end
    end

    local function CompactRows(width, height, positionsOnly)
        local _, scrollContent = getScrollFrames()
        local panelWidth=width-38
        local displayWidth = panelWidth-WH.Presentation.IconsWidth(WH.Presentation.current,dotSlots())
        local healthWidth = displayWidth - 37
        local present, contentHeight, maximumStep = 0, 0, ROW_HEIGHT
        for _, row in ipairs(getRows()) do
            maximumStep = math.max(maximumStep, WH.Presentation.Step(row))
            if row.present then present = present + 1; contentHeight = contentHeight + WH.Presentation.Step(row) end
        end
        local activeY, emptyY = 0, contentHeight
        local activePosition, emptyPosition = 0, present
        local P = WH.Presentation
        -- 0.7.1: with click targeting, HUD rows keep their places in combat
        -- (the secure click zones cannot move there); changes wait for its end.
        local frozen = positionsOnly and InCombatLockdown() and P.Frozen()
        if not positionsOnly then for _, row in ipairs(getRows()) do P.EnsureTail(row) end end
        local previousTail
        for _, row in ipairs(getRows()) do
            local position
            if row.present then
                activePosition = activePosition + 1
                position = activePosition
            else
                emptyPosition = emptyPosition + 1
                position = emptyPosition
            end
            local step = P.Step(row)
            local y = row.present and -activeY or -emptyY
            if row.present then activeY = activeY + step else emptyY = emptyY + step end
            -- Equal-width rows hang from the previous present row's tail, so
            -- their height follows the DoTs the game shows (nothing measured).
            local relative, relativePoint = scrollContent, "TOPLEFT"
            if P.Chained(row) then
                if not row.present then y = -20000
                elseif previousTail then
                    relative, relativePoint, y = previousTail, "BOTTOMLEFT", -P.current.spacing
                else y = 0 end
                if row.present then previousTail = row.tail end
            end
            if not positionsOnly then row.display:SetWidth(displayWidth) end
            if row.position ~= position or row.step ~= step or row.layoutY ~= y
                or row.layoutRelative ~= relative then
                if frozen then
                    markPending()
                elseif positionsOnly then
                    -- These display frames are created outside combat. Move only
                    -- an unprotected existing parent; never rebuild native auras.
                    local checked, protected = pcall(row.display.IsProtected, row.display)
                    if not checked or (issecretvalue and issecretvalue(protected))
                        or protected then
                        markPending()
                    else
                        local moved = pcall(row.display.SetPoint, row.display,
                            "TOPLEFT", relative, relativePoint, 0, y)
                        if moved then row.position, row.step, row.layoutY, row.layoutRelative = position, step, y, relative
                        else markPending() end
                    end
                else
                    row.display:ClearAllPoints()
                    row.display:SetPoint("TOPLEFT", relative, relativePoint, 0, y)
                    row.position, row.step, row.layoutY, row.layoutRelative = position, step, y, relative
                end
            end
            if not positionsOnly then
                row.name:SetWidth(math.max(42, displayWidth - 168))
                healthWidth = WH.Presentation.Row(row, displayWidth, ICON_SIZE,panelWidth)
                for _, segment in ipairs({ row.damageMarker, row.baneMarker,
                    row.siphonMarker, row.immolateMarker }) do
                    segment:SetWidth(healthWidth)
                end
                for _, tick in ipairs({ row.executeOutline, row.executeLine }) do
                    tick:ClearAllPoints()
                    tick:SetPoint("CENTER", row.healthBar, "LEFT", healthWidth * 0.2, 0)
                    tick:SetHeight(WH.Presentation.current.healthHeight+4)
                end
            end
        end
        -- Pre-size for the engine's sixteen-row capacity. More targets can
        -- appear in combat without resizing an ancestor of native aura slots.
        if not positionsOnly then scrollContent:SetHeight(math.max(height - WH.Presentation.TopInset() - 7,16*maximumStep)) end
        UpdateScrollRange(height, contentHeight)
    end
    return CompactRows
end
