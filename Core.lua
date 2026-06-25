-- FrameUnlocker Core
-- Shared utilities and full settings application

local addonName, FU = ...

function FU:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff2BB673[FU]|r " .. msg)
    end
end

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
    self:ApplyQuestTrackerScale(self:Get("scaleQuestTracker") and self:Get("questTrackerScale") or 1.0)
    self:ApplyQuestTrackerPosition()
    self:ApplyRaidWarningScale(self:Get("scaleRaidWarnings") and self:Get("raidWarningScale") or 1.0)
    self:ApplyRaidWarningPosition()
end
