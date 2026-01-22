-- FrameUnlocker Configuration
-- Handles defaults and saved variables initialization

-- Create addon namespace
local addonName, FU = ...
_G.FrameUnlocker = FU

-- Default settings
FU.defaults = {
    unlockChat = true,
    scaleRaidFrames = true,
    raidFrameScale = 0.8,
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

-- Set a setting value
function FU:Set(key, value)
    if self.db then
        self.db[key] = value
    end
end
