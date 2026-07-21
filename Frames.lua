-- FrameUnlocker Frames
-- Simple frame scaling: raid and party frames

local addonName, FU = ...

---------------------------------------------------------------------
-- Party vs raid frames
--
-- On TBC Anniversary / Retail these are separate hierarchies: party members live
-- under PartyFrame, raid members under CompactRaidFrameContainer. Scaling them
-- independently is straightforward.
--
-- Classic Era has no PartyFrame at all, and CompactPartyFrame is reparented onto
-- CompactRaidFrameContainer (Blizzard_CompactRaidFrameContainer.lua does an
-- unconditional groupFrame:SetParent(self) for the PARTY group). Scaling both
-- would compound, since frame scale is inherited multiplicatively.
--
-- What saves us is that Era never shows both at once -- the manager gates the
-- whole container on GetDisplayedAllyFrames(). So the container only ever needs
-- one scale at a time; which setting owns it depends on what it's currently
-- displaying:
--
--   GetDisplayedAllyFrames() == "party"            -> PartyMemberFrame1..4 shown
--   == "raid" and not IsInRaid()                   -> container shows PARTY members
--   == "raid" and IsInRaid()                       -> container shows RAID members
---------------------------------------------------------------------

-- True when this client routes party members through CompactRaidFrameContainer
-- rather than a dedicated party hierarchy (i.e. Classic Era with raid-style
-- party frames turned on).
local function PartyUsesRaidContainer()
    if PartyFrame then return false end  -- TBC/Retail: separate hierarchies
    if IsInRaid and IsInRaid() then return false end
    return GetDisplayedAllyFrames and GetDisplayedAllyFrames() == "raid"
end

-- Re-assert the container's scale from whichever setting currently owns it.
-- Called by the applier that does *not* own it, so switching between party and
-- raid can't leave the container stuck on the other context's scale (which it
-- otherwise would when only one of the two settings is enabled).
local function NormalizeRaidContainer(self)
    if not CompactRaidFrameContainer then return end
    local enableKey, scaleKey
    if PartyUsesRaidContainer() then
        enableKey, scaleKey = "scalePartyFrames", "partyFrameScale"
    else
        enableKey, scaleKey = "scaleRaidFrames", "raidFrameScale"
    end
    CompactRaidFrameContainer:SetScale((self:Get(enableKey) and self:Get(scaleKey)) or 1.0)
end

function FU:ApplyRaidFrameScale(scale)
    if not CompactRaidFrameContainer then return end

    -- The container is currently showing party members, so the party setting owns
    -- it; raid frames aren't on screen to scale.
    if PartyUsesRaidContainer() then
        NormalizeRaidContainer(self)
        return
    end

    CompactRaidFrameContainer:SetScale(scale or self:Get("raidFrameScale") or 1.0)
end

function FU:ApplyPartyFrameScale(scale)
    scale = scale or self:Get("partyFrameScale") or 1.0

    -- Modern party frame container (Midnight/TBC Anniversary)
    if PartyFrame then
        PartyFrame:SetScale(scale)
        return
    end

    -- Classic Era, raid-style party frames: party members render through the raid
    -- container. Scale the container and keep CompactPartyFrame at 1.0 so the two
    -- don't multiply.
    if PartyUsesRaidContainer() then
        if CompactPartyFrame then CompactPartyFrame:SetScale(1.0) end
        if CompactRaidFrameContainer then CompactRaidFrameContainer:SetScale(scale) end
        return
    end

    -- Legacy party member frames (Classic Era default, older clients).
    -- Deliberately not gated on CompactPartyFrame being absent: that global is
    -- generated lazily on the first group layout and never torn down, so its mere
    -- existence says nothing about which frames are actually on screen.
    for i = 1, 4 do
        local frame = _G["PartyMemberFrame" .. i]
        if frame then frame:SetScale(scale) end
    end

    -- We don't own the container in this state; make sure it isn't still carrying
    -- a party scale from before the group type changed.
    NormalizeRaidContainer(self)
end
