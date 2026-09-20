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
    if FU:Get("scaleLootFrames") then
        FU:ApplyLootFrameScale()
    end
    FU:ApplyLootFramePosition()
    if FU:Get("scaleArenaFrames") then
        FU:ApplyArenaFrameScale()
    end
    FU:ApplyArenaFramePosition()
    if FU:Get("scaleQuestTracker") then
        FU:ApplyQuestTrackerScale()
    end
    FU:ApplyQuestTrackerPosition()
    if FU:Get("scaleRaidWarnings") then
        FU:ApplyRaidWarningScale()
    end
    FU:ApplyRaidWarningPosition()
    if FU:Get("scaleBelowMinimap") then
        FU:ApplyBelowMinimapScale()
    end
    FU:ApplyBelowMinimapPosition()

    -- ContainerFrameCombinedBags isn't guaranteed to exist yet at PLAYER_LOGIN
    -- (unlike the frames above, which are always-present FrameXML elements), so
    -- unlocking/hooking it lives here rather than as a one-shot PLAYER_LOGIN call
    -- -- this function also re-runs on PLAYER_ENTERING_WORLD, giving it another
    -- chance to attach once the frame actually exists. Wrapped in pcall so a
    -- failure here (this is the newest, least-tested code path) can't take down
    -- ReapplyScaling's caller mid-function -- PLAYER_LOGIN calls this directly,
    -- and everything after that call (event registration, EditMode extras) would
    -- silently never run if this threw uncaught.
    local ok, err = pcall(function()
        if FU:Get("unlockBagFrame") then
            FU:UnlockBagFrame()
        end
        FU:ApplyBagFramePosition()
        FU:HookBagFramePosition()
    end)
    if not ok then
        FU:Print("|cffff0000Combined bag frame error:|r " .. tostring(err))
    end
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
        FU:HookQuestTrackerPosition()
        FU:HookRaidWarningPosition()
        FU:HookBelowMinimapPosition()

        -- Register events that may require reapplying settings
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("UI_SCALE_CHANGED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
        self:RegisterEvent("ARENA_OPPONENT_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")  -- flush combat-deferred frame moves

        -- Hook Edit Mode (frames exist now after login, not available in Classic Era)
        if EditModeManagerFrame and EditModeManagerFrame.HookScript then
            EditModeManagerFrame:HookScript("OnHide", OnEditModeExit)
        elseif EditModeManager and EditModeManager.HookScript then
            EditModeManager:HookScript("OnHide", OnEditModeExit)
        end

        -- Add our controls to the Edit Mode raid/party (scale) and chat (unlock)
        -- dialogs (self-guards on clients without Edit Mode).
        FU:SetupEditModeExtras()

        -- Hook raid frame layout updates so our scale is reapplied after Blizzard
        -- rebuilds the frames. Retail/TBC expose ApplyToFrames as a mixin method on
        -- the container; Classic Era has no mixin -- it's a plain global that takes
        -- the container as its first arg. Hook whichever form the client provides.
        local function ReapplyRaidLayout()
            if FU:Get("scaleRaidFrames") then
                ThrottledCall("raidLayout", 0.1, function()
                    FU:ApplyRaidFrameScale()
                end)
            end
        end
        if CompactRaidFrameContainer and CompactRaidFrameContainer.ApplyToFrames then
            hooksecurefunc(CompactRaidFrameContainer, "ApplyToFrames", ReapplyRaidLayout)
        elseif CompactRaidFrameContainer_ApplyToFrames then
            hooksecurefunc("CompactRaidFrameContainer_ApplyToFrames", ReapplyRaidLayout)
        end

        FU:Print("Initialized. Type /fu for options.")
        if FU.restoredFromMirror then
            FU:Print("SavedVariables didn't load (WoW Forever beta bug) -- settings restored from backup.")
        end

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
        -- Reapply arena frame settings when entering arena/BG with flag carriers.
        -- ApplyArenaFramePosition defers itself if we're in combat (arena frames are
        -- secure and can't be moved then); it reapplies on PLAYER_REGEN_ENABLED.
        ThrottledCall("arenaFrames", 0.3, function()
            if FU:Get("scaleArenaFrames") then
                FU:ApplyArenaFrameScale()
                FU:ApplyArenaFramePosition()
            end
        end)

    elseif event == "PLAYER_REGEN_ENABLED" then
        FU:FlushCombatDeferred()
    end
end)

---------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------

SLASH_FRAMEUNLOCKER1 = "/fu"
SLASH_FRAMEUNLOCKER2 = "/frameunlocker"

SlashCmdList.FRAMEUNLOCKER = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "reset" then
        FU:ResetToDefaults()
        if FU.optionsPanel and FU.optionsPanel.refresh then
            FU.optionsPanel.refresh()
        end
        FU:ApplyAllSettings()
        FU:Print("Settings reset to defaults.")
    else
        -- Everything else (including options/config/settings and no argument)
        -- opens the settings panel; per-feature moving is done from there.
        FU:OpenOptions()
    end
end
