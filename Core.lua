-- FrameUnlocker Core Features
-- Chat frame unlocking and raid frame scaling

local addonName, FU = ...

---------------------------------------------------------------------
-- Chat Frame Unlocking
---------------------------------------------------------------------

function FU:UnlockChatFrame(chatFrame)
    if not chatFrame then
        return
    end

    local frameName = chatFrame:GetName()
    if not frameName then
        return
    end

    local chatTab = _G[frameName .. "Tab"]
    if not chatTab then
        return
    end

    -- Allow the frame to be moved.
    chatFrame:SetMovable(true)
    chatFrame:SetClampedToScreen(true)

    -- Allow the frame to be resized (no bounds - full user control)
    chatFrame:SetResizable(true)

    -- Show the resize button if it exists.
    local resizeButton = _G[frameName .. "ResizeButton"]
    if resizeButton then
        resizeButton:Show()
        resizeButton:EnableMouse(true)
    end

    -- Let the tab receive drag events.
    chatTab:EnableMouse(true)
    chatTab:RegisterForDrag("LeftButton")

    -- Use HookScript to avoid taint issues with protected frames
    -- Only hook once to prevent stacking on repeated calls
    if not chatTab.FU_Hooked then
        chatTab:HookScript("OnDragStart", function()
            if chatFrame:IsMovable() then
                chatFrame:StartMoving()
            end
        end)

        chatTab:HookScript("OnDragStop", function()
            chatFrame:StopMovingOrSizing()
        end)
        chatTab.FU_Hooked = true
    end
end

function FU:LockChatFrame(chatFrame)
    if not chatFrame then
        return
    end

    local frameName = chatFrame:GetName()
    if not frameName then
        return
    end

    local chatTab = _G[frameName .. "Tab"]
    if not chatTab then
        return
    end

    -- Prevent the frame from being moved.
    chatFrame:SetMovable(false)

    -- Prevent the frame from being resized.
    chatFrame:SetResizable(false)

    -- Hide the resize button if it exists.
    local resizeButton = _G[frameName .. "ResizeButton"]
    if resizeButton then
        resizeButton:Hide()
        resizeButton:EnableMouse(false)
    end

    -- Remove drag registration (empty args clears all drag buttons)
    -- Note: HookScript handlers remain but are guarded by IsMovable() check
    chatTab:RegisterForDrag()
end

---------------------------------------------------------------------
-- Raid Frame Scaling
---------------------------------------------------------------------

function FU:ApplyRaidFrameScale(scale)
    if CompactRaidFrameContainer then
        CompactRaidFrameContainer:SetScale(scale or self:Get("raidFrameScale") or 1.0)
    end
end

---------------------------------------------------------------------
-- Party Frame Scaling
---------------------------------------------------------------------

function FU:ApplyPartyFrameScale(scale)
    scale = scale or self:Get("partyFrameScale") or 1.0
    local scaled = false
    
    -- Modern party frame container (Midnight/TBC Anniversary)
    if PartyFrame then
        PartyFrame:SetScale(scale)
        scaled = true
    end
    
    -- Compact party frame (raid-style party frames)
    if CompactPartyFrame then
        CompactPartyFrame:SetScale(scale)
        scaled = true
    end
    
    -- Legacy party member frames (Classic/older clients)
    if not scaled then
        for i = 1, 4 do
            local frame = _G["PartyMemberFrame" .. i]
            if frame then
                frame:SetScale(scale)
            end
        end
    end
end

---------------------------------------------------------------------
-- Status Bar Scaling (XP, Rep, Honor bars)
---------------------------------------------------------------------

function FU:ApplyStatusBarScale(scale)
    scale = scale or self:Get("statusBarScale") or 1.0
    
    -- Primary status bar container (bottom bar)
    if MainStatusTrackingBarContainer then
        MainStatusTrackingBarContainer:SetScale(scale)
    end
    
    -- Secondary status bar container (top bar)
    if SecondaryStatusTrackingBarContainer then
        SecondaryStatusTrackingBarContainer:SetScale(scale)
    end
    
    -- Fallback: StatusTrackingBarManager (older clients)
    if StatusTrackingBarManager and not MainStatusTrackingBarContainer then
        StatusTrackingBarManager:SetScale(scale)
    end
end

---------------------------------------------------------------------
-- Loot Roll Frame Anchor and Scaling
---------------------------------------------------------------------

-- Create the draggable anchor frame (created once, reused)
function FU:CreateLootAnchor()
    if self.lootAnchor then
        return self.lootAnchor
    end
    
    local anchor = CreateFrame("Frame", "FULootAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(220, 60)
    anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:Hide()
    
    -- Visual styling
    anchor:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    anchor:SetBackdropColor(0.1, 0.6, 0.3, 0.9)
    anchor:SetBackdropBorderColor(0.2, 0.8, 0.4, 1)
    
    -- Label
    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", 0, -8)
    label:SetText("Loot Roll Anchor")
    
    -- Scale button (opens options)
    local scaleBtn = CreateFrame("Button", nil, anchor, "UIPanelButtonTemplate")
    scaleBtn:SetSize(80, 22)
    scaleBtn:SetPoint("BOTTOMLEFT", 12, 8)
    scaleBtn:SetText("Scale")
    scaleBtn:SetScript("OnClick", function()
        FU:OpenOptions()
    end)
    
    -- Lock button
    local lockBtn = CreateFrame("Button", nil, anchor, "UIPanelButtonTemplate")
    lockBtn:SetSize(80, 22)
    lockBtn:SetPoint("BOTTOMRIGHT", -12, 8)
    lockBtn:SetText("Lock")
    lockBtn:SetScript("OnClick", function()
        FU:HideLootAnchor()
        -- Update options panel button if it exists
        if FU.optionsPanel and FU.optionsPanel.lootAnchorButton then
            FU.optionsPanel.lootAnchorButton:SetText("Move")
        end
    end)
    
    -- Drag handlers
    anchor:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local x, y = self:GetCenter()
        local uiX, uiY = UIParent:GetCenter()
        FU:Set("lootFrameX", x - uiX)
        FU:Set("lootFrameY", y - uiY)
        -- Apply to loot container
        FU:ApplyLootFramePosition()
    end)
    
    self.lootAnchor = anchor
    return anchor
end

function FU:ShowLootAnchor()
    local anchor = self:CreateLootAnchor()
    
    -- Position anchor at saved location or center
    local x = self:Get("lootFrameX")
    local y = self:Get("lootFrameY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
    else
        -- Default to where GroupLootContainer usually is
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
    end
    
    anchor:Show()
    self:Print("Drag the anchor to reposition loot roll frames. Click 'Lock' when done.")
end

function FU:HideLootAnchor()
    if self.lootAnchor then
        -- Save position before hiding
        local x, y = self.lootAnchor:GetCenter()
        if x and y then
            local uiX, uiY = UIParent:GetCenter()
            self:Set("lootFrameX", x - uiX)
            self:Set("lootFrameY", y - uiY)
            self:ApplyLootFramePosition()
        end
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
    -- Only apply custom position if loot frame scaling is enabled
    if not self:Get("scaleLootFrames") then
        return
    end
    
    local x = self:Get("lootFrameX")
    local y = self:Get("lootFrameY")
    
    if not x or x == false or not y or y == false then
        return  -- Use default position
    end
    
    -- Apply custom position to GroupLootContainer
    if GroupLootContainer then
        GroupLootContainer:ClearAllPoints()
        GroupLootContainer:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
end

-- Reset loot frame to default position (shared logic)
local function ResetLootContainerToDefault()
    if GroupLootContainer then
        GroupLootContainer:ClearAllPoints()
        if GroupLootContainer.Layout then
            GroupLootContainer:Layout()
        end
    end
end

-- Reset loot frame to default position without clearing saved coordinates
function FU:ResetLootFrameToDefault()
    ResetLootContainerToDefault()
end

function FU:ResetLootFramePosition()
    -- Clear saved position
    self:Set("lootFrameX", false)
    self:Set("lootFrameY", false)
    
    -- Hide anchor if shown
    if self.lootAnchor and self.lootAnchor:IsShown() then
        self.lootAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.lootAnchorButton then
            self.optionsPanel.lootAnchorButton:SetText("Move")
        end
    end
    
    ResetLootContainerToDefault()
    self:Print("Loot frame position reset to default.")
end

function FU:ApplyLootFrameScale(scale)
    scale = scale or self:Get("lootFrameScale") or 1.0
    
    if GroupLootContainer then
        GroupLootContainer:SetScale(scale)
    end
    
    -- Also scale individual loot frames if they exist
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame then
            frame:SetScale(scale)
        end
    end
end

-- Hook to reapply position after Blizzard resets it
function FU:HookLootFramePosition()
    if GroupLootContainer and not self.lootFrameHooked then
        local pendingReposition = false
        hooksecurefunc(GroupLootContainer, "SetPoint", function()
            -- Only override if loot frame scaling is enabled and we have a saved position
            if not FU:Get("scaleLootFrames") then
                return
            end
            local x = FU:Get("lootFrameX")
            local y = FU:Get("lootFrameY")
            if x and x ~= false and y and y ~= false then
                -- Throttle to prevent rapid-fire repositioning
                if pendingReposition then
                    return
                end
                pendingReposition = true
                C_Timer.After(0.05, function()
                    pendingReposition = false
                    FU:ApplyLootFramePosition()
                end)
            end
        end)
        self.lootFrameHooked = true
    end
end

---------------------------------------------------------------------
-- Arena/Flag Carrier Frame Anchor and Scaling
---------------------------------------------------------------------

-- Create the draggable anchor frame for arena frames
function FU:CreateArenaAnchor()
    if self.arenaAnchor then
        return self.arenaAnchor
    end
    
    local anchor = CreateFrame("Frame", "FUArenaAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(180, 50)
    anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -200)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:Hide()
    
    -- Visual styling (purple/red for PvP theme)
    anchor:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    anchor:SetBackdropColor(0.6, 0.1, 0.3, 0.9)
    anchor:SetBackdropBorderColor(0.8, 0.2, 0.4, 1)
    
    -- Label
    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", 0, -8)
    label:SetText("Arena/Flag Carrier Anchor")
    
    -- Scale button (opens options)
    local scaleBtn = CreateFrame("Button", nil, anchor, "UIPanelButtonTemplate")
    scaleBtn:SetSize(70, 20)
    scaleBtn:SetPoint("BOTTOMLEFT", 8, 6)
    scaleBtn:SetText("Scale")
    scaleBtn:SetScript("OnClick", function()
        FU:OpenOptions()
    end)
    
    -- Lock button
    local lockBtn = CreateFrame("Button", nil, anchor, "UIPanelButtonTemplate")
    lockBtn:SetSize(70, 20)
    lockBtn:SetPoint("BOTTOMRIGHT", -8, 6)
    lockBtn:SetText("Lock")
    lockBtn:SetScript("OnClick", function()
        FU:HideArenaAnchor()
        -- Update options panel button if it exists
        if FU.optionsPanel and FU.optionsPanel.arenaAnchorButton then
            FU.optionsPanel.arenaAnchorButton:SetText("Move")
        end
    end)
    
    -- Drag handlers
    anchor:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position using TOPRIGHT relative to screen
        local right = self:GetRight()
        local top = self:GetTop()
        local screenW = UIParent:GetWidth()
        local screenH = UIParent:GetHeight()
        FU:Set("arenaFrameX", right - screenW)  -- negative offset from right
        FU:Set("arenaFrameY", top - screenH)    -- negative offset from top
        -- Apply to arena container
        FU:ApplyArenaFramePosition()
    end)
    
    self.arenaAnchor = anchor
    return anchor
end

function FU:ShowArenaAnchor()
    local anchor = self:CreateArenaAnchor()
    
    -- Position anchor at saved location or default arena position
    local x = self:Get("arenaFrameX")
    local y = self:Get("arenaFrameY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    else
        -- Default to right side where arena frames usually appear
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -200)
    end
    
    anchor:Show()
    self:Print("Drag the anchor to reposition arena/flag carrier frames. Click 'Lock' when done.")
end

function FU:HideArenaAnchor()
    if self.arenaAnchor then
        -- Save position before hiding using TOPRIGHT
        local right = self.arenaAnchor:GetRight()
        local top = self.arenaAnchor:GetTop()
        if right and top then
            local screenW = UIParent:GetWidth()
            local screenH = UIParent:GetHeight()
            self:Set("arenaFrameX", right - screenW)
            self:Set("arenaFrameY", top - screenH)
            self:ApplyArenaFramePosition()
        end
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
    -- Only apply custom position if arena frame scaling is enabled
    if not self:Get("scaleArenaFrames") then
        return
    end
    
    local x = self:Get("arenaFrameX")
    local y = self:Get("arenaFrameY")
    
    if not x or x == false or not y or y == false then
        return  -- Use default position
    end
    
    -- Apply custom position to ArenaEnemyFrames container using TOPRIGHT
    if ArenaEnemyFrames then
        ArenaEnemyFrames:ClearAllPoints()
        ArenaEnemyFrames:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    end
end

-- Reset arena frame to default position (shared logic)
local function ResetArenaContainerToDefault()
    if ArenaEnemyFrames then
        ArenaEnemyFrames:ClearAllPoints()
        -- Default arena frames position (right side of screen)
        ArenaEnemyFrames:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -200)
    end
end

-- Reset arena frame to default position without clearing saved coordinates
function FU:ResetArenaFrameToDefault()
    ResetArenaContainerToDefault()
end

function FU:ResetArenaFramePosition()
    -- Clear saved position
    self:Set("arenaFrameX", false)
    self:Set("arenaFrameY", false)
    
    -- Hide anchor if shown
    if self.arenaAnchor and self.arenaAnchor:IsShown() then
        self.arenaAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.arenaAnchorButton then
            self.optionsPanel.arenaAnchorButton:SetText("Move")
        end
    end
    
    ResetArenaContainerToDefault()
    self:Print("Arena/flag carrier frame position reset to default.")
end

function FU:ApplyArenaFrameScale(scale)
    scale = scale or self:Get("arenaFrameScale") or 1.0
    
    -- Scale the main container
    if ArenaEnemyFrames then
        ArenaEnemyFrames:SetScale(scale)
    end
    
    -- Also scale individual arena frames if they exist (fallback)
    for i = 1, 5 do
        local frame = _G["ArenaEnemyFrame" .. i]
        if frame then
            frame:SetScale(scale)
        end
    end
end

-- Hook to reapply position after Blizzard resets it
function FU:HookArenaFramePosition()
    if ArenaEnemyFrames and not self.arenaFrameHooked then
        local pendingReposition = false
        hooksecurefunc(ArenaEnemyFrames, "SetPoint", function()
            -- Only override if arena frame scaling is enabled and we have a saved position
            if not FU:Get("scaleArenaFrames") then
                return
            end
            local x = FU:Get("arenaFrameX")
            local y = FU:Get("arenaFrameY")
            if x and x ~= false and y and y ~= false then
                -- Throttle to prevent rapid-fire repositioning
                if pendingReposition then
                    return
                end
                pendingReposition = true
                C_Timer.After(0.05, function()
                    pendingReposition = false
                    FU:ApplyArenaFramePosition()
                end)
            end
        end)
        self.arenaFrameHooked = true
    end
end

---------------------------------------------------------------------
-- Print helper
---------------------------------------------------------------------

function FU:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff2BB673[FU]|r " .. msg)
    end
end

---------------------------------------------------------------------
-- Apply all settings (used by reset and initialization)
---------------------------------------------------------------------

function FU:ApplyAllSettings()
    if self:Get("unlockChat") then
        self:UnlockChatFrame(ChatFrame1)
    else
        self:LockChatFrame(ChatFrame1)
    end
    self:ApplyRaidFrameScale(self:Get("scaleRaidFrames") and self:Get("raidFrameScale") or 1.0)
    self:ApplyPartyFrameScale(self:Get("scalePartyFrames") and self:Get("partyFrameScale") or 1.0)
    self:ApplyStatusBarScale(self:Get("scaleStatusBars") and self:Get("statusBarScale") or 1.0)
    self:ApplyLootFrameScale(self:Get("scaleLootFrames") and self:Get("lootFrameScale") or 1.0)
    self:ApplyLootFramePosition()
    self:ApplyArenaFrameScale(self:Get("scaleArenaFrames") and self:Get("arenaFrameScale") or 1.0)
    self:ApplyArenaFramePosition()
end
