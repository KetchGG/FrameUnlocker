-- FrameUnlocker
-- Automatically unlocks the main chat window so you can drag it by its tab
-- (e.g. "General") and resize it via the bottom-right corner.
-- Unlocks on login and after exiting Edit Mode.

---------------------------------------------------------------------
-- Unlock logic: make the chat frame draggable and resizable
---------------------------------------------------------------------

local function UnlockChatFrame(chatFrame)
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

    chatTab:SetScript("OnDragStart", function()
        if chatFrame:IsMovable() then
            chatFrame:StartMoving()
        end
    end)

    chatTab:SetScript("OnDragStop", function()
        chatFrame:StopMovingOrSizing()
    end)
end

---------------------------------------------------------------------
-- Initialization: unlock chat on login
---------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        UnlockChatFrame(ChatFrame1)
        
        -- Scale compact raid frames to 80%.
        if CompactRaidFrameContainer then
            CompactRaidFrameContainer:SetScale(0.8)
        end
        
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FU]|r Chat unlocked. Drag tab to move, corner to resize.")
        end
    end
end)

---------------------------------------------------------------------
-- Edit Mode hook: re-unlock chat after exiting Edit Mode
---------------------------------------------------------------------

local function OnEditModeExit()
    -- Short delay lets Blizzard's layout code finish first.
    C_Timer.After(0.3, function()
        UnlockChatFrame(ChatFrame1)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FU]|r Chat re-unlocked. Drag tab to move, corner to resize.")
        end
    end)
end

-- Try multiple approaches since the exact global/method varies by client.
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnHide", OnEditModeExit)
elseif EditModeManager then
    EditModeManager:HookScript("OnHide", OnEditModeExit)
end

---------------------------------------------------------------------
-- Slash command: /fu to force unlock
---------------------------------------------------------------------

SLASH_FRAMEUNLOCKER1 = "/fu"
SlashCmdList.FRAMEUNLOCKER = function()
    UnlockChatFrame(ChatFrame1)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FU]|r Chat unlocked. Drag tab to move, corner to resize.")
    end
end
