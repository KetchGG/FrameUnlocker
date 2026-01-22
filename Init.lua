-- FrameUnlocker Initialization
-- Event handling and startup

local addonName, FU = ...

---------------------------------------------------------------------
-- Edit Mode hook: re-unlock chat after exiting Edit Mode
-- (defined before event handler so it can be referenced)
---------------------------------------------------------------------

local function OnEditModeExit()
    if not FU:Get("unlockChat") then
        return
    end
    -- Short delay lets Blizzard's layout code finish first.
    C_Timer.After(0.3, function()
        FU:UnlockChatFrame(ChatFrame1)
        FU:Print("Chat re-unlocked after Edit Mode.")
    end)
end

---------------------------------------------------------------------
-- Event frame
---------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize saved variables and options
        FU:InitDB()
        FU:CreateOptionsPanel()

        -- Refresh options panel to match saved settings
        if FU.optionsPanel and FU.optionsPanel.refresh then
            FU.optionsPanel.refresh()
        end

        -- No longer need this event
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- Apply settings on login
        if FU:Get("unlockChat") then
            FU:UnlockChatFrame(ChatFrame1)
        end

        if FU:Get("scaleRaidFrames") then
            FU:ApplyRaidFrameScale()
        end

        -- Hook Edit Mode (frames exist now after login)
        if EditModeManagerFrame then
            EditModeManagerFrame:HookScript("OnHide", OnEditModeExit)
        elseif EditModeManager then
            EditModeManager:HookScript("OnHide", OnEditModeExit)
        end

        FU:Print("Initialized. Type /fu for help.")
    end
end)

---------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------

SLASH_FRAMEUNLOCKER1 = "/fu"
SLASH_FRAMEUNLOCKER2 = "/frameunlocker"

SlashCmdList.FRAMEUNLOCKER = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "options" or msg == "config" or msg == "settings" then
        FU:OpenOptions()
    elseif msg == "unlock" then
        FU:UnlockChatFrame(ChatFrame1)
        FU:Print("Chat unlocked.")
    elseif msg == "lock" then
        FU:LockChatFrame(ChatFrame1)
        FU:Print("Chat locked.")
    elseif msg == "scale" then
        FU:ApplyRaidFrameScale()
        FU:Print("Raid frame scale applied.")
    else
        FU:Print("Commands:")
        FU:Print("  /fu - Help menu")
        FU:Print("  /fu options - Open settings")
        FU:Print("  /fu unlock - Force unlock chat")
        FU:Print("  /fu lock - Force lock chat")
        FU:Print("  /fu scale - Apply raid frame scale")
    end
end
