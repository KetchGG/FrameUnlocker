-- FrameUnlocker Anchors
-- Draggable anchor system for repositionable frames:
-- loot rolls, arena/flag carriers, quest tracker, raid warnings

local addonName, FU = ...

-- "BackdropTemplate" only exists as a registered template on Retail (post-Shadowlands).
-- Classic Era frames have SetBackdrop natively, so we pass nil and rely on the
-- if anchor.SetBackdrop guard below instead of the mixin.
local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

-- Slider template with backdrop on modern clients (matches the options panel).
local anchorSliderTemplate = BackdropTemplateMixin
    and "OptionsSliderTemplate, BackdropTemplate" or "OptionsSliderTemplate"

---------------------------------------------------------------------
-- Shared draggable anchor factory
--
-- Each anchor carries its own scale slider so scale can be tweaked while
-- positioning without returning to the options panel, and a Lock button that
-- saves the position and reopens the panel (see the move/lock flow in Options).
---------------------------------------------------------------------

-- opts fields: name, width, height, point, relPoint, x, y,
--   bgColor {r,g,b,a}, borderColor {r,g,b,a}, label,
--   scaleKey (setting key), applyScale (FU method), onLock, onDragStop
local function CreatePositionAnchor(opts)
    local anchor = CreateFrame("Frame", opts.name, UIParent, backdropTemplate)
    anchor:SetSize(opts.width, opts.height)
    anchor:SetPoint(opts.point, UIParent, opts.relPoint, opts.x, opts.y)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:Hide()

    if anchor.SetBackdrop then
        anchor:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        local bg = opts.bgColor
        local br = opts.borderColor
        anchor:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        anchor:SetBackdropBorderColor(br[1], br[2], br[3], br[4])
    end

    -- Span the label across the anchor width (both sides) so long names wrap to a
    -- second line and stay centered instead of spilling past the edges. The two-point
    -- anchor tracks SetSize, so this holds when Show* resizes the anchor.
    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 8, -10)
    label:SetPoint("TOPRIGHT", -8, -10)
    label:SetJustifyH("CENTER")
    label:SetText(opts.label)

    -- Scale slider: adjust the frame's scale in place. Anchored below the label so
    -- it follows a one- or two-line title.
    local scaleText = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleText:SetPoint("TOP", label, "BOTTOM", 0, -6)
    scaleText:SetText("Scale: 100%")

    local scaleRefreshing = false
    local scaleSlider = CreateFrame("Slider", nil, anchor, anchorSliderTemplate)
    scaleSlider:SetPoint("TOP", scaleText, "BOTTOM", 0, -6)
    scaleSlider:SetSize(140, 16)
    scaleSlider:SetMinMaxValues(0.5, 1.5)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    if scaleSlider.SetBackdrop then
        scaleSlider:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 }
        })
    end
    if scaleSlider.Low  then scaleSlider.Low:SetText("")  end
    if scaleSlider.High then scaleSlider.High:SetText("") end
    if scaleSlider.Text then scaleSlider.Text:SetText("") end

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        if scaleRefreshing then return end
        value = math.floor(value * 20 + 0.5) / 20
        FU:Set(opts.scaleKey, value)
        scaleText:SetText("Scale: " .. math.floor(value * 100) .. "%")
        opts.applyScale(FU, value)
    end)

    -- Sync the slider to the saved scale each time the anchor is shown.
    anchor:HookScript("OnShow", function()
        scaleRefreshing = true
        local s = FU:Get(opts.scaleKey) or 1.0
        scaleSlider:SetValue(s)
        scaleText:SetText("Scale: " .. math.floor(s * 100) .. "%")
        scaleRefreshing = false
    end)

    -- Lock: run the per-feature save/hide, then reopen the options panel.
    local lockBtn = CreateFrame("Button", nil, anchor, "UIPanelButtonTemplate")
    lockBtn:SetSize(90, 22)
    lockBtn:SetPoint("BOTTOM", 0, 8)
    lockBtn:SetText("Lock")
    lockBtn:SetScript("OnClick", function()
        opts.onLock()
        FU:OpenOptions()
    end)

    anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        opts.onDragStop(self)
    end)

    return anchor
end

---------------------------------------------------------------------
-- Per-anchor position save helpers (shared by OnDragStop and Hide)
---------------------------------------------------------------------

-- Loot rolls are stored as the BOTTOM-centre of the roll stack, offset from
-- UIParent's centre. Bottom rather than centre because Blizzard's container grows
-- upward as rolls stack up -- anchoring the bottom keeps the first roll put and
-- lets the rest pile on above it, instead of the whole stack shifting each time a
-- roll appears or expires.
local function saveLootPosition(anchor)
    local x = anchor:GetCenter()
    local bottom = anchor:GetBottom()
    if not x or not bottom then return end
    local uiX, uiY = UIParent:GetCenter()
    FU:Set("lootFrameX", x - uiX)
    FU:Set("lootFrameY", bottom - uiY)
    FU:ApplyLootFramePosition()
end

-- Offsets are stored relative to UIParent's matching edge (right/top here, since
-- these anchor TOPRIGHT), consistent with the raid-warning save below.
local function saveArenaPosition(anchor)
    local right = anchor:GetRight()
    local top   = anchor:GetTop()
    if not right then return end
    FU:Set("arenaFrameX", right - UIParent:GetRight())
    FU:Set("arenaFrameY", top   - UIParent:GetTop())
    FU:ApplyArenaFramePosition()
end

local function saveQuestTrackerPosition(anchor)
    local right = anchor:GetRight()
    local top   = anchor:GetTop()
    if not right then return end
    FU:Set("questTrackerX", right - UIParent:GetRight())
    FU:Set("questTrackerY", top   - UIParent:GetTop())
    FU:ApplyQuestTrackerPosition()
end

local function saveRaidWarningPosition(anchor)
    local x   = anchor:GetCenter()
    local top = anchor:GetTop()
    if not x then return end
    local uiX = UIParent:GetCenter()
    FU:Set("raidWarningX", x   - uiX)
    FU:Set("raidWarningY", top - UIParent:GetTop())
    FU:ApplyRaidWarningPosition()
end

---------------------------------------------------------------------
-- Shared SetPoint hook
-- Reapply our saved position shortly after Blizzard moves a frame, debounced so a
-- burst of SetPoint calls coalesces into a single reapply. Per-feature differences
-- (frame, keys, flags, debounce delay) come in via `spec`:
--   frame, hookedFlag, repositioningFlag, enableKey, xKey, yKey, apply (FU method), delay
---------------------------------------------------------------------

local function HookFramePosition(spec)
    local frame = spec.frame
    if not frame or FU[spec.hookedFlag] then return end
    local pending = false
    hooksecurefunc(frame, "SetPoint", function()
        if FU[spec.repositioningFlag] then return end
        if not FU:Get(spec.enableKey) then return end
        local x, y = FU:Get(spec.xKey), FU:Get(spec.yKey)
        if x and x ~= false and y and y ~= false and not pending then
            pending = true
            C_Timer.After(spec.delay, function()
                pending = false
                spec.apply(FU)
            end)
        end
    end)
    FU[spec.hookedFlag] = true
end

---------------------------------------------------------------------
-- Scale-aware SetPoint offset
--
-- Saved offsets are measured in UIParent space: the drag anchor is an unscaled
-- UIParent child, so its GetRight()/GetTop()/GetCenter() differences are in
-- UIParent's coordinate space. But SetPoint interprets its x/y offsets in the
-- *anchored frame's own* coordinate space (its effective scale). A frame with
-- SetScale(S) therefore lands S times too far from the anchor corner -- the
-- misalignment gets worse the further you scale from 1.0.
--
-- Convert by the ratio of effective scales so the frame's corner lands at the
-- saved screen position regardless of its scale. Read live from the frame, so it
-- stays correct across UI-scale changes and non-UIParent parents; this is why
-- Apply*Scale re-applies position (the ratio changes when the frame is rescaled).
---------------------------------------------------------------------

local function ScaledOffset(frame, x, y)
    local fs = frame:GetEffectiveScale()
    if not fs or fs == 0 then return x, y end
    local ratio = UIParent:GetEffectiveScale() / fs
    return x * ratio, y * ratio
end

---------------------------------------------------------------------
-- Loot Roll Frame Anchor and Scaling
---------------------------------------------------------------------

function FU:CreateLootAnchor()
    if self.lootAnchor then return self.lootAnchor end
    self.lootAnchor = CreatePositionAnchor({
        name        = "FULootAnchor",
        width       = 240, height = 108,
        point       = "CENTER", relPoint = "CENTER", x = 0, y = 0,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Loot Roll Anchor",
        scaleKey    = "lootFrameScale", applyScale = FU.ApplyLootFrameScale,
        onLock = function()
            FU:HideLootAnchor()
            if FU.optionsPanel and FU.optionsPanel.lootAnchorButton then
                FU.optionsPanel.lootAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveLootPosition,
    })
    return self.lootAnchor
end

function FU:ShowLootAnchor()
    local anchor = self:CreateLootAnchor()
    local x = self:Get("lootFrameX")
    local y = self:Get("lootFrameY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("BOTTOM", UIParent, "CENTER", x, y)
    else
        -- Default to where GroupLootContainer usually is
        anchor:SetPoint("BOTTOM", UIParent, "CENTER", 0, -100)
    end
    -- Size to one loot roll item; GroupLootFrame1 may not exist until a roll is active
    local ref = GroupLootFrame1
    local w = (ref and ref:GetWidth()  > 0) and ref:GetWidth()  or 300
    local h = (ref and ref:GetHeight() > 0) and ref:GetHeight() or 60
    anchor:SetSize(math.max(w, 240), math.max(h, 108))
    anchor:Show()
    self:Print("Drag the anchor to reposition loot roll frames. Click 'Lock' when done.")
end

function FU:HideLootAnchor()
    if self.lootAnchor then
        saveLootPosition(self.lootAnchor)
        self.lootAnchor:Hide()
        self:Print("Loot roll frame position saved.")
    end
end

function FU:ToggleLootAnchor()
    if self.lootAnchor and self.lootAnchor:IsShown() then
        self:HideLootAnchor()
        return false
    else
        self:ShowLootAnchor()
        return true
    end
end

function FU:ApplyLootFramePosition()
    if not self:Get("scaleLootFrames") then return end

    local x = self:Get("lootFrameX")
    local y = self:Get("lootFrameY")
    if not x or x == false or not y or y == false then return end

    local c = GroupLootContainer
    if c then
        -- Flag prevents the SetPoint hook below from re-triggering us
        self.lootFrameRepositioning = true

        -- GroupLootContainer is a managed frame (UIParentBottomManagedFrameTemplate):
        -- its OnShow re-adds itself to the bottom managed layout, which snaps it back
        -- to the default spot every time a roll appears (the stutter). Detach it so
        -- our position sticks -- ignoreFramePositionManager makes AddManagedFrame
        -- skip it, and RemoveManagedFrame pulls it out of the layout right now.
        c.ignoreFramePositionManager = true
        if c.layoutParent and c.layoutParent.RemoveManagedFrame then
            c.layoutParent:RemoveManagedFrame(c)
        end

        c:ClearAllPoints()
        -- BOTTOM, so the stack grows upward as rolls accumulate (see saveLootPosition)
        local ox, oy = ScaledOffset(c, x, y)
        c:SetPoint("BOTTOM", UIParent, "CENTER", ox, oy)
        self.lootFrameRepositioning = false
    end
end

local function ResetLootContainerToDefault()
    local c = GroupLootContainer
    if not c then return end

    -- Hand the container back to Blizzard's managed layout.
    c.ignoreFramePositionManager = nil
    c:ClearAllPoints()
    if c.layoutParent and c.layoutParent.AddManagedFrame and c:IsShown() then
        c.layoutParent:AddManagedFrame(c)  -- re-anchor to the managed default now
    else
        c:SetPoint("BOTTOM", UIParent, "CENTER", 0, -100)  -- fallback until next roll
    end
end

function FU:ResetLootFrameToDefault()
    ResetLootContainerToDefault()
end

function FU:ResetLootFramePosition()
    self:Set("lootFrameX", false)
    self:Set("lootFrameY", false)
    self:Set("lootFrameScale", 1.0)

    if self.lootAnchor and self.lootAnchor:IsShown() then
        self.lootAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.lootAnchorButton then
            self.optionsPanel.lootAnchorButton:SetText("Move")
        end
    end

    self:ApplyLootFrameScale(1.0)
    ResetLootContainerToDefault()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Loot frame reset to default.")
end

function FU:ApplyLootFrameScale(scale)
    scale = scale or self:Get("lootFrameScale") or 1.0

    if GroupLootContainer then
        GroupLootContainer:SetScale(scale)
    end

    -- Fallback: scale individual frames if container doesn't exist
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame then frame:SetScale(scale) end
    end

    -- Scale changes the offset ratio (see ScaledOffset), so reapply position.
    self:ApplyLootFramePosition()
end

function FU:HookLootFramePosition()
    HookFramePosition({
        frame = GroupLootContainer, hookedFlag = "lootFrameHooked",
        repositioningFlag = "lootFrameRepositioning", enableKey = "scaleLootFrames",
        xKey = "lootFrameX", yKey = "lootFrameY",
        -- next frame: a longer delay leaves the container visibly parked at
        -- Blizzard's position before we correct it, which reads as a flicker
        apply = FU.ApplyLootFramePosition, delay = 0,
    })
end

---------------------------------------------------------------------
-- Arena / Flag Carrier Frame Anchor and Scaling
---------------------------------------------------------------------

function FU:CreateArenaAnchor()
    if self.arenaAnchor then return self.arenaAnchor end
    self.arenaAnchor = CreatePositionAnchor({
        name        = "FUArenaAnchor",
        width       = 240, height = 108,
        point       = "TOPRIGHT", relPoint = "TOPRIGHT", x = -100, y = -200,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Arena/Flag Carrier Anchor",
        scaleKey    = "arenaFrameScale", applyScale = FU.ApplyArenaFrameScale,
        onLock = function()
            FU:HideArenaAnchor()
            if FU.optionsPanel and FU.optionsPanel.arenaAnchorButton then
                FU.optionsPanel.arenaAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveArenaPosition,
    })
    return self.arenaAnchor
end

function FU:ShowArenaAnchor()
    local anchor = self:CreateArenaAnchor()
    local x = self:Get("arenaFrameX")
    local y = self:Get("arenaFrameY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    else
        -- Default to right side where arena frames usually appear
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -200)
    end
    -- Size to 3 stacked enemy frames; individual frames may not exist outside arena
    local ref = _G["ArenaEnemyFrame1"]
    local frameW = (ref and ref:GetWidth()  > 0) and ref:GetWidth()  or 235
    local frameH = (ref and ref:GetHeight() > 0) and ref:GetHeight() or 18
    anchor:SetSize(math.max(frameW, 240), math.max(frameH * 3 + 4, 108))
    anchor:Show()
    self:Print("Drag the anchor to reposition arena/flag carrier frames. Click 'Lock' when done.")
end

function FU:HideArenaAnchor()
    if self.arenaAnchor then
        saveArenaPosition(self.arenaAnchor)
        self.arenaAnchor:Hide()
        self:Print("Arena/flag carrier frame position saved.")
    end
end

function FU:ToggleArenaAnchor()
    if self.arenaAnchor and self.arenaAnchor:IsShown() then
        self:HideArenaAnchor()
        return false
    else
        self:ShowArenaAnchor()
        return true
    end
end

function FU:ApplyArenaFramePosition()
    if not self:Get("scaleArenaFrames") then return end

    local x = self:Get("arenaFrameX")
    local y = self:Get("arenaFrameY")
    if not x or x == false or not y or y == false then return end
    if not ArenaEnemyFrames then return end

    -- ArenaEnemyFrames is secure; moving it is blocked in combat (and arena/BG
    -- combat is exactly when these appear). Defer to combat end.
    if self:InCombat() then
        self:DeferToCombatEnd("arenaPosition", function() self:ApplyArenaFramePosition() end)
        return
    end

    self.arenaFrameRepositioning = true
    ArenaEnemyFrames:ClearAllPoints()
    local ox, oy = ScaledOffset(ArenaEnemyFrames, x, y)
    ArenaEnemyFrames:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", ox, oy)
    self.arenaFrameRepositioning = false
end

local function ResetArenaContainerToDefault()
    if not ArenaEnemyFrames then return end

    -- Same combat restriction as ApplyArenaFramePosition. Shares the "arenaPosition"
    -- key so a queued apply and a queued reset don't both run at combat end -- the
    -- last thing the user asked for wins.
    if FU:InCombat() then
        FU:DeferToCombatEnd("arenaPosition", ResetArenaContainerToDefault)
        return
    end

    ArenaEnemyFrames:ClearAllPoints()
    ArenaEnemyFrames:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -200)
end

function FU:ResetArenaFrameToDefault()
    ResetArenaContainerToDefault()
end

function FU:ResetArenaFramePosition()
    self:Set("arenaFrameX", false)
    self:Set("arenaFrameY", false)
    self:Set("arenaFrameScale", 1.0)

    if self.arenaAnchor and self.arenaAnchor:IsShown() then
        self.arenaAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.arenaAnchorButton then
            self.optionsPanel.arenaAnchorButton:SetText("Move")
        end
    end

    self:ApplyArenaFrameScale(1.0)
    ResetArenaContainerToDefault()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Arena/flag carrier frame reset to default.")
end

function FU:ApplyArenaFrameScale(scale)
    scale = scale or self:Get("arenaFrameScale") or 1.0

    if ArenaEnemyFrames then
        ArenaEnemyFrames:SetScale(scale)
    end

    -- Fallback: scale individual frames if container doesn't exist
    for i = 1, 5 do
        local frame = _G["ArenaEnemyFrame" .. i]
        if frame then frame:SetScale(scale) end
    end

    -- Scale changes the offset ratio (see ScaledOffset), so reapply position.
    self:ApplyArenaFramePosition()
end

function FU:HookArenaFramePosition()
    HookFramePosition({
        frame = ArenaEnemyFrames, hookedFlag = "arenaFrameHooked",
        repositioningFlag = "arenaFrameRepositioning", enableKey = "scaleArenaFrames",
        xKey = "arenaFrameX", yKey = "arenaFrameY",
        apply = FU.ApplyArenaFramePosition, delay = 0.1,
    })
end

---------------------------------------------------------------------
-- Quest Tracker Anchor and Scaling
---------------------------------------------------------------------

-- Get the quest tracker frame (different names across client versions)
local function GetQuestTrackerFrame()
    return ObjectiveTrackerFrame or QuestWatchFrame
end

function FU:CreateQuestTrackerAnchor()
    if self.questTrackerAnchor then return self.questTrackerAnchor end
    self.questTrackerAnchor = CreatePositionAnchor({
        name        = "FUQuestTrackerAnchor",
        width       = 240, height = 108,
        point       = "TOPRIGHT", relPoint = "TOPRIGHT", x = -50, y = -200,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Quest Tracker Anchor",
        scaleKey    = "questTrackerScale", applyScale = FU.ApplyQuestTrackerScale,
        onLock = function()
            FU:HideQuestTrackerAnchor()
            if FU.optionsPanel and FU.optionsPanel.questTrackerAnchorButton then
                FU.optionsPanel.questTrackerAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveQuestTrackerPosition,
    })
    return self.questTrackerAnchor
end

function FU:ShowQuestTrackerAnchor()
    local anchor = self:CreateQuestTrackerAnchor()
    local x = self:Get("questTrackerX")
    local y = self:Get("questTrackerY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    else
        -- Default position
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -200)
    end
    -- Read live tracker dimensions; guard > 10 filters frames not yet laid out
    local tracker = GetQuestTrackerFrame()
    local w = (tracker and tracker:GetWidth()  > 10) and tracker:GetWidth()  or 240
    local h = (tracker and tracker:GetHeight() > 10) and tracker:GetHeight() or 150
    anchor:SetSize(math.max(w, 240), math.max(h, 108))
    anchor:Show()
    self:Print("Drag the anchor to reposition quest tracker. Click 'Lock' when done.")
end

function FU:HideQuestTrackerAnchor()
    if self.questTrackerAnchor then
        saveQuestTrackerPosition(self.questTrackerAnchor)
        self.questTrackerAnchor:Hide()
        self:Print("Quest tracker position saved.")
    end
end

function FU:ToggleQuestTrackerAnchor()
    if self.questTrackerAnchor and self.questTrackerAnchor:IsShown() then
        self:HideQuestTrackerAnchor()
        return false
    else
        self:ShowQuestTrackerAnchor()
        return true
    end
end

function FU:ApplyQuestTrackerPosition()
    if not self:Get("scaleQuestTracker") then return end

    local x = self:Get("questTrackerX")
    local y = self:Get("questTrackerY")
    if not x or x == false or not y or y == false then return end

    local tracker = GetQuestTrackerFrame()
    if not tracker then return end

    -- Reparenting / SetPoint on the managed objective tracker is blocked in combat.
    if self:InCombat() then
        self:DeferToCombatEnd("questTrackerPosition", function() self:ApplyQuestTrackerPosition() end)
        return
    end

    self.questTrackerRepositioning = true

    -- Removed from Blizzard's managed layout system to prevent flickering
    -- when the tracker is repositioned; restored to defaults on reset.
    tracker.isManagedFrame = false
    tracker.isRightManagedFrame = false

    if tracker:GetParent() ~= UIParent then
        tracker:SetParent(UIParent)
    end

    tracker:ClearAllPoints()
    local ox, oy = ScaledOffset(tracker, x, y)
    tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", ox, oy)
    self.questTrackerRepositioning = false
end

local function ResetQuestTrackerInternal()
    local tracker = GetQuestTrackerFrame()
    if not tracker then return end

    -- Reparenting the tracker back under the managed container is blocked in combat,
    -- same as ApplyQuestTrackerPosition. Shares that applier's deferral key so an
    -- apply and a reset can't both be queued for combat end.
    if FU:InCombat() then
        FU:DeferToCombatEnd("questTrackerPosition", ResetQuestTrackerInternal)
        return
    end

    tracker.isManagedFrame = true
    tracker.isRightManagedFrame = true

    if UIParentRightManagedFrameContainer then
        tracker:SetParent(UIParentRightManagedFrameContainer)
    end

    tracker:ClearAllPoints()
    tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -200)
end

function FU:ResetQuestTrackerToDefault()
    ResetQuestTrackerInternal()
end

function FU:ResetQuestTrackerPosition()
    self:Set("questTrackerX", false)
    self:Set("questTrackerY", false)
    self:Set("questTrackerScale", 1.0)

    if self.questTrackerAnchor and self.questTrackerAnchor:IsShown() then
        self.questTrackerAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.questTrackerAnchorButton then
            self.optionsPanel.questTrackerAnchorButton:SetText("Move")
        end
    end

    self:ApplyQuestTrackerScale(1.0)
    ResetQuestTrackerInternal()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Quest tracker reset to default.")
end

function FU:ApplyQuestTrackerScale(scale)
    scale = scale or self:Get("questTrackerScale") or 1.0
    local tracker = GetQuestTrackerFrame()
    if tracker then
        tracker:SetScale(scale)
    end

    -- Scale changes the offset ratio (see ScaledOffset), so reapply position.
    self:ApplyQuestTrackerPosition()
end

function FU:HookQuestTrackerPosition()
    HookFramePosition({
        frame = GetQuestTrackerFrame(), hookedFlag = "questTrackerHooked",
        repositioningFlag = "questTrackerRepositioning", enableKey = "scaleQuestTracker",
        xKey = "questTrackerX", yKey = "questTrackerY",
        apply = FU.ApplyQuestTrackerPosition,
        delay = 0,  -- next frame: minimal delay to reduce tracker flicker
    })
end

---------------------------------------------------------------------
-- Raid Warning Frame Anchor and Scaling
---------------------------------------------------------------------

function FU:CreateRaidWarningAnchor()
    if self.raidWarningAnchor then return self.raidWarningAnchor end
    self.raidWarningAnchor = CreatePositionAnchor({
        name        = "FURaidWarningAnchor",
        width       = 260, height = 108,
        point       = "TOP", relPoint = "TOP", x = 0, y = -200,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Raid Warning / Death Alert Anchor",
        scaleKey    = "raidWarningScale", applyScale = FU.ApplyRaidWarningScale,
        onLock = function()
            FU:HideRaidWarningAnchor()
            if FU.optionsPanel and FU.optionsPanel.raidWarningAnchorButton then
                FU.optionsPanel.raidWarningAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveRaidWarningPosition,
    })
    return self.raidWarningAnchor
end

function FU:ShowRaidWarningAnchor()
    local anchor = self:CreateRaidWarningAnchor()
    local x = self:Get("raidWarningX")
    local y = self:Get("raidWarningY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("TOP", UIParent, "TOP", x, y)
    else
        anchor:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
    -- RaidWarningFrame is a fixed-size container; read its dimensions directly
    local w = (RaidWarningFrame and RaidWarningFrame:GetWidth()  > 0) and RaidWarningFrame:GetWidth()  or 500
    local h = (RaidWarningFrame and RaidWarningFrame:GetHeight() > 0) and RaidWarningFrame:GetHeight() or 50
    anchor:SetSize(math.max(w, 240), math.max(h, 108))
    anchor:Show()
    self:Print("Drag the anchor to reposition raid warnings / death alerts. Click 'Lock' when done.")
end

function FU:HideRaidWarningAnchor()
    if self.raidWarningAnchor then
        saveRaidWarningPosition(self.raidWarningAnchor)
        self.raidWarningAnchor:Hide()
        self:Print("Raid warning position saved.")
    end
end

function FU:ToggleRaidWarningAnchor()
    if self.raidWarningAnchor and self.raidWarningAnchor:IsShown() then
        self:HideRaidWarningAnchor()
        return false
    else
        self:ShowRaidWarningAnchor()
        return true
    end
end

function FU:ApplyRaidWarningScale(scale)
    scale = scale or self:Get("raidWarningScale") or 1.0
    if RaidWarningFrame then
        RaidWarningFrame:SetScale(scale)
    end

    -- Scale changes the offset ratio (see ScaledOffset), so reapply position.
    self:ApplyRaidWarningPosition()
end

function FU:ApplyRaidWarningPosition()
    if not self:Get("scaleRaidWarnings") then return end

    local x = self:Get("raidWarningX")
    local y = self:Get("raidWarningY")
    if not x or x == false or not y or y == false then return end

    if RaidWarningFrame then
        self.raidWarningRepositioning = true
        RaidWarningFrame:ClearAllPoints()
        local ox, oy = ScaledOffset(RaidWarningFrame, x, y)
        RaidWarningFrame:SetPoint("TOP", UIParent, "TOP", ox, oy)
        self.raidWarningRepositioning = false
    end
end

function FU:ResetRaidWarningToDefault()
    if RaidWarningFrame then
        RaidWarningFrame:ClearAllPoints()
        RaidWarningFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    end
end

function FU:ResetRaidWarningPosition()
    self:Set("raidWarningX", false)
    self:Set("raidWarningY", false)
    self:Set("raidWarningScale", 1.0)

    if self.raidWarningAnchor and self.raidWarningAnchor:IsShown() then
        self.raidWarningAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.raidWarningAnchorButton then
            self.optionsPanel.raidWarningAnchorButton:SetText("Move")
        end
    end

    self:ApplyRaidWarningScale(1.0)
    self:ResetRaidWarningToDefault()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Raid warning position reset to default.")
end

function FU:HookRaidWarningPosition()
    HookFramePosition({
        frame = RaidWarningFrame, hookedFlag = "raidWarningHooked",
        repositioningFlag = "raidWarningRepositioning", enableKey = "scaleRaidWarnings",
        xKey = "raidWarningX", yKey = "raidWarningY",
        apply = FU.ApplyRaidWarningPosition, delay = 0,
    })
end

---------------------------------------------------------------------
-- Below-Minimap Widget Container (world/PvP objective displays)
--
-- UIWidgetBelowMinimapContainerFrame is a *managed* frame: it inherits
-- UIParentRightManagedFrameTemplate and is laid out by
-- UIParentRightManagedFrameContainer (the same system as the objective/quest
-- tracker). Like the tracker, we must remove it from that managed layout before
-- we can freely position it, and restore it on reset -- otherwise Blizzard's
-- layout keeps yanking it back (flicker). Reparenting is blocked in combat, so
-- ApplyBelowMinimapPosition defers like the tracker does.
---------------------------------------------------------------------

local function saveBelowMinimapPosition(anchor)
    local right = anchor:GetRight()
    local top   = anchor:GetTop()
    if not right then return end
    FU:Set("belowMinimapX", right - UIParent:GetRight())
    FU:Set("belowMinimapY", top   - UIParent:GetTop())
    FU:ApplyBelowMinimapPosition()
end

function FU:CreateBelowMinimapAnchor()
    if self.belowMinimapAnchor then return self.belowMinimapAnchor end
    self.belowMinimapAnchor = CreatePositionAnchor({
        name        = "FUBelowMinimapAnchor",
        width       = 240, height = 108,
        point       = "TOPRIGHT", relPoint = "TOPRIGHT", x = -50, y = -220,
        bgColor     = { 0.07, 0.29, 0.18, 0.85 },
        borderColor = { 0.17, 0.71, 0.45, 1.0  },
        label       = "Below-Minimap Widget Anchor",
        scaleKey    = "belowMinimapScale", applyScale = FU.ApplyBelowMinimapScale,
        onLock = function()
            FU:HideBelowMinimapAnchor()
            if FU.optionsPanel and FU.optionsPanel.belowMinimapAnchorButton then
                FU.optionsPanel.belowMinimapAnchorButton:SetText("Move")
            end
        end,
        onDragStop = saveBelowMinimapPosition,
    })
    return self.belowMinimapAnchor
end

function FU:ShowBelowMinimapAnchor()
    local anchor = self:CreateBelowMinimapAnchor()
    local x = self:Get("belowMinimapX")
    local y = self:Get("belowMinimapY")
    anchor:ClearAllPoints()
    if x and x ~= false and y and y ~= false then
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    else
        anchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -220)
    end
    local f = UIWidgetBelowMinimapContainerFrame
    local w = (f and f:GetWidth()  > 0) and f:GetWidth()  or 200
    local h = (f and f:GetHeight() > 0) and f:GetHeight() or 44
    anchor:SetSize(math.max(w, 240), math.max(h, 108))
    anchor:Show()
    self:Print("Drag the anchor to reposition the below-minimap widgets. Click 'Lock' when done.")
end

function FU:HideBelowMinimapAnchor()
    if self.belowMinimapAnchor then
        saveBelowMinimapPosition(self.belowMinimapAnchor)
        self.belowMinimapAnchor:Hide()
        self:Print("Below-minimap widget position saved.")
    end
end

function FU:ToggleBelowMinimapAnchor()
    if self.belowMinimapAnchor and self.belowMinimapAnchor:IsShown() then
        self:HideBelowMinimapAnchor()
        return false
    else
        self:ShowBelowMinimapAnchor()
        return true
    end
end

function FU:ApplyBelowMinimapScale(scale)
    scale = scale or self:Get("belowMinimapScale") or 1.0
    if UIWidgetBelowMinimapContainerFrame then
        UIWidgetBelowMinimapContainerFrame:SetScale(scale)
    end

    -- Scale changes the offset ratio (see ScaledOffset), so reapply position.
    self:ApplyBelowMinimapPosition()
end

function FU:ApplyBelowMinimapPosition()
    if not self:Get("scaleBelowMinimap") then return end

    local x = self:Get("belowMinimapX")
    local y = self:Get("belowMinimapY")
    if not x or x == false or not y or y == false then return end

    local f = UIWidgetBelowMinimapContainerFrame
    if not f then return end

    -- Reparenting / SetPoint on the managed container is blocked in combat.
    if self:InCombat() then
        self:DeferToCombatEnd("belowMinimapPosition", function() self:ApplyBelowMinimapPosition() end)
        return
    end

    self.belowMinimapRepositioning = true

    -- Remove from Blizzard's managed layout so it stops re-anchoring (see tracker).
    f.isManagedFrame = false
    f.isRightManagedFrame = false
    if f:GetParent() ~= UIParent then
        f:SetParent(UIParent)
    end

    f:ClearAllPoints()
    local ox, oy = ScaledOffset(f, x, y)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", ox, oy)
    self.belowMinimapRepositioning = false
end

local function ResetBelowMinimapInternal()
    local f = UIWidgetBelowMinimapContainerFrame
    if not f then return end

    -- Restoring managed status reparents it in combat, same block as the tracker.
    if FU:InCombat() then
        FU:DeferToCombatEnd("belowMinimapPosition", ResetBelowMinimapInternal)
        return
    end

    f.isManagedFrame = true
    f.isRightManagedFrame = true

    if UIParentRightManagedFrameContainer then
        f:SetParent(UIParentRightManagedFrameContainer)
    end

    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -220)
end

function FU:ResetBelowMinimapToDefault()
    ResetBelowMinimapInternal()
end

function FU:ResetBelowMinimapPosition()
    self:Set("belowMinimapX", false)
    self:Set("belowMinimapY", false)
    self:Set("belowMinimapScale", 1.0)

    if self.belowMinimapAnchor and self.belowMinimapAnchor:IsShown() then
        self.belowMinimapAnchor:Hide()
        if self.optionsPanel and self.optionsPanel.belowMinimapAnchorButton then
            self.optionsPanel.belowMinimapAnchorButton:SetText("Move")
        end
    end

    self:ApplyBelowMinimapScale(1.0)
    ResetBelowMinimapInternal()

    if self.optionsPanel and self.optionsPanel.refresh then
        self.optionsPanel.refresh()
    end

    self:Print("Below-minimap widgets reset to default.")
end

function FU:HookBelowMinimapPosition()
    HookFramePosition({
        frame = UIWidgetBelowMinimapContainerFrame, hookedFlag = "belowMinimapHooked",
        repositioningFlag = "belowMinimapRepositioning", enableKey = "scaleBelowMinimap",
        xKey = "belowMinimapX", yKey = "belowMinimapY",
        apply = FU.ApplyBelowMinimapPosition, delay = 0,
    })
end

---------------------------------------------------------------------
-- Combined Bag Frame Unlock (direct drag, like the chat frame)
--
-- Unlike the anchor-based features above, this frame is dragged directly and
-- continuously while unlocked -- there's no proxy anchor to show/hide, matching
-- FU:UnlockChatFrame's model (Chat.lua) rather than CreatePositionAnchor's.
-- ContainerFrameCombinedBags only exists on Retail (the combined-bags view);
-- Classic Era/TBC/Forever show individual ContainerFrame1..N instead, which
-- this feature deliberately does not cover. It isn't secure or part of
-- Blizzard's managed frame layout, so no combat deferral or isManagedFrame
-- juggling is needed, unlike the quest tracker / below-minimap widgets.
---------------------------------------------------------------------

local function saveBagFramePosition(frame)
    local right = frame:GetRight()
    local bottom = frame:GetBottom()
    if not right or not bottom then return end
    FU:Set("bagFrameX", right  - UIParent:GetRight())
    FU:Set("bagFrameY", bottom - UIParent:GetBottom())
end

function FU:UnlockBagFrame()
    local f = ContainerFrameCombinedBags
    if not f then return end

    f:SetMovable(true)
    f:SetClampedToScreen(true)

    -- Drag from the header bar (TitleContainer), not the whole frame. The
    -- header is where players instinctively grab a window to move it, but it
    -- sits on top of the main frame and is also what opens the Bag Settings
    -- menu on click -- registering drag on the main frame never saw those
    -- clicks at all, they resolved as a header click before we got a look.
    -- RegisterForDrag on the header itself lets WoW tell a real drag apart
    -- from a plain click, so dragging now moves the frame while a plain click
    -- still does whatever the header already did. The portrait icon is a
    -- separate region layered on top of the header and is untouched either way.
    local header = f.TitleContainer
    if not header then return end

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")

    -- Only hook once to prevent stacking on repeated calls
    if not header.FU_BagDragHooked then
        header:HookScript("OnDragStart", function()
            if f:IsMovable() then f:StartMoving() end
        end)
        header:HookScript("OnDragStop", function()
            f:StopMovingOrSizing()
            saveBagFramePosition(f)
        end)
        header.FU_BagDragHooked = true
    end
end

function FU:LockBagFrame()
    local f = ContainerFrameCombinedBags
    if not f then return end

    f:SetMovable(false)
    if f.TitleContainer then
        -- Empty args clears all registered drag buttons; HookScript handlers
        -- remain but are guarded by the IsMovable() check in OnDragStart.
        f.TitleContainer:RegisterForDrag()
    end
end

function FU:ApplyBagFramePosition()
    if not self:Get("unlockBagFrame") then return end

    local x = self:Get("bagFrameX")
    local y = self:Get("bagFrameY")
    if not x or x == false or not y or y == false then return end

    local f = ContainerFrameCombinedBags
    if not f then return end

    self.bagFrameRepositioning = true
    f:ClearAllPoints()
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", x, y)
    self.bagFrameRepositioning = false
end

function FU:HookBagFramePosition()
    HookFramePosition({
        frame = ContainerFrameCombinedBags, hookedFlag = "bagFrameHooked",
        repositioningFlag = "bagFrameRepositioning", enableKey = "unlockBagFrame",
        xKey = "bagFrameX", yKey = "bagFrameY",
        apply = FU.ApplyBagFramePosition, delay = 0,
    })
end
