-- FrameUnlocker Core
-- Shared utilities and full settings application

local addonName, FU = ...

function FU:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff2BB673[FU]|r " .. msg)
    end
end

---------------------------------------------------------------------
-- Combat deferral
-- Some Blizzard frames are secure/managed (e.g. ArenaEnemyFrames, the objective
-- tracker); moving or reparenting them is blocked during combat and taints the
-- addon. Queue that work and flush it when combat ends. Keyed so repeated requests
-- (e.g. a burst of SetPoint hooks) coalesce to the latest. Init.lua flushes this
-- on PLAYER_REGEN_ENABLED.
---------------------------------------------------------------------

local combatDeferred = {}

function FU:InCombat()
    return InCombatLockdown and InCombatLockdown()
end

function FU:DeferToCombatEnd(key, fn)
    combatDeferred[key] = fn
end

function FU:FlushCombatDeferred()
    if not next(combatDeferred) then return end
    local pending = combatDeferred
    combatDeferred = {}
    for _, fn in pairs(pending) do fn() end
end

function FU:ApplyAllSettings()
    if self:Get("unlockChat") then
        self:UnlockChatFrame(ChatFrame1)
    else
        self:LockChatFrame(ChatFrame1)
    end
    self:ApplyRaidFrameScale(self:Get("scaleRaidFrames") and self:Get("raidFrameScale") or 1.0)
    self:ApplyPartyFrameScale(self:Get("scalePartyFrames") and self:Get("partyFrameScale") or 1.0)
    self:ApplyLootFrameScale(self:Get("scaleLootFrames") and self:Get("lootFrameScale") or 1.0)
    self:ApplyLootFramePosition()
    self:ApplyArenaFrameScale(self:Get("scaleArenaFrames") and self:Get("arenaFrameScale") or 1.0)
    self:ApplyArenaFramePosition()
    self:ApplyQuestTrackerScale(self:Get("scaleQuestTracker") and self:Get("questTrackerScale") or 1.0)
    self:ApplyQuestTrackerPosition()
    self:ApplyRaidWarningScale(self:Get("scaleRaidWarnings") and self:Get("raidWarningScale") or 1.0)
    self:ApplyRaidWarningPosition()
    self:ApplyBelowMinimapScale(self:Get("scaleBelowMinimap") and self:Get("belowMinimapScale") or 1.0)
    self:ApplyBelowMinimapPosition()

    -- Wrapped in pcall so a bag-frame-specific failure (this is the newest,
    -- least-tested code path) can't prevent the caller's own follow-up code
    -- (e.g. the "/fu reset" confirmation message) from running.
    local ok, err = pcall(function()
        if self:Get("unlockBagFrame") then
            self:UnlockBagFrame()
            self:ApplyBagFramePosition()
        else
            self:LockBagFrame()
        end
    end)
    if not ok then
        self:Print("|cffff0000Combined bag frame error:|r " .. tostring(err))
    end
end
