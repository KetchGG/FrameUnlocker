-- FrameUnlocker Frames
-- Simple frame scaling: raid, party, and status bars

local addonName, FU = ...

function FU:ApplyRaidFrameScale(scale)
    if CompactRaidFrameContainer then
        CompactRaidFrameContainer:SetScale(scale or self:Get("raidFrameScale") or 1.0)
    end
end

function FU:ApplyPartyFrameScale(scale)
    scale = scale or self:Get("partyFrameScale") or 1.0
    local scaled = false

    -- Modern party frame container (Midnight/TBC Anniversary)
    if PartyFrame then
        PartyFrame:SetScale(scale)
        scaled = true
    end

    -- Compact party frame (raid-style party frames)
    if CompactPartyFrame then
        CompactPartyFrame:SetScale(scale)
        scaled = true
    end

    -- Legacy party member frames (Classic/older clients)
    if not scaled then
        for i = 1, 4 do
            local frame = _G["PartyMemberFrame" .. i]
            if frame then frame:SetScale(scale) end
        end
    end
end

function FU:ApplyStatusBarScale(scale)
    scale = scale or self:Get("statusBarScale") or 1.0

    -- Primary status bar container (bottom bar)
    if MainStatusTrackingBarContainer then
        MainStatusTrackingBarContainer:SetScale(scale)
    end

    -- Secondary status bar container (top bar)
    if SecondaryStatusTrackingBarContainer then
        SecondaryStatusTrackingBarContainer:SetScale(scale)
    end

    -- Fallback: StatusTrackingBarManager (older clients)
    if StatusTrackingBarManager and not MainStatusTrackingBarContainer then
        StatusTrackingBarManager:SetScale(scale)
    end
end
