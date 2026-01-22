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

    -- Allow the frame to be resized.
    chatFrame:SetResizable(true)
    if chatFrame.SetResizeBounds then
        -- Modern API (Dragonflight+)
        chatFrame:SetResizeBounds(200, 100, 800, 600)
    elseif chatFrame.SetMinResize and chatFrame.SetMaxResize then
        -- Legacy API (Classic/TBC)
        chatFrame:SetMinResize(200, 100)
        chatFrame:SetMaxResize(800, 600)
    end

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
    chatTab:HookScript("OnDragStart", function()
        if chatFrame:IsMovable() then
            chatFrame:StartMoving()
        end
    end)

    chatTab:HookScript("OnDragStop", function()
        chatFrame:StopMovingOrSizing()
    end)
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
    chatTab:RegisterForDrag()
    chatTab:SetScript("OnDragStart", nil)
    chatTab:SetScript("OnDragStop", nil)
end

---------------------------------------------------------------------
-- Raid Frame Scaling
---------------------------------------------------------------------

function FU:ApplyRaidFrameScale(scale)
    if CompactRaidFrameContainer then
        CompactRaidFrameContainer:SetScale(scale or self:Get("raidFrameScale") or 0.8)
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
