-- FrameUnlocker Options Panel
-- Settings UI for Blizzard addon options

local addonName, FU = ...

---------------------------------------------------------------------
-- Detect client API support (feature detection, not version check)
-- This handles retail, TBC Anniversary, and other clients correctly
---------------------------------------------------------------------

local hasSettingsAPI = (Settings and Settings.RegisterCanvasLayoutCategory) ~= nil

---------------------------------------------------------------------
-- Create the options panel
---------------------------------------------------------------------

function FU:CreateOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "FrameUnlocker"

    -- Flag to prevent OnValueChanged firing during refresh (used by slider)
    local isRefreshing = false

    -- Layout constants (4-column layout)
    local COL1 = 16
    local COL2 = 155
    local COL3 = 294
    local COL4 = 433
    local SLIDER_WIDTH = 120
    local SLIDER_HEIGHT = 15

    -- Get version from TOC (C_AddOns on modern clients, global on older ones)
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = (getMeta and getMeta(addonName, "Version")) or "?"

    -- Logo image
    local logoTexture = panel:CreateTexture(nil, "ARTWORK")
    logoTexture:SetSize(48, 48)
    logoTexture:SetPoint("TOPLEFT", 16, -12)
    logoTexture:SetTexture("Interface\\AddOns\\FrameUnlocker\\logo.png")

    -- Title text
    local logo = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    logo:SetPoint("TOPLEFT", logoTexture, "TOPRIGHT", 10, -2)
    logo:SetText("|cff2BB673Frame|r|cffffffffUnlocker|r")

    -- Version
    local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    versionText:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    versionText:SetText("|cff888888v" .. version .. "|r")

    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("Unlock and customize UI frames")

    -- Author credit
    local author = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    author:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -2)
    author:SetText("|cff888888by |cff2BB673Ketch|r")

    -- Classic Era compatibility note (top right)
    local compatNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    compatNote:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -16)
    compatNote:SetText("|cffFFD100* Not available in Classic Era|r")

    local yOffset = -80

    -- Helper to create a horizontal divider line
    local function CreateDivider(parent, yPos)
        local divider = parent:CreateTexture(nil, "ARTWORK")
        divider:SetHeight(1)
        divider:SetPoint("TOPLEFT", COL1, yPos)
        divider:SetPoint("TOPRIGHT", -16, yPos)
        divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        return divider
    end

    -- Helper to enable/disable a slider with visual feedback
    local function SetSliderEnabled(sldr, label, enabled)
        if enabled then
            sldr:Enable()
            sldr:SetAlpha(1.0)
            label:SetAlpha(1.0)
        else
            sldr:Disable()
            sldr:SetAlpha(0.5)
            label:SetAlpha(0.5)
        end
    end

    -- Create slider with BackdropTemplate for modern clients
    local sliderTemplate = "OptionsSliderTemplate"
    if BackdropTemplateMixin then
        sliderTemplate = "OptionsSliderTemplate, BackdropTemplate"
    end

    -- Helper to create a scaling control (checkbox + slider)
    local function CreateScaleControl(parent, xPos, yPos, label, settingKey, scaleKey, applyFunc)
        local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        check:SetPoint("TOPLEFT", xPos, yPos)
        check.Text:SetText(label)

        local sliderLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        sliderLabel:SetPoint("TOPLEFT", xPos + 4, yPos - 30)
        sliderLabel:SetText("Scale: 100%")

        local slider = CreateFrame("Slider", nil, parent, sliderTemplate)
        slider:SetPoint("TOPLEFT", xPos + 4, yPos - 50)
        slider:SetMinMaxValues(0.5, 1.5)
        slider:SetValueStep(0.05)
        slider:SetObeyStepOnDrag(true)
        slider:SetWidth(SLIDER_WIDTH)
        slider:SetHeight(SLIDER_HEIGHT)

        if slider.SetBackdrop then
            slider:SetBackdrop({
                bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                tile = true, tileSize = 8, edgeSize = 8,
                insets = { left = 3, right = 3, top = 6, bottom = 6 }
            })
        end

        -- These named regions are keyed members on modern OptionsSliderTemplate;
        -- guard in case an older client doesn't expose them on an unnamed slider.
        if slider.Low  then slider.Low:SetText("")  end
        if slider.High then slider.High:SetText("") end
        if slider.Text then slider.Text:SetText("") end

        slider:SetScript("OnValueChanged", function(self, value)
            if isRefreshing then return end
            value = math.floor(value * 20 + 0.5) / 20
            FU:Set(scaleKey, value)
            sliderLabel:SetText("Scale: " .. math.floor(value * 100) .. "%")
            if FU:Get(settingKey) then
                applyFunc(FU, value)
            end
        end)

        check:SetScript("OnClick", function(self)
            FU:Set(settingKey, self:GetChecked())
            SetSliderEnabled(slider, sliderLabel, self:GetChecked())
            if self:GetChecked() then
                applyFunc(FU)
            else
                applyFunc(FU, 1.0)
            end
        end)

        return check, slider, sliderLabel
    end

    -- Create the Move/Reset position buttons for a repositionable feature and wire
    -- its scale checkbox to enable/disable them and apply/clear the position.
    -- spec: check, anchorField, toggle, resetPosition, applyPosition, resetToDefault
    --   (the four action fields are FU methods). Returns the Move button and the
    --   enable function, for the caller to store on `panel` for refresh.
    local function CreatePositionControls(col, yPos, spec)
        local moveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        moveBtn:SetPoint("TOPLEFT", col, yPos)
        moveBtn:SetSize(55, 22)
        moveBtn:SetText("Move")
        moveBtn:SetScript("OnClick", function(self)
            local showing = spec.toggle(FU)
            self:SetText(showing and "Lock" or "Move")
            -- Close the panel when a frame is unlocked so the on-screen anchor is
            -- unobstructed; the anchor's Lock button reopens it (see Anchors.lua).
            if showing then FU:CloseOptions() end
        end)

        local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        resetBtn:SetPoint("LEFT", moveBtn, "RIGHT", 4, 0)
        resetBtn:SetSize(55, 22)
        resetBtn:SetText("Reset")
        resetBtn:SetScript("OnClick", function() spec.resetPosition(FU) end)

        local function setEnabled(enabled)
            local alpha = enabled and 1.0 or 0.5
            if enabled then moveBtn:Enable();  resetBtn:Enable()
            else            moveBtn:Disable(); resetBtn:Disable() end
            moveBtn:SetAlpha(alpha)
            resetBtn:SetAlpha(alpha)
        end

        spec.check:HookScript("OnClick", function(self)
            local enabled = self:GetChecked()
            setEnabled(enabled)
            if enabled then
                spec.applyPosition(FU)
            else
                local anchor = FU[spec.anchorField]
                if anchor and anchor:IsShown() then
                    anchor:Hide()
                    moveBtn:SetText("Move")
                end
                spec.resetToDefault(FU)
            end
        end)

        return moveBtn, setEnabled
    end

    ---------------------------------------------------------------------
    -- Draggable Frames Section (Chat, Combined Bags)
    ---------------------------------------------------------------------

    local chatHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chatHeader:SetPoint("TOPLEFT", COL1, yOffset)
    chatHeader:SetText("Draggable Frames")
    chatHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 18
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 12

    -- Chat unlock (column 1)
    local chatCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    chatCheck:SetPoint("TOPLEFT", COL1, yOffset)
    chatCheck.Text:SetText("Unlock chat frame")
    chatCheck:SetScript("OnClick", function(self)
        FU:Set("unlockChat", self:GetChecked())
        if self:GetChecked() then
            FU:UnlockChatFrame(ChatFrame1)
        else
            FU:LockChatFrame(ChatFrame1)
        end
    end)

    -- Chat description (on second line)
    local chatDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    chatDesc:SetPoint("TOPLEFT", COL1 + 26, yOffset - 20)
    chatDesc:SetText("|cff888888Drag by tab, resize from corner|r")

    -- Combined bag frame unlock (column 3, Retail only) -- direct-drag like the
    -- chat frame, not scale/anchor-based, so it's a plain checkbox + description.
    -- Column 3 (not 2) because the chat description above is a full sentence
    -- that needs more than the usual 139px column gap to avoid overlapping it.
    local bagFrameCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    bagFrameCheck:SetPoint("TOPLEFT", COL3, yOffset)
    bagFrameCheck.Text:SetText("Unlock combined bags*")
    bagFrameCheck:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        -- Set() runs before touching the live frame so the choice is saved even
        -- if the frame manipulation below errors (see the pcall in Init.lua's
        -- ReapplyScaling for why that's a real possibility with this frame).
        FU:Set("unlockBagFrame", checked)
        local ok, err = pcall(function()
            if checked then
                FU:UnlockBagFrame()
                FU:ApplyBagFramePosition()
            else
                FU:LockBagFrame()
            end
        end)
        if not ok then
            FU:Print("|cffff0000Combined bag frame error:|r " .. tostring(err))
        end
    end)

    local bagFrameDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bagFrameDesc:SetPoint("TOPLEFT", COL3 + 26, yOffset - 20)
    bagFrameDesc:SetText("|cff888888Drag by the header|r")

    yOffset = yOffset - 50

    ---------------------------------------------------------------------
    -- Group and Gameplay Frames Section (Raid, Party, Quest, Loot - 4 columns)
    ---------------------------------------------------------------------

    local groupHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    groupHeader:SetPoint("TOPLEFT", COL1, yOffset)
    groupHeader:SetText("Group and Gameplay Frames")
    groupHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 18
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 12

    -- Raid frames (column 1)
    local raidCheck, slider, sliderLabel = CreateScaleControl(
        panel, COL1, yOffset,
        "Raid frames", "scaleRaidFrames", "raidFrameScale",
        FU.ApplyRaidFrameScale
    )

    -- Party frames (column 2)
    local partyCheck, partySlider, partySliderLabel = CreateScaleControl(
        panel, COL2, yOffset,
        "Party frames", "scalePartyFrames", "partyFrameScale",
        FU.ApplyPartyFrameScale
    )

    -- Quest tracker (column 3)
    local questTrackerCheck, questTrackerSlider, questTrackerSliderLabel = CreateScaleControl(
        panel, COL3, yOffset,
        "Quest tracker", "scaleQuestTracker", "questTrackerScale",
        FU.ApplyQuestTrackerScale
    )

    -- Loot roll frames (column 4)
    local lootCheck, lootSlider, lootSliderLabel = CreateScaleControl(
        panel, COL4, yOffset,
        "Loot rolls", "scaleLootFrames", "lootFrameScale",
        FU.ApplyLootFrameScale
    )

    yOffset = yOffset - 90

    -- Move/Reset Quest Tracker buttons (under column 3)
    local questTrackerAnchorButton, SetQuestTrackerButtonsEnabled = CreatePositionControls(COL3, yOffset, {
        check = questTrackerCheck, anchorField = "questTrackerAnchor",
        toggle = FU.ToggleQuestTrackerAnchor, resetPosition = FU.ResetQuestTrackerPosition,
        applyPosition = FU.ApplyQuestTrackerPosition, resetToDefault = FU.ResetQuestTrackerToDefault,
    })

    -- Move/Reset Loot Frames buttons (under column 4)
    local lootAnchorButton, SetLootButtonsEnabled = CreatePositionControls(COL4, yOffset, {
        check = lootCheck, anchorField = "lootAnchor",
        toggle = FU.ToggleLootAnchor, resetPosition = FU.ResetLootFramePosition,
        applyPosition = FU.ApplyLootFramePosition, resetToDefault = FU.ResetLootFrameToDefault,
    })

    yOffset = yOffset - 35

    ---------------------------------------------------------------------
    -- PvP and Misc Section (Arena, PvP objectives, Below minimap, Raid warnings)
    ---------------------------------------------------------------------

    local miscHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    miscHeader:SetPoint("TOPLEFT", COL1, yOffset)
    miscHeader:SetText("PvP and Misc")
    miscHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 18
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 12

    -- Arena/Flag carrier frames (column 1)
    local arenaCheck, arenaSlider, arenaSliderLabel = CreateScaleControl(
        panel, COL1, yOffset,
        "Arena / Flags*", "scaleArenaFrames", "arenaFrameScale",
        FU.ApplyArenaFrameScale
    )

    -- Below-minimap widgets (column 2)
    local belowMinimapCheck, belowMinimapSlider, belowMinimapSliderLabel = CreateScaleControl(
        panel, COL2, yOffset,
        "Below minimap", "scaleBelowMinimap", "belowMinimapScale",
        FU.ApplyBelowMinimapScale
    )

    -- Raid warnings (column 3)
    local raidWarningCheck, raidWarningSlider, raidWarningSliderLabel = CreateScaleControl(
        panel, COL3, yOffset,
        "Raid warnings", "scaleRaidWarnings", "raidWarningScale",
        FU.ApplyRaidWarningScale
    )

    yOffset = yOffset - 90

    -- Move/Reset Arena Frames buttons (under column 1)
    local arenaAnchorButton, SetArenaButtonsEnabled = CreatePositionControls(COL1, yOffset, {
        check = arenaCheck, anchorField = "arenaAnchor",
        toggle = FU.ToggleArenaAnchor, resetPosition = FU.ResetArenaFramePosition,
        applyPosition = FU.ApplyArenaFramePosition, resetToDefault = FU.ResetArenaFrameToDefault,
    })

    -- Move/Reset Below-Minimap buttons (under column 2)
    local belowMinimapAnchorButton, SetBelowMinimapButtonsEnabled = CreatePositionControls(COL2, yOffset, {
        check = belowMinimapCheck, anchorField = "belowMinimapAnchor",
        toggle = FU.ToggleBelowMinimapAnchor, resetPosition = FU.ResetBelowMinimapPosition,
        applyPosition = FU.ApplyBelowMinimapPosition, resetToDefault = FU.ResetBelowMinimapToDefault,
    })

    -- Move/Reset Raid Warning buttons (under column 3)
    local raidWarningAnchorButton, SetRaidWarningButtonsEnabled = CreatePositionControls(COL3, yOffset, {
        check = raidWarningCheck, anchorField = "raidWarningAnchor",
        toggle = FU.ToggleRaidWarningAnchor, resetPosition = FU.ResetRaidWarningPosition,
        applyPosition = FU.ApplyRaidWarningPosition, resetToDefault = FU.ResetRaidWarningToDefault,
    })

    yOffset = yOffset - 35

    ---------------------------------------------------------------------
    -- Slash Commands (left) and Reset Button (right) on same row
    ---------------------------------------------------------------------

    CreateDivider(panel, yOffset)
    yOffset = yOffset - 15

    -- Slash Commands (left side)
    local cmdHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cmdHeader:SetPoint("TOPLEFT", COL1, yOffset)
    cmdHeader:SetText("Slash Commands")
    cmdHeader:SetTextColor(1, 0.82, 0)

    local commands = {
        "/fu - Open settings",
        "/fu reset - Reset all to defaults",
    }

    local cmdYOffset = yOffset - 18
    for _, cmdText in ipairs(commands) do
        local cmdLine = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cmdLine:SetPoint("TOPLEFT", COL1, cmdYOffset)
        cmdLine:SetText("|cff888888" .. cmdText .. "|r")
        cmdYOffset = cmdYOffset - 14
    end

    -- Reset Button (right side)
    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", COL4, yOffset - 2)
    resetButton:SetSize(130, 22)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        FU:ResetToDefaults()
        panel.refresh()
        FU:ApplyAllSettings()
        FU:Print("Settings reset to defaults.")
    end)

    -- Store references for refresh
    panel.chatCheck = chatCheck
    panel.raidCheck = raidCheck
    panel.slider = slider
    panel.sliderLabel = sliderLabel
    panel.partyCheck = partyCheck
    panel.partySlider = partySlider
    panel.partySliderLabel = partySliderLabel
    panel.lootCheck = lootCheck
    panel.lootSlider = lootSlider
    panel.lootSliderLabel = lootSliderLabel
    panel.lootAnchorButton = lootAnchorButton
    panel.questTrackerCheck = questTrackerCheck
    panel.questTrackerSlider = questTrackerSlider
    panel.questTrackerSliderLabel = questTrackerSliderLabel
    panel.questTrackerAnchorButton = questTrackerAnchorButton
    panel.arenaCheck = arenaCheck
    panel.arenaSlider = arenaSlider
    panel.arenaSliderLabel = arenaSliderLabel
    panel.arenaAnchorButton = arenaAnchorButton
    panel.raidWarningCheck = raidWarningCheck
    panel.raidWarningSlider = raidWarningSlider
    panel.raidWarningSliderLabel = raidWarningSliderLabel
    panel.raidWarningAnchorButton = raidWarningAnchorButton
    panel.belowMinimapCheck = belowMinimapCheck
    panel.belowMinimapSlider = belowMinimapSlider
    panel.belowMinimapSliderLabel = belowMinimapSliderLabel
    panel.belowMinimapAnchorButton = belowMinimapAnchorButton
    panel.bagFrameCheck = bagFrameCheck

    ---------------------------------------------------------------------
    -- Refresh function to sync UI with saved settings
    ---------------------------------------------------------------------

    -- Scale controls in display order. The optional position fields (setButtons /
    -- anchorButton / anchorField) drive the Move/Reset button state and Move/Lock
    -- label for the features that also support repositioning.
    local scaleControls = {
        { check = raidCheck,         slider = slider,             label = sliderLabel,             enable = "scaleRaidFrames",   scale = "raidFrameScale" },
        { check = partyCheck,        slider = partySlider,        label = partySliderLabel,        enable = "scalePartyFrames",  scale = "partyFrameScale" },
        { check = lootCheck,         slider = lootSlider,         label = lootSliderLabel,         enable = "scaleLootFrames",   scale = "lootFrameScale",
          setButtons = SetLootButtonsEnabled,         anchorButton = lootAnchorButton,         anchorField = "lootAnchor" },
        { check = questTrackerCheck, slider = questTrackerSlider, label = questTrackerSliderLabel, enable = "scaleQuestTracker", scale = "questTrackerScale",
          setButtons = SetQuestTrackerButtonsEnabled, anchorButton = questTrackerAnchorButton, anchorField = "questTrackerAnchor" },
        { check = arenaCheck,        slider = arenaSlider,        label = arenaSliderLabel,        enable = "scaleArenaFrames",  scale = "arenaFrameScale",
          setButtons = SetArenaButtonsEnabled,        anchorButton = arenaAnchorButton,        anchorField = "arenaAnchor" },
        { check = raidWarningCheck,  slider = raidWarningSlider,  label = raidWarningSliderLabel,  enable = "scaleRaidWarnings", scale = "raidWarningScale",
          setButtons = SetRaidWarningButtonsEnabled,  anchorButton = raidWarningAnchorButton,  anchorField = "raidWarningAnchor" },
        { check = belowMinimapCheck, slider = belowMinimapSlider, label = belowMinimapSliderLabel, enable = "scaleBelowMinimap", scale = "belowMinimapScale",
          setButtons = SetBelowMinimapButtonsEnabled, anchorButton = belowMinimapAnchorButton, anchorField = "belowMinimapAnchor" },
    }

    panel.refresh = function()
        isRefreshing = true
        chatCheck:SetChecked(FU:Get("unlockChat"))
        bagFrameCheck:SetChecked(FU:Get("unlockBagFrame"))
        for _, c in ipairs(scaleControls) do
            local enabled = FU:Get(c.enable)
            c.check:SetChecked(enabled)
            local s = FU:Get(c.scale) or 1.0
            c.slider:SetValue(s)
            c.label:SetText("Scale: " .. math.floor(s * 100) .. "%")
            SetSliderEnabled(c.slider, c.label, enabled)
            if c.setButtons then c.setButtons(enabled) end
            if c.anchorButton then
                local shown = FU[c.anchorField] and FU[c.anchorField]:IsShown()
                c.anchorButton:SetText(shown and "Lock" or "Move")
            end
        end
        isRefreshing = false
    end

    -- Refresh settings when panel is shown
    panel:SetScript("OnShow", function()
        panel.refresh()
    end)

    ---------------------------------------------------------------------
    -- Register with the appropriate settings system
    ---------------------------------------------------------------------

    if hasSettingsAPI then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        FU.settingsCategory = category
    else
        InterfaceOptions_AddCategory(panel)
    end

    FU.optionsPanel = panel
end

---------------------------------------------------------------------
-- Open / close the options panel
---------------------------------------------------------------------

function FU:OpenOptions()
    if hasSettingsAPI then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    else
        -- Two calls required: first selects the category, second scrolls to it (WoW quirk).
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end

-- Close whichever settings frame is open (modern Settings panel or legacy
-- InterfaceOptions). Used when unlocking a frame so the anchor is unobstructed.
function FU:CloseOptions()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        HideUIPanel(InterfaceOptionsFrame)
    end
end

---------------------------------------------------------------------
-- Edit Mode extras
--
-- Adds a compact FrameUnlocker control just beneath Blizzard's Edit Mode system
-- dialog for the systems we cover: a scale slider for the raid/party unit frames,
-- and an unlock checkbox for the chat frame -- so our settings sit right alongside
-- Edit Mode's own without leaving Edit Mode.
--
-- Taint-safe by construction: the panel is parented to UIParent and only
-- *anchored* to the dialog -- it is never injected into the dialog's frame
-- hierarchy, and it only calls SetScale / our chat unlock (not protected actions).
-- We attach via hooksecurefunc (a post-hook, which does not taint Blizzard's
-- execution). Feature-detected: no-ops on clients without Edit Mode.
---------------------------------------------------------------------

function FU:SetupEditModeExtras()
    if self.editModeExtrasReady then return end
    if not (EditModeSystemSettingsDialog and EditModeSystemSettingsDialog.UpdateDialog
        and Enum and Enum.EditModeSystem) then
        return
    end

    local hasUnitFrame = Enum.EditModeSystem.UnitFrame ~= nil and Enum.EditModeUnitFrameSystemIndices ~= nil
    local hasChatFrame = Enum.EditModeSystem.ChatFrame ~= nil
    if not (hasUnitFrame or hasChatFrame) then return end

    -- kind == "scale": drives the slider; kind == "toggle": drives the checkbox.
    local unitFrameMap = hasUnitFrame and {
        [Enum.EditModeUnitFrameSystemIndices.Raid]  = { kind = "scale", enable = "scaleRaidFrames",  scale = "raidFrameScale",  apply = FU.ApplyRaidFrameScale,  label = "Raid frame scale" },
        [Enum.EditModeUnitFrameSystemIndices.Party] = { kind = "scale", enable = "scalePartyFrames", scale = "partyFrameScale", apply = FU.ApplyPartyFrameScale, label = "Party frame scale" },
    } or {}
    local chatConfig = { kind = "toggle", enable = "unlockChat", label = "Unlock chat frame" }

    -- Emblem style to test: "logo" (logo.png) or "text" (a "FU" wordmark, F green /
    -- U white -- echoes the Frame|Unlocker logo). Flip and /reload to compare.
    local EMBLEM_STYLE = "logo"

    local panel = CreateFrame("Frame", "FUEditModeExtrasPanel", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetSize(240, 40)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        panel:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
        panel:SetBackdropBorderColor(0.17, 0.71, 0.45, 1.0)
    end

    -- Hover shows which FrameUnlocker setting this is.
    panel:EnableMouse(true)
    panel:SetScript("OnEnter", function(self)
        if not self.currentMap then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff2BB673FrameUnlocker|r")
        GameTooltip:AddLine(self.currentMap.label, 1, 1, 1)
        GameTooltip:Show()
    end)
    panel:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Shared emblem on the left (logo texture, or a "FU" wordmark).
    local emblem
    if EMBLEM_STYLE == "logo" then
        emblem = panel:CreateTexture(nil, "ARTWORK")
        emblem:SetSize(26, 26)
        emblem:SetPoint("LEFT", 10, 0)
        emblem:SetTexture("Interface\\AddOns\\FrameUnlocker\\logo.png")
    else
        emblem = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        emblem:SetPoint("LEFT", 12, 0)
        emblem:SetText("|cff2BB673F|r|cffffffffU|r")
    end

    -- Scale group (slider): "Scale" + slider + %. Shown for the scale systems.
    local scaleGroup = CreateFrame("Frame", nil, panel)
    scaleGroup:SetAllPoints(panel)
    scaleGroup:Hide()

    local scaleWord = scaleGroup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    scaleWord:SetPoint("LEFT", emblem, "RIGHT", 6, 0)
    scaleWord:SetText("|cffFFD100Scale|r")

    local sLabel = scaleGroup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sLabel:SetPoint("RIGHT", -12, 0)
    sLabel:SetWidth(40)
    sLabel:SetJustifyH("RIGHT")
    sLabel:SetText("100%")

    local refreshing = false
    local sliderTemplate = BackdropTemplateMixin
        and "OptionsSliderTemplate, BackdropTemplate" or "OptionsSliderTemplate"
    local slider = CreateFrame("Slider", nil, scaleGroup, sliderTemplate)
    slider:SetPoint("LEFT", scaleWord, "RIGHT", 10, 0)
    slider:SetPoint("RIGHT", sLabel, "LEFT", -8, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(0.5, 1.5)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    if slider.SetBackdrop then
        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 }
        })
    end
    if slider.Low  then slider.Low:SetText("")  end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end

    slider:SetScript("OnValueChanged", function(_, value)
        if refreshing then return end
        local m = panel.currentMap
        if not m or m.kind ~= "scale" then return end
        value = math.floor(value * 20 + 0.5) / 20
        FU:Set(m.scale, value)
        sLabel:SetText(math.floor(value * 100) .. "%")
        -- Turn the feature on so the scale actually applies and persists across
        -- reloads (ReapplyScaling only reapplies enabled features).
        if not FU:Get(m.enable) then FU:Set(m.enable, true) end
        m.apply(FU, value)
        if FU.optionsPanel and FU.optionsPanel.refresh then FU.optionsPanel.refresh() end
    end)

    -- Toggle group (checkbox): shown for the chat frame.
    local toggleGroup = CreateFrame("Frame", nil, panel)
    toggleGroup:SetAllPoints(panel)
    toggleGroup:Hide()

    local check = CreateFrame("CheckButton", nil, toggleGroup, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
    check.Text:SetText("Unlock chat frame")
    check:SetScript("OnClick", function(self)
        local m = panel.currentMap
        if not m or m.kind ~= "toggle" then return end
        local checked = self:GetChecked()
        FU:Set(m.enable, checked)
        if checked then FU:UnlockChatFrame(ChatFrame1) else FU:LockChatFrame(ChatFrame1) end
        if FU.optionsPanel and FU.optionsPanel.refresh then FU.optionsPanel.refresh() end
    end)

    local function resolve(systemFrame)
        if not systemFrame then return nil end
        if hasUnitFrame and systemFrame.system == Enum.EditModeSystem.UnitFrame then
            return unitFrameMap[systemFrame.systemIndex]
        elseif hasChatFrame and systemFrame.system == Enum.EditModeSystem.ChatFrame then
            return chatConfig
        end
        return nil
    end

    -- Show/update beneath the dialog for a supported system, hide otherwise.
    local function updateFor(systemFrame)
        local m = resolve(systemFrame)
        panel.currentMap = m
        if not m then panel:Hide(); return end

        refreshing = true
        if m.kind == "scale" then
            local s = FU:Get(m.scale) or 1.0
            slider:SetValue(s)
            sLabel:SetText(math.floor(s * 100) .. "%")
        else
            check:SetChecked(FU:Get(m.enable))
        end
        refreshing = false

        scaleGroup:SetShown(m.kind == "scale")
        toggleGroup:SetShown(m.kind == "toggle")

        panel:ClearAllPoints()
        panel:SetPoint("TOP", EditModeSystemSettingsDialog, "BOTTOM", 0, -4)
        panel:SetWidth(EditModeSystemSettingsDialog:GetWidth())
        panel:Show()
    end

    hooksecurefunc(EditModeSystemSettingsDialog, "UpdateDialog", function(_, systemFrame)
        updateFor(systemFrame)
    end)
    EditModeSystemSettingsDialog:HookScript("OnHide", function() panel:Hide() end)

    self.editModeExtrasPanel = panel
    self.editModeExtrasReady = true
end
