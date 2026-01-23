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

    -- Layout constants
    local LEFT_COL = 16
    local RIGHT_COL = 230
    local SLIDER_WIDTH = 180

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

    local yOffset = -75

    -- Helper to create a horizontal divider line
    local function CreateDivider(parent, yPos)
        local divider = parent:CreateTexture(nil, "ARTWORK")
        divider:SetHeight(1)
        divider:SetPoint("TOPLEFT", LEFT_COL, yPos)
        divider:SetPoint("TOPRIGHT", -16, yPos)
        divider:SetColorTexture(0.5, 0.5, 0.5, 0.5)
        return divider
    end

    -- Divider after title
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 10

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
        slider:SetHeight(20)

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
    -- Chat Unlock Section
    ---------------------------------------------------------------------

    local chatHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chatHeader:SetPoint("TOPLEFT", LEFT_COL, yOffset)
    chatHeader:SetText("Chat Frame")
    chatHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 25

    local chatCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    chatCheck:SetPoint("TOPLEFT", LEFT_COL, yOffset)
    chatCheck.Text:SetText("Unlock chat frame (drag by tab, resize from corner)")
    chatCheck:SetScript("OnClick", function(self)
        FU:Set("unlockChat", self:GetChecked())
        if self:GetChecked() then
            FU:UnlockChatFrame(ChatFrame1)
        else
            FU:LockChatFrame(ChatFrame1)
        end
    end)

    yOffset = yOffset - 45

    -- Divider before Group Frames
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 15

    ---------------------------------------------------------------------
    -- Group Frames Section (Raid + Party side by side)
    ---------------------------------------------------------------------

    local groupHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    groupHeader:SetPoint("TOPLEFT", LEFT_COL, yOffset)
    groupHeader:SetText("Group Frames")
    groupHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 25

    -- Raid frames (left column)
    local raidCheck, slider, sliderLabel = CreateScaleControl(
        panel, LEFT_COL, yOffset,
        "Raid frames", "scaleRaidFrames", "raidFrameScale",
        FU.ApplyRaidFrameScale
    )

    -- Party frames (right column)
    local partyCheck, partySlider, partySliderLabel = CreateScaleControl(
        panel, RIGHT_COL, yOffset,
        "Party frames", "scalePartyFrames", "partyFrameScale",
        FU.ApplyPartyFrameScale
    )

    yOffset = yOffset - 95

    -- Divider before Misc UI
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 15

    ---------------------------------------------------------------------
    -- Misc UI Section
    ---------------------------------------------------------------------

    local miscHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    miscHeader:SetPoint("TOPLEFT", LEFT_COL, yOffset)
    miscHeader:SetText("Misc UI")
    miscHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 25

    -- Status bars (left column)
    local statusCheck, statusSlider, statusSliderLabel = CreateScaleControl(
        panel, LEFT_COL, yOffset,
        "Status bars (XP, rep, honor)", "scaleStatusBars", "statusBarScale",
        FU.ApplyStatusBarScale
    )

    -- Loot roll frames (right column)
    local lootCheck, lootSlider, lootSliderLabel = CreateScaleControl(
        panel, RIGHT_COL, yOffset,
        "Loot roll frames", "scaleLootFrames", "lootFrameScale",
        FU.ApplyLootFrameScale
    )

    yOffset = yOffset - 85

    -- Move Loot Frames button
    local lootAnchorButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lootAnchorButton:SetPoint("TOPLEFT", RIGHT_COL, yOffset)
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

    -- Reset Loot Position button
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
            -- Hide anchor if shown and reset to default
            if FU.lootAnchor and FU.lootAnchor:IsShown() then
                FU.lootAnchor:Hide()
                lootAnchorButton:SetText("Move")
            end
            FU:ResetLootFrameToDefault()
        end
    end)

    yOffset = yOffset - 30

    -- Divider after settings
    CreateDivider(panel, yOffset)
    yOffset = yOffset - 15

    ---------------------------------------------------------------------
    -- Reset Button
    ---------------------------------------------------------------------

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", LEFT_COL, yOffset)
    resetButton:SetSize(140, 22)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        FU:ResetToDefaults()
        panel.refresh()
        FU:ApplyAllSettings()
        FU:Print("Settings reset to defaults.")
    end)

    yOffset = yOffset - 40

    ---------------------------------------------------------------------
    -- Slash Commands Reference
    ---------------------------------------------------------------------

    local cmdHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cmdHeader:SetPoint("TOPLEFT", LEFT_COL, yOffset)
    cmdHeader:SetText("Slash Commands")
    cmdHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 20

    local commands = {
        "/fu - Open this settings panel",
        "/fu loot - Move loot roll frames",
        "/fu reset - Reset to defaults",
    }

    for _, cmdText in ipairs(commands) do
        local cmdLine = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cmdLine:SetPoint("TOPLEFT", LEFT_COL + 4, yOffset)
        cmdLine:SetText("|cff888888" .. cmdText .. "|r")
        yOffset = yOffset - 14
    end

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
        
        -- Update anchor button text based on current state
        if FU.lootAnchor and FU.lootAnchor:IsShown() then
            lootAnchorButton:SetText("Lock")
        else
            lootAnchorButton:SetText("Move")
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
