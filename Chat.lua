-- FrameUnlocker Chat
-- Chat frame unlock, drag, and resize support

local addonName, FU = ...

function FU:UnlockChatFrame(chatFrame)
    if not chatFrame then return end

    local frameName = chatFrame:GetName()
    if not frameName then return end

    local chatTab = _G[frameName .. "Tab"]
    if not chatTab then return end

    chatFrame:SetMovable(true)
    chatFrame:SetClampedToScreen(true)
    chatFrame:SetResizable(true)

    local resizeButton = _G[frameName .. "ResizeButton"]
    if resizeButton then
        resizeButton:Show()
        resizeButton:EnableMouse(true)
    end

    chatTab:EnableMouse(true)
    chatTab:RegisterForDrag("LeftButton")

    -- Only hook once to prevent stacking on repeated calls (e.g. after Edit Mode exit)
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
    if not chatFrame then return end

    local frameName = chatFrame:GetName()
    if not frameName then return end

    local chatTab = _G[frameName .. "Tab"]
    if not chatTab then return end

    chatFrame:SetMovable(false)
    chatFrame:SetResizable(false)

    local resizeButton = _G[frameName .. "ResizeButton"]
    if resizeButton then
        resizeButton:Hide()
        resizeButton:EnableMouse(false)
    end

    -- Empty args clears all registered drag buttons; HookScript handlers remain
    -- but are guarded by the IsMovable() check in OnDragStart.
    chatTab:RegisterForDrag()
end
