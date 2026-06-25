-- FrameUnlocker Anchors
-- Draggable anchor system for repositionable frames:
-- loot rolls, arena/flag carriers, quest tracker, raid warnings

local addonName, FU = ...

-- "BackdropTemplate" only exists as a registered template on Retail (post-Shadowlands).
-- Classic Era frames have SetBackdrop natively, so we pass nil and rely on the
-- if anchor.SetBackdrop guard below instead of the mixin.
local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

---------------------------------------------------------------------
-- Shared draggable anchor factory
---------------------------------------------------------------------

-- opts fields: name, width, height, point, relPoint, x, y,
--   bgColor {r,g,b,a}, borderColor {r,g,b,a}, label,
--   btnWidth, btnHeight, btnInset, btnY, onLock, onDragStop
local function CreatePositionAnchor(opts)
    local anchor = CreateFrame("Frame", opts.name, UIParent, backdropTemplate)
    anchor:SetSize(opts.width, opts.height)
    anchor:SetPoint(opts.point, UIParent, opts.relPoint, opts.x, opts.y)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:Hide()

    if anchor.SetBackdrop then
        anchor:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        local bg = opts.bgColor
        local br = opts.borderColor
        anchor:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        anchor:SetBackdropBorderColor(br[1], br[2], br[3], br[4])
    end

    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", 0, -8)
    label:SetText(opts.label)

    local btnW  = opts.btnWidth  or 80
    local btnH  = opts.btnHeight or 22
    local inset = opts.btnInset  or 12
    local btnY  = opts.btnY      or 6

    local scaleBtn = CreateFrame("Button", nil, anchor, "UIPanelButtonTemplate")
    scaleBtn:SetSize(btnW, btnH)
    scaleBtn:SetPoint("BOTTOMLEFT", inset, btnY)
    scaleBtn:SetText("Scale")
    scaleBtn:SetScript("OnClick", function() FU:OpenOptions() end)

    local lockBtn = CreateFrame("Button", nil, anchor, "UIPanelButtonTemplate")
    lockBtn:SetSize(btnW, btnH)
    lockBtn:SetPoint("BOTTOMRIGHT", -inset, btnY)
    lockBtn:SetText("Lock")
    lockBtn:SetScript("OnClick", opts.onLock)

    anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        opts.onDragStop(self)
    end)

    return anchor
end

---------------------------------------------------------------------
-- Per-anchor position save helpers (shared by OnDragStop and Hide)
---------------------------------------------------------------------

local function saveLootPosition(anchor)
    local x, y = anchor:GetCenter()
    if not x then return end
    local uiX, uiY = UIParent:GetCenter()
    FU:Set("lootFrameX", x - uiX)
    FU:Set("lootFrameY", y - uiY)
    FU:ApplyLootFramePosition()
end

local function saveArenaPosition(anchor)
    local right = anchor:GetRight()
    local top   = anchor:GetTop()
    if not right then return end
    FU:Set("arenaFrameX", right - UIParent:GetWidth())
    FU:Set("arenaFrameY", top   - UIParent:GetHeight())
    FU:ApplyArenaFramePosition()
end

local function saveQuestTrackerPosition(anchor)
    local right = anchor:GetRight()
    local top   = anchor:GetTop()
    if not right then return end
    FU:Set("questTrackerX", right - UIParent:GetWidth())
    FU:Set("questTrackerY", top   - UIParent:GetHeight())
    FU:ApplyQuestTrackerPosition()
end

local function saveRaidWarningPosition(anchor)
    local x   = anchor:GetCenter()
    local top = anchor:GetTop()
    if not x then return end
    local uiX = UIParent:GetCenter()
    FU:Set("raidWarningX", x   - uiX)
    FU:Set("raidWarningY", top - UIParent:GetTop())
    FU:ApplyRaidWarningPosition()
end

---------------------------------------------------------------------
-- Loot Roll Frame Anchor and Scaling
---------------------------------------------------------------------

function FU:CreateLootAnchor()
    if self.lootAnchor then return self.lootAnchor end
    self.lootAnchor = CreatePositionAnchor({
        name        = "FULootAnchor",
        width       = 220, height = 60,
        point       = "CENTER", relPoint = "CENTER", x = 0, y = 0,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Loot Roll Anchor",
        onLock = function()
            FU:HideLootAnchor()
            if FU.optionsPanel and FU.optionsPanel.lootAnchorButton then
                FU.optionsPanel.lootAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveLootPosition,
    })
    return self.lootAnchor
end

function FU:ShowLootAnchor()
    local anchor = self:CreateLootAnchor()
    local x = self:Get("lootFrameX")
    local y = self:Get("lootFrameY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
    else
        -- Default to where GroupLootContainer usually is
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
    end
    -- Size to one loot roll item; GroupLootFrame1 may not exist until a roll is active
    local ref = GroupLootFrame1
    local w = (ref and ref:GetWidth()  > 0) and ref:GetWidth()  or 300
    local h = (ref and ref:GetHeight() > 0) and ref:GetHeight() or 60
    anchor:SetSize(math.max(w, 180), math.max(h, 52))
    anchor:Show()
    self:Print("Drag the anchor to reposition loot roll frames. Click 'Lock' when done.")
end

function FU:HideLootAnchor()
    if self.lootAnchor then
        saveLootPosition(self.lootAnchor)
        self.lootAnchor:Hide()
        self:Print("Loot roll frame position saved.")
    end
end

function FU:ToggleLootAnchor()
    if self.lootAnchor and self.lootAnchor:IsShown() then
        self:HideLootAnchor()
        return false
    else
        self:ShowLootAnchor()
        return true
    end
end

function FU:ApplyLootFramePosition()
    if not self:Get("scaleLootFrames") then return end

    local x = self:Get("lootFrameX")
    local y = self:Get("lootFrameY")
    if not x or x == false or not y or y == false then return end

    if GroupLootContainer then
        -- Flag prevents the SetPoint hook below from re-triggering us
        self.lootFrameRepositioning = true
        GroupLootContainer:ClearAllPoints()
        GroupLootContainer:SetPoint("CENTER", UIParent, "CENTER", x, y)
        self.lootFrameRepositioning = false
    end
end

local function ResetLootContainerToDefault()
    if GroupLootContainer then
        GroupLootContainer:ClearAllPoints()
        if GroupLootContainer.Layout then
            GroupLootContainer:Layout()
        end
    end
end

function FU:ResetLootFrameToDefault()
    ResetLootContainerToDefault()
end

function FU:ResetLootFramePosition()
    self:Set("lootFrameX", false)
    self:Set("lootFrameY", false)
    self:Set("lootFrameScale", 1.0)

    if self.lootAnchor and self.lootAnchor:IsShown() then
        self.lootAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.lootAnchorButton then
            self.optionsPanel.lootAnchorButton:SetText("Move")
        end
    end

    self:ApplyLootFrameScale(1.0)
    ResetLootContainerToDefault()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Loot frame reset to default.")
end

function FU:ApplyLootFrameScale(scale)
    scale = scale or self:Get("lootFrameScale") or 1.0

    if GroupLootContainer then
        GroupLootContainer:SetScale(scale)
    end

    -- Fallback: scale individual frames if container doesn't exist
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame then frame:SetScale(scale) end
    end
end

function FU:HookLootFramePosition()
    if GroupLootContainer and not self.lootFrameHooked then
        local pendingReposition = false
        hooksecurefunc(GroupLootContainer, "SetPoint", function()
            if FU.lootFrameRepositioning then return end
            if not FU:Get("scaleLootFrames") then return end
            local x = FU:Get("lootFrameX")
            local y = FU:Get("lootFrameY")
            if x and x ~= false and y and y ~= false then
                if pendingReposition then return end
                pendingReposition = true
                C_Timer.After(0.1, function()
                    pendingReposition = false
                    FU:ApplyLootFramePosition()
                end)
            end
        end)
        self.lootFrameHooked = true
    end
end

---------------------------------------------------------------------
-- Arena / Flag Carrier Frame Anchor and Scaling
---------------------------------------------------------------------

function FU:CreateArenaAnchor()
    if self.arenaAnchor then return self.arenaAnchor end
    self.arenaAnchor = CreatePositionAnchor({
        name        = "FUArenaAnchor",
        width       = 180, height = 50,
        point       = "TOPRIGHT", relPoint = "TOPRIGHT", x = -100, y = -200,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Arena/Flag Carrier Anchor",
        btnWidth = 70, btnHeight = 20, btnInset = 8, btnY = 6,
        onLock = function()
            FU:HideArenaAnchor()
            if FU.optionsPanel and FU.optionsPanel.arenaAnchorButton then
                FU.optionsPanel.arenaAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveArenaPosition,
    })
    return self.arenaAnchor
end

function FU:ShowArenaAnchor()
    local anchor = self:CreateArenaAnchor()
    local x = self:Get("arenaFrameX")
    local y = self:Get("arenaFrameY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    else
        -- Default to right side where arena frames usually appear
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -200)
    end
    -- Size to 3 stacked enemy frames; individual frames may not exist outside arena
    local ref = _G["ArenaEnemyFrame1"]
    local frameW = (ref and ref:GetWidth()  > 0) and ref:GetWidth()  or 235
    local frameH = (ref and ref:GetHeight() > 0) and ref:GetHeight() or 18
    anchor:SetSize(math.max(frameW, 180), math.max(frameH * 3 + 4, 52))
    anchor:Show()
    self:Print("Drag the anchor to reposition arena/flag carrier frames. Click 'Lock' when done.")
end

function FU:HideArenaAnchor()
    if self.arenaAnchor then
        saveArenaPosition(self.arenaAnchor)
        self.arenaAnchor:Hide()
        self:Print("Arena/flag carrier frame position saved.")
    end
end

function FU:ToggleArenaAnchor()
    if self.arenaAnchor and self.arenaAnchor:IsShown() then
        self:HideArenaAnchor()
        return false
    else
        self:ShowArenaAnchor()
        return true
    end
end

function FU:ApplyArenaFramePosition()
    if not self:Get("scaleArenaFrames") then return end

    local x = self:Get("arenaFrameX")
    local y = self:Get("arenaFrameY")
    if not x or x == false or not y or y == false then return end

    if ArenaEnemyFrames then
        self.arenaFrameRepositioning = true
        ArenaEnemyFrames:ClearAllPoints()
        ArenaEnemyFrames:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
        self.arenaFrameRepositioning = false
    end
end

local function ResetArenaContainerToDefault()
    if ArenaEnemyFrames then
        ArenaEnemyFrames:ClearAllPoints()
        ArenaEnemyFrames:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -200)
    end
end

function FU:ResetArenaFrameToDefault()
    ResetArenaContainerToDefault()
end

function FU:ResetArenaFramePosition()
    self:Set("arenaFrameX", false)
    self:Set("arenaFrameY", false)
    self:Set("arenaFrameScale", 1.0)

    if self.arenaAnchor and self.arenaAnchor:IsShown() then
        self.arenaAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.arenaAnchorButton then
            self.optionsPanel.arenaAnchorButton:SetText("Move")
        end
    end

    self:ApplyArenaFrameScale(1.0)
    ResetArenaContainerToDefault()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Arena/flag carrier frame reset to default.")
end

function FU:ApplyArenaFrameScale(scale)
    scale = scale or self:Get("arenaFrameScale") or 1.0

    if ArenaEnemyFrames then
        ArenaEnemyFrames:SetScale(scale)
    end

    -- Fallback: scale individual frames if container doesn't exist
    for i = 1, 5 do
        local frame = _G["ArenaEnemyFrame" .. i]
        if frame then frame:SetScale(scale) end
    end
end

function FU:HookArenaFramePosition()
    if ArenaEnemyFrames and not self.arenaFrameHooked then
        local pendingReposition = false
        hooksecurefunc(ArenaEnemyFrames, "SetPoint", function()
            if FU.arenaFrameRepositioning then return end
            if not FU:Get("scaleArenaFrames") then return end
            local x = FU:Get("arenaFrameX")
            local y = FU:Get("arenaFrameY")
            if x and x ~= false and y and y ~= false then
                if pendingReposition then return end
                pendingReposition = true
                C_Timer.After(0.1, function()
                    pendingReposition = false
                    FU:ApplyArenaFramePosition()
                end)
            end
        end)
        self.arenaFrameHooked = true
    end
end

---------------------------------------------------------------------
-- Quest Tracker Anchor and Scaling
---------------------------------------------------------------------

-- Get the quest tracker frame (different names across client versions)
local function GetQuestTrackerFrame()
    return ObjectiveTrackerFrame or QuestWatchFrame
end

function FU:CreateQuestTrackerAnchor()
    if self.questTrackerAnchor then return self.questTrackerAnchor end
    self.questTrackerAnchor = CreatePositionAnchor({
        name        = "FUQuestTrackerAnchor",
        width       = 220, height = 60,
        point       = "TOPRIGHT", relPoint = "TOPRIGHT", x = -50, y = -200,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Quest Tracker Anchor",
        onLock = function()
            FU:HideQuestTrackerAnchor()
            if FU.optionsPanel and FU.optionsPanel.questTrackerAnchorButton then
                FU.optionsPanel.questTrackerAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveQuestTrackerPosition,
    })
    return self.questTrackerAnchor
end

function FU:ShowQuestTrackerAnchor()
    local anchor = self:CreateQuestTrackerAnchor()
    local x = self:Get("questTrackerX")
    local y = self:Get("questTrackerY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    else
        -- Default position
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -200)
    end
    -- Read live tracker dimensions; guard > 10 filters frames not yet laid out
    local tracker = GetQuestTrackerFrame()
    local w = (tracker and tracker:GetWidth()  > 10) and tracker:GetWidth()  or 240
    local h = (tracker and tracker:GetHeight() > 10) and tracker:GetHeight() or 150
    anchor:SetSize(math.max(w, 180), math.max(h, 52))
    anchor:Show()
    self:Print("Drag the anchor to reposition quest tracker. Click 'Lock' when done.")
end

function FU:HideQuestTrackerAnchor()
    if self.questTrackerAnchor then
        saveQuestTrackerPosition(self.questTrackerAnchor)
        self.questTrackerAnchor:Hide()
        self:Print("Quest tracker position saved.")
    end
end

function FU:ToggleQuestTrackerAnchor()
    if self.questTrackerAnchor and self.questTrackerAnchor:IsShown() then
        self:HideQuestTrackerAnchor()
        return false
    else
        self:ShowQuestTrackerAnchor()
        return true
    end
end

function FU:ApplyQuestTrackerPosition()
    if not self:Get("scaleQuestTracker") then return end

    local x = self:Get("questTrackerX")
    local y = self:Get("questTrackerY")
    if not x or x == false or not y or y == false then return end

    local tracker = GetQuestTrackerFrame()
    if tracker then
        self.questTrackerRepositioning = true

        -- Removed from Blizzard's managed layout system to prevent flickering
        -- when the tracker is repositioned; restored to defaults on reset.
        tracker.isManagedFrame = false
        tracker.isRightManagedFrame = false

        if tracker:GetParent() ~= UIParent then
            tracker:SetParent(UIParent)
        end

        tracker:ClearAllPoints()
        tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
        self.questTrackerRepositioning = false
    end
end

local function ResetQuestTrackerInternal()
    local tracker = GetQuestTrackerFrame()
    if tracker then
        tracker.isManagedFrame = true
        tracker.isRightManagedFrame = true

        if UIParentRightManagedFrameContainer then
            tracker:SetParent(UIParentRightManagedFrameContainer)
        end

        tracker:ClearAllPoints()
        tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -200)
    end
end

function FU:ResetQuestTrackerToDefault()
    ResetQuestTrackerInternal()
end

function FU:ResetQuestTrackerPosition()
    self:Set("questTrackerX", false)
    self:Set("questTrackerY", false)
    self:Set("questTrackerScale", 1.0)

    if self.questTrackerAnchor and self.questTrackerAnchor:IsShown() then
        self.questTrackerAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.questTrackerAnchorButton then
            self.optionsPanel.questTrackerAnchorButton:SetText("Move")
        end
    end

    self:ApplyQuestTrackerScale(1.0)
    ResetQuestTrackerInternal()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Quest tracker reset to default.")
end

function FU:ApplyQuestTrackerScale(scale)
    scale = scale or self:Get("questTrackerScale") or 1.0
    local tracker = GetQuestTrackerFrame()
    if tracker then
        tracker:SetScale(scale)
    end
end

function FU:HookQuestTrackerPosition()
    local tracker = GetQuestTrackerFrame()
    if tracker and not self.questTrackerHooked then
        local pendingReposition = false
        hooksecurefunc(tracker, "SetPoint", function()
            if FU.questTrackerRepositioning then return end
            if not FU:Get("scaleQuestTracker") then return end
            local x = FU:Get("questTrackerX")
            local y = FU:Get("questTrackerY")
            if x and x ~= false and y and y ~= false then
                if pendingReposition then return end
                pendingReposition = true
                -- Minimal delay (next frame) to reduce flicker
                C_Timer.After(0, function()
                    pendingReposition = false
                    FU:ApplyQuestTrackerPosition()
                end)
            end
        end)
        self.questTrackerHooked = true
    end
end

---------------------------------------------------------------------
-- Raid Warning Frame Anchor and Scaling
---------------------------------------------------------------------

function FU:CreateRaidWarningAnchor()
    if self.raidWarningAnchor then return self.raidWarningAnchor end
    self.raidWarningAnchor = CreatePositionAnchor({
        name        = "FURaidWarningAnchor",
        width       = 260, height = 50,
        point       = "TOP", relPoint = "TOP", x = 0, y = -200,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Raid Warning / Death Alert Anchor",
        onLock = function()
            FU:HideRaidWarningAnchor()
            if FU.optionsPanel and FU.optionsPanel.raidWarningAnchorButton then
                FU.optionsPanel.raidWarningAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveRaidWarningPosition,
    })
    return self.raidWarningAnchor
end

function FU:ShowRaidWarningAnchor()
    local anchor = self:CreateRaidWarningAnchor()
    local x = self:Get("raidWarningX")
    local y = self:Get("raidWarningY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("TOP", UIParent, "TOP", x, y)
    else
        anchor:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
    -- RaidWarningFrame is a fixed-size container; read its dimensions directly
    local w = (RaidWarningFrame and RaidWarningFrame:GetWidth()  > 0) and RaidWarningFrame:GetWidth()  or 500
    local h = (RaidWarningFrame and RaidWarningFrame:GetHeight() > 0) and RaidWarningFrame:GetHeight() or 50
    anchor:SetSize(math.max(w, 180), math.max(h, 52))
    anchor:Show()
    self:Print("Drag the anchor to reposition raid warnings / death alerts. Click 'Lock' when done.")
end

function FU:HideRaidWarningAnchor()
    if self.raidWarningAnchor then
        saveRaidWarningPosition(self.raidWarningAnchor)
        self.raidWarningAnchor:Hide()
        self:Print("Raid warning position saved.")
    end
end

function FU:ToggleRaidWarningAnchor()
    if self.raidWarningAnchor and self.raidWarningAnchor:IsShown() then
        self:HideRaidWarningAnchor()
        return false
    else
        self:ShowRaidWarningAnchor()
        return true
    end
end

function FU:ApplyRaidWarningScale(scale)
    scale = scale or self:Get("raidWarningScale") or 1.0
    if RaidWarningFrame then
        RaidWarningFrame:SetScale(scale)
    end
end

function FU:ApplyRaidWarningPosition()
    if not self:Get("scaleRaidWarnings") then return end

    local x = self:Get("raidWarningX")
    local y = self:Get("raidWarningY")
    if not x or x == false or not y or y == false then return end

    if RaidWarningFrame then
        self.raidWarningRepositioning = true
        RaidWarningFrame:ClearAllPoints()
        RaidWarningFrame:SetPoint("TOP", UIParent, "TOP", x, y)
        self.raidWarningRepositioning = false
    end
end

function FU:ResetRaidWarningToDefault()
    if RaidWarningFrame then
        RaidWarningFrame:ClearAllPoints()
        RaidWarningFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
end

function FU:ResetRaidWarningPosition()
    self:Set("raidWarningX", false)
    self:Set("raidWarningY", false)
    self:Set("raidWarningScale", 1.0)

    if self.raidWarningAnchor and self.raidWarningAnchor:IsShown() then
        self.raidWarningAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.raidWarningAnchorButton then
            self.optionsPanel.raidWarningAnchorButton:SetText("Move")
        end
    end

    self:ApplyRaidWarningScale(1.0)
    self:ResetRaidWarningToDefault()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Raid warning position reset to default.")
end

function FU:HookRaidWarningPosition()
    if RaidWarningFrame and not self.raidWarningHooked then
        local pendingReposition = false
        hooksecurefunc(RaidWarningFrame, "SetPoint", function()
            if FU.raidWarningRepositioning then return end
            if not FU:Get("scaleRaidWarnings") then return end
            local x = FU:Get("raidWarningX")
            local y = FU:Get("raidWarningY")
            if x and x ~= false and y and y ~= false then
                if pendingReposition then return end
                pendingReposition = true
                C_Timer.After(0, function()
                    pendingReposition = false
                    FU:ApplyRaidWarningPosition()
                end)
            end
        end)
        self.raidWarningHooked = true
    end
end
