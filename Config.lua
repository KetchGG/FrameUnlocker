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
    scaleStatusBars = false,
    statusBarScale = 1.0,
    scaleLootFrames = false,
    lootFrameScale = 1.0,
    lootFrameX = false,  -- false = use default position
    lootFrameY = false,
}

-- Initialize saved variables
function FU:InitDB()
    if not FrameUnlockerDB then
        FrameUnlockerDB = {}
    end
    for k, v in pairs(self.defaults) do
        if FrameUnlockerDB[k] == nil then
            FrameUnlockerDB[k] = v
        end
    end
    self.db = FrameUnlockerDB
end

-- Get a setting value
function FU:Get(key)
    return self.db and self.db[key]
end

-- Set a setting value (only allows known keys from defaults)
function FU:Set(key, value)
    if self.db and self.defaults[key] ~= nil then
        self.db[key] = value
    end
end

-- Reset all settings to defaults
function FU:ResetToDefaults()
    if self.db then
        for k, v in pairs(self.defaults) do
            self.db[k] = v
        end
    end
end
