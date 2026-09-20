-- FrameUnlocker Configuration
-- Handles defaults and saved variables initialization

-- Create addon namespace
local addonName, FU = ...
_G.FrameUnlocker = FU

-- Default settings
FU.defaults = {
    unlockChat = true,
    scaleRaidFrames = false,
    raidFrameScale = 1.0,
    scalePartyFrames = false,
    partyFrameScale = 1.0,
    scaleLootFrames = false,
    lootFrameScale = 1.0,
    lootFrameX = false,  -- false = use default position
    lootFrameY = false,
    scaleArenaFrames = false,
    arenaFrameScale = 1.0,
    arenaFrameX = false,  -- false = use default position
    arenaFrameY = false,
    scaleQuestTracker = false,
    questTrackerScale = 1.0,
    questTrackerX = false,  -- false = use default position
    questTrackerY = false,
    scaleRaidWarnings = false,
    raidWarningScale = 1.0,
    raidWarningX = false,  -- false = use default position
    raidWarningY = false,
    scaleBelowMinimap = false,
    belowMinimapScale = 1.0,
    belowMinimapX = false,  -- false = use default position
    belowMinimapY = false,
    unlockBagFrame = false,
    bagFrameX = false,  -- false = use default position
    bagFrameY = false,
}

-- Nominal height of a single loot roll frame. Only used to migrate saved
-- coordinates below, where the real frame isn't available to measure (no roll is
-- active at login). Matches the fallback in FU:ShowLootAnchor.
local LOOT_ROLL_HEIGHT = 60

-- One-time saved-variable migrations. Runs after defaults are merged.
--
-- Migration flags are schema metadata, not settings, so they deliberately live
-- outside FU.defaults -- otherwise ResetToDefaults would clear the flag and the
-- migration would run a second time against already-migrated coordinates.
local function MigrateDB(db)
    -- 1.6.0: the loot container switched from CENTER to BOTTOM anchoring so the
    -- roll stack grows upward instead of expanding around its midpoint. lootFrameY
    -- used to mean "centre of the stack" and now means "bottom of the stack", so
    -- shift existing values down half a roll frame to keep them where they were.
    if not db.lootFrameYIsBottom then
        if db.lootFrameY and db.lootFrameY ~= false then
            db.lootFrameY = db.lootFrameY - (LOOT_ROLL_HEIGHT / 2)
        end
        db.lootFrameYIsBottom = true
    end
end

---------------------------------------------------------------------
-- Per-character backup (WoW Forever beta workaround)
---------------------------------------------------------------------
-- The WoW Forever beta client (1.60.x) writes account-wide SavedVariables but
-- never reads them back, so FrameUnlockerDB arrives nil every session. Verified
-- in-game 2026-09-19 (build 1.60.1): SavedVariablesPerCharacter *does* load
-- normally on that client -- a hand-seeded account file stayed nil while a
-- per-character table came back with the value written at the previous logout.
--
-- So the whole DB is also kept in FrameUnlockerCharDB, and InitDB restores from
-- it when the account-wide table comes back empty. Where SavedVariables load
-- normally the account DB always wins and the backup is never read. The cost is
-- that on the buggy client settings are effectively per character (a new
-- character starts on defaults) -- the alternative is losing them every session.

local function CopyDB(src)
    local out = {}
    for k, v in pairs(src) do
        if type(v) ~= "table" and type(v) ~= "function" then out[k] = v end
    end
    return out
end

-- Keep the per-character copy in step with the live DB.
local function WriteBackup(db)
    if type(db) ~= "table" then return end
    FrameUnlockerCharDB = FrameUnlockerCharDB or {}
    FrameUnlockerCharDB.db = CopyDB(db)
end

-- Initialize saved variables
function FU:InitDB()
    if not FrameUnlockerDB then
        FrameUnlockerDB = {}
        -- Nil here means either a genuine first install or the Forever client
        -- dropping our SavedVariables; the per-character backup tells them apart.
        local backup = type(FrameUnlockerCharDB) == "table" and FrameUnlockerCharDB.db
        if type(backup) == "table" and next(backup) ~= nil then
            for k, v in pairs(backup) do FrameUnlockerDB[k] = v end
            self.restoredFromMirror = true
        end
    end
    -- A brand-new DB is already in the current format; stamp it so MigrateDB
    -- doesn't shift a coordinate that was never in the old scheme.
    local isNewDB = next(FrameUnlockerDB) == nil
    for k, v in pairs(self.defaults) do
        if FrameUnlockerDB[k] == nil then
            FrameUnlockerDB[k] = v
        end
    end
    if isNewDB then
        FrameUnlockerDB.lootFrameYIsBottom = true
    end
    MigrateDB(FrameUnlockerDB)
    self.db = FrameUnlockerDB
    WriteBackup(self.db)
end

-- Get a setting value
function FU:Get(key)
    return self.db and self.db[key]
end

-- Set a setting value (only allows known keys from defaults)
function FU:Set(key, value)
    if self.db and self.defaults[key] ~= nil then
        self.db[key] = value
        WriteBackup(self.db)
    end
end

-- Reset all settings to defaults
function FU:ResetToDefaults()
    if self.db then
        for k, v in pairs(self.defaults) do
            self.db[k] = v
        end
        WriteBackup(self.db)
    end
end
