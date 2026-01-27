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
-- Reapply scaling settings (called on various UI update events)
---------------------------------------------------------------------

local function ReapplyScaling()
    if FU:Get("scaleRaidFrames") then
        FU:ApplyRaidFrameScale()
    end
    if FU:Get("scalePartyFrames") then
        FU:ApplyPartyFrameScale()
    end
    if FU:Get("scaleStatusBars") then
        FU:ApplyStatusBarScale()
    end
    if FU:Get("scaleLootFrames") then
        FU:ApplyLootFrameScale()
    end
    FU:ApplyLootFramePosition()
    if FU:Get("scaleArenaFrames") then
        FU:ApplyArenaFrameScale()
    end
    FU:ApplyArenaFramePosition()
end

---------------------------------------------------------------------
-- Throttle helper to prevent rapid-fire event handling
---------------------------------------------------------------------

local pendingTimers = {}

local function ThrottledCall(key, delay, func)
    if pendingTimers[key] then
        return  -- Already scheduled
    end
    pendingTimers[key] = true
    C_Timer.After(delay, function()
        pendingTimers[key] = nil
        func()
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

        ReapplyScaling()
        FU:HookLootFramePosition()
        FU:HookArenaFramePosition()

        -- Register events that may require reapplying settings
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("UI_SCALE_CHANGED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
        self:RegisterEvent("ARENA_OPPONENT_UPDATE")

        -- Hook Edit Mode (frames exist now after login)
        if EditModeManagerFrame then
            EditModeManagerFrame:HookScript("OnHide", OnEditModeExit)
        elseif EditModeManager then
            EditModeManager:HookScript("OnHide", OnEditModeExit)
        end

        -- Hook raid frame layout updates (if available)
        if CompactRaidFrameContainer and CompactRaidFrameContainer.ApplyToFrames then
            hooksecurefunc(CompactRaidFrameContainer, "ApplyToFrames", function()
                if FU:Get("scaleRaidFrames") then
                    ThrottledCall("raidLayout", 0.1, function()
                        FU:ApplyRaidFrameScale()
                    end)
                end
            end)
        end

        FU:Print("Initialized. Type /fu for options.")

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Reapply party/raid scaling when group composition changes (throttled)
        ThrottledCall("groupRoster", 0.3, function()
            if FU:Get("scaleRaidFrames") then
                FU:ApplyRaidFrameScale()
            end
            if FU:Get("scalePartyFrames") then
                FU:ApplyPartyFrameScale()
            end
        end)

    elseif event == "UI_SCALE_CHANGED" then
        -- Reapply all scaling after UI scale change
        ThrottledCall("uiScale", 0.3, ReapplyScaling)

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Reapply after loading screens (throttled to avoid spam)
        ThrottledCall("enterWorld", 0.5, ReapplyScaling)

    elseif event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS" or event == "ARENA_OPPONENT_UPDATE" then
        -- Reapply arena frame settings when entering arena/BG with flag carriers
        ThrottledCall("arenaFrames", 0.3, function()
            if FU:Get("scaleArenaFrames") then
                FU:ApplyArenaFrameScale()
                FU:ApplyArenaFramePosition()
            end
        end)
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
    elseif msg == "loot" then
        -- Enable loot frame customization if not already enabled
        if not FU:Get("scaleLootFrames") then
            FU:Set("scaleLootFrames", true)
            if FU.optionsPanel and FU.optionsPanel.refresh then
                FU.optionsPanel.refresh()
            end
        end
        FU:ToggleLootAnchor()
    elseif msg == "arena" then
        -- Enable arena frame customization if not already enabled
        if not FU:Get("scaleArenaFrames") then
            FU:Set("scaleArenaFrames", true)
            if FU.optionsPanel and FU.optionsPanel.refresh then
                FU.optionsPanel.refresh()
            end
        end
        FU:ToggleArenaAnchor()
    elseif msg == "reset" then
        FU:ResetToDefaults()
        if FU.optionsPanel and FU.optionsPanel.refresh then
            FU.optionsPanel.refresh()
        end
        FU:ApplyAllSettings()
        FU:Print("Settings reset to defaults.")
    else
        FU:OpenOptions()
    end
end
