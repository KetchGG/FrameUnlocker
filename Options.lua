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

    -- Layout constants (3-column layout)
    local COL1 = 16
    local COL2 = 170
    local COL3 = 324
    local SLIDER_WIDTH = 130
    local SLIDER_HEIGHT = 15

    -- Get version from TOC
    local version = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") 
        or GetAddOnMetadata(addonName, "Version") 
        or "?"

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

        slider.Low:SetText("50%")
        slider.High:SetText("150%")
        slider.Text:SetText("")

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

    ---------------------------------------------------------------------
    -- Chat Frames Section
    ---------------------------------------------------------------------

    local chatHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chatHeader:SetPoint("TOPLEFT", COL1, yOffset)
    chatHeader:SetText("Chat Frames")
    chatHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 18
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 12

    -- Chat unlock
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

    yOffset = yOffset - 50

    ---------------------------------------------------------------------
    -- Group & PvP Frames Section (Raid, Party, Arena - 3 columns)
    ---------------------------------------------------------------------

    local groupHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    groupHeader:SetPoint("TOPLEFT", COL1, yOffset)
    groupHeader:SetText("Group & PvP Frames")
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

    -- Arena/Flag carrier frames (column 3)
    local arenaCheck, arenaSlider, arenaSliderLabel = CreateScaleControl(
        panel, COL3, yOffset,
        "Arena / Flag Carriers", "scaleArenaFrames", "arenaFrameScale",
        FU.ApplyArenaFrameScale
    )

    yOffset = yOffset - 90

    -- Move/Reset Arena Frames buttons (under column 3)
    local arenaAnchorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    arenaAnchorButton:SetPoint("TOPLEFT", COL3, yOffset)
    arenaAnchorButton:SetSize(60, 22)
    arenaAnchorButton:SetText("Move")
    arenaAnchorButton:SetScript("OnClick", function(self)
        local showing = FU:ToggleArenaAnchor()
        if showing then
            self:SetText("Lock")
        else
            self:SetText("Move")
        end
    end)

    local arenaResetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    arenaResetButton:SetPoint("LEFT", arenaAnchorButton, "RIGHT", 4, 0)
    arenaResetButton:SetSize(60, 22)
    arenaResetButton:SetText("Reset")
    arenaResetButton:SetScript("OnClick", function()
        FU:ResetArenaFramePosition()
    end)

    -- Helper to enable/disable arena position buttons
    local function SetArenaButtonsEnabled(enabled)
        if enabled then
            arenaAnchorButton:Enable()
            arenaAnchorButton:SetAlpha(1.0)
            arenaResetButton:Enable()
            arenaResetButton:SetAlpha(1.0)
        else
            arenaAnchorButton:Disable()
            arenaAnchorButton:SetAlpha(0.5)
            arenaResetButton:Disable()
            arenaResetButton:SetAlpha(0.5)
        end
    end

    -- Handle position and button state when arena scaling is toggled
    arenaCheck:HookScript("OnClick", function(self)
        local enabled = self:GetChecked()
        SetArenaButtonsEnabled(enabled)
        if enabled then
            FU:ApplyArenaFramePosition()
        else
            if FU.arenaAnchor and FU.arenaAnchor:IsShown() then
                FU.arenaAnchor:Hide()
                arenaAnchorButton:SetText("Move")
            end
            FU:ResetArenaFrameToDefault()
        end
    end)

    yOffset = yOffset - 35

    ---------------------------------------------------------------------
    -- Misc Frames Section (Status bars, Loot rolls, Quest tracker)
    ---------------------------------------------------------------------

    local miscHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    miscHeader:SetPoint("TOPLEFT", COL1, yOffset)
    miscHeader:SetText("Misc Frames")
    miscHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 18
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 12

    -- Status bars (column 1)
    local statusCheck, statusSlider, statusSliderLabel = CreateScaleControl(
        panel, COL1, yOffset,
        "Status bars", "scaleStatusBars", "statusBarScale",
        FU.ApplyStatusBarScale
    )

    -- Loot roll frames (column 2)
    local lootCheck, lootSlider, lootSliderLabel = CreateScaleControl(
        panel, COL2, yOffset,
        "Loot rolls", "scaleLootFrames", "lootFrameScale",
        FU.ApplyLootFrameScale
    )

    -- Quest tracker (column 3)
    local questTrackerCheck, questTrackerSlider, questTrackerSliderLabel = CreateScaleControl(
        panel, COL3, yOffset,
        "Quest tracker", "scaleQuestTracker", "questTrackerScale",
        FU.ApplyQuestTrackerScale
    )

    yOffset = yOffset - 90

    -- Move/Reset Loot Frames buttons (under column 2)
    local lootAnchorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lootAnchorButton:SetPoint("TOPLEFT", COL2, yOffset)
    lootAnchorButton:SetSize(60, 22)
    lootAnchorButton:SetText("Move")
    lootAnchorButton:SetScript("OnClick", function(self)
        local showing = FU:ToggleLootAnchor()
        if showing then
            self:SetText("Lock")
        else
            self:SetText("Move")
        end
    end)

    local lootResetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lootResetButton:SetPoint("LEFT", lootAnchorButton, "RIGHT", 4, 0)
    lootResetButton:SetSize(60, 22)
    lootResetButton:SetText("Reset")
    lootResetButton:SetScript("OnClick", function()
        FU:ResetLootFramePosition()
    end)

    -- Helper to enable/disable loot position buttons
    local function SetLootButtonsEnabled(enabled)
        if enabled then
            lootAnchorButton:Enable()
            lootAnchorButton:SetAlpha(1.0)
            lootResetButton:Enable()
            lootResetButton:SetAlpha(1.0)
        else
            lootAnchorButton:Disable()
            lootAnchorButton:SetAlpha(0.5)
            lootResetButton:Disable()
            lootResetButton:SetAlpha(0.5)
        end
    end

    -- Handle position and button state when loot scaling is toggled
    lootCheck:HookScript("OnClick", function(self)
        local enabled = self:GetChecked()
        SetLootButtonsEnabled(enabled)
        if enabled then
            FU:ApplyLootFramePosition()
        else
            if FU.lootAnchor and FU.lootAnchor:IsShown() then
                FU.lootAnchor:Hide()
                lootAnchorButton:SetText("Move")
            end
            FU:ResetLootFrameToDefault()
        end
    end)

    -- Move/Reset Quest Tracker buttons (under column 3)
    local questTrackerAnchorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    questTrackerAnchorButton:SetPoint("TOPLEFT", COL3, yOffset)
    questTrackerAnchorButton:SetSize(60, 22)
    questTrackerAnchorButton:SetText("Move")
    questTrackerAnchorButton:SetScript("OnClick", function(self)
        local showing = FU:ToggleQuestTrackerAnchor()
        if showing then
            self:SetText("Lock")
        else
            self:SetText("Move")
        end
    end)

    local questTrackerResetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    questTrackerResetButton:SetPoint("LEFT", questTrackerAnchorButton, "RIGHT", 4, 0)
    questTrackerResetButton:SetSize(60, 22)
    questTrackerResetButton:SetText("Reset")
    questTrackerResetButton:SetScript("OnClick", function()
        FU:ResetQuestTrackerPosition()
    end)

    -- Helper to enable/disable quest tracker position buttons
    local function SetQuestTrackerButtonsEnabled(enabled)
        if enabled then
            questTrackerAnchorButton:Enable()
            questTrackerAnchorButton:SetAlpha(1.0)
            questTrackerResetButton:Enable()
            questTrackerResetButton:SetAlpha(1.0)
        else
            questTrackerAnchorButton:Disable()
            questTrackerAnchorButton:SetAlpha(0.5)
            questTrackerResetButton:Disable()
            questTrackerResetButton:SetAlpha(0.5)
        end
    end

    -- Handle position and button state when quest tracker scaling is toggled
    questTrackerCheck:HookScript("OnClick", function(self)
        local enabled = self:GetChecked()
        SetQuestTrackerButtonsEnabled(enabled)
        if enabled then
            FU:ApplyQuestTrackerPosition()
        else
            if FU.questTrackerAnchor and FU.questTrackerAnchor:IsShown() then
                FU.questTrackerAnchor:Hide()
                questTrackerAnchorButton:SetText("Move")
            end
            FU:ResetQuestTrackerToDefault()
        end
    end)

    yOffset = yOffset - 45

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
        "/fu loot - Move loot frames",
        "/fu quest - Move quest tracker",
        "/fu arena - Move arena frames",
        "/fu reset - Reset to defaults",
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
    resetButton:SetPoint("TOPLEFT", COL3, yOffset - 2)
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
    panel.statusCheck = statusCheck
    panel.statusSlider = statusSlider
    panel.statusSliderLabel = statusSliderLabel
    panel.lootCheck = lootCheck
    panel.lootSlider = lootSlider
    panel.lootSliderLabel = lootSliderLabel
    panel.lootAnchorButton = lootAnchorButton
    panel.questTrackerCheck = questTrackerCheck
    panel.questTrackerSlider = questTrackerSlider
    panel.questTrackerSliderLabel = questTrackerSliderLabel
    panel.questTrackerAnchorButton = questTrackerAnchorButton
    panel.SetQuestTrackerButtonsEnabled = SetQuestTrackerButtonsEnabled
    panel.arenaCheck = arenaCheck
    panel.arenaSlider = arenaSlider
    panel.arenaSliderLabel = arenaSliderLabel
    panel.arenaAnchorButton = arenaAnchorButton
    panel.SetArenaButtonsEnabled = SetArenaButtonsEnabled

    ---------------------------------------------------------------------
    -- Refresh function to sync UI with saved settings
    ---------------------------------------------------------------------

    panel.refresh = function()
        isRefreshing = true
        chatCheck:SetChecked(FU:Get("unlockChat"))
        
        raidCheck:SetChecked(FU:Get("scaleRaidFrames"))
        local scale = FU:Get("raidFrameScale") or 1.0
        slider:SetValue(scale)
        sliderLabel:SetText("Scale: " .. math.floor(scale * 100) .. "%")
        SetSliderEnabled(slider, sliderLabel, FU:Get("scaleRaidFrames"))
        
        partyCheck:SetChecked(FU:Get("scalePartyFrames"))
        local partyScale = FU:Get("partyFrameScale") or 1.0
        partySlider:SetValue(partyScale)
        partySliderLabel:SetText("Scale: " .. math.floor(partyScale * 100) .. "%")
        SetSliderEnabled(partySlider, partySliderLabel, FU:Get("scalePartyFrames"))
        
        statusCheck:SetChecked(FU:Get("scaleStatusBars"))
        local statusScale = FU:Get("statusBarScale") or 1.0
        statusSlider:SetValue(statusScale)
        statusSliderLabel:SetText("Scale: " .. math.floor(statusScale * 100) .. "%")
        SetSliderEnabled(statusSlider, statusSliderLabel, FU:Get("scaleStatusBars"))
        
        local lootEnabled = FU:Get("scaleLootFrames")
        lootCheck:SetChecked(lootEnabled)
        local lootScale = FU:Get("lootFrameScale") or 1.0
        lootSlider:SetValue(lootScale)
        lootSliderLabel:SetText("Scale: " .. math.floor(lootScale * 100) .. "%")
        SetSliderEnabled(lootSlider, lootSliderLabel, lootEnabled)
        SetLootButtonsEnabled(lootEnabled)
        
        -- Update loot anchor button text based on current state
        if FU.lootAnchor and FU.lootAnchor:IsShown() then
            lootAnchorButton:SetText("Lock")
        else
            lootAnchorButton:SetText("Move")
        end
        
        local questTrackerEnabled = FU:Get("scaleQuestTracker")
        questTrackerCheck:SetChecked(questTrackerEnabled)
        local questTrackerScale = FU:Get("questTrackerScale") or 1.0
        questTrackerSlider:SetValue(questTrackerScale)
        questTrackerSliderLabel:SetText("Scale: " .. math.floor(questTrackerScale * 100) .. "%")
        SetSliderEnabled(questTrackerSlider, questTrackerSliderLabel, questTrackerEnabled)
        SetQuestTrackerButtonsEnabled(questTrackerEnabled)
        
        -- Update quest tracker anchor button text based on current state
        if FU.questTrackerAnchor and FU.questTrackerAnchor:IsShown() then
            questTrackerAnchorButton:SetText("Lock")
        else
            questTrackerAnchorButton:SetText("Move")
        end
        
        local arenaEnabled = FU:Get("scaleArenaFrames")
        arenaCheck:SetChecked(arenaEnabled)
        local arenaScale = FU:Get("arenaFrameScale") or 1.0
        arenaSlider:SetValue(arenaScale)
        arenaSliderLabel:SetText("Scale: " .. math.floor(arenaScale * 100) .. "%")
        SetSliderEnabled(arenaSlider, arenaSliderLabel, arenaEnabled)
        SetArenaButtonsEnabled(arenaEnabled)
        
        -- Update arena anchor button text based on current state
        if FU.arenaAnchor and FU.arenaAnchor:IsShown() then
            arenaAnchorButton:SetText("Lock")
        else
            arenaAnchorButton:SetText("Move")
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
-- Slash command to open options
---------------------------------------------------------------------

function FU:OpenOptions()
    if hasSettingsAPI then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    else
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end
