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
end
