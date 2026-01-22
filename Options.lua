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

    local yOffset = -70

    ---------------------------------------------------------------------
    -- Chat Unlock Section
    ---------------------------------------------------------------------

    local chatHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    chatHeader:SetPoint("TOPLEFT", 16, yOffset)
    chatHeader:SetText("Chat Frame")
    chatHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 25

    -- Checkbox: Unlock chat frame
    local chatCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    chatCheck:SetPoint("TOPLEFT", 16, yOffset)
    chatCheck.Text:SetText("Unlock chat frame (drag by tab, resize from corner)")
    chatCheck:SetScript("OnClick", function(self)
        FU:Set("unlockChat", self:GetChecked())
        if self:GetChecked() then
            FU:UnlockChatFrame(ChatFrame1)
            FU:Print("Chat unlocked.")
        else
            FU:LockChatFrame(ChatFrame1)
            FU:Print("Chat locked.")
        end
    end)

    yOffset = yOffset - 40

    ---------------------------------------------------------------------
    -- Raid Frames Section
    ---------------------------------------------------------------------

    local raidHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    raidHeader:SetPoint("TOPLEFT", 16, yOffset)
    raidHeader:SetText("Raid Frames")
    raidHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 25

    -- Checkbox: Scale raid frames
    local raidCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    raidCheck:SetPoint("TOPLEFT", 16, yOffset)
    raidCheck.Text:SetText("Scale compact raid frames")
    raidCheck:SetScript("OnClick", function(self)
        FU:Set("scaleRaidFrames", self:GetChecked())
        if self:GetChecked() then
            FU:ApplyRaidFrameScale()
            FU:Print("Raid frame scaling enabled.")
        else
            FU:ApplyRaidFrameScale(1.0)
            FU:Print("Raid frame scaling disabled.")
        end
    end)

    yOffset = yOffset - 35

    -- Slider: Raid frame scale
    local sliderLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sliderLabel:SetPoint("TOPLEFT", 20, yOffset)
    sliderLabel:SetText("Scale: 80%")

    yOffset = yOffset - 20

    -- Create slider with BackdropTemplate for modern clients
    local sliderTemplate = "OptionsSliderTemplate"
    if BackdropTemplateMixin then
        sliderTemplate = "OptionsSliderTemplate, BackdropTemplate"
    end
    
    local slider = CreateFrame("Slider", "FUScaleSlider", panel, sliderTemplate)
    slider:SetPoint("TOPLEFT", 20, yOffset)
    slider:SetMinMaxValues(0.5, 1.5)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(200)
    slider:SetHeight(20)

    -- Add backdrop for visual appearance
    if slider.SetBackdrop then
        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 }
        })
    end

    slider.Low:SetText("50%")
    slider.High:SetText("150%")
    slider.Text:SetText("")

    -- Flag to prevent OnValueChanged firing during refresh
    local isRefreshing = false

    slider:SetScript("OnValueChanged", function(self, value)
        if isRefreshing then return end
        value = math.floor(value * 20 + 0.5) / 20  -- Round to nearest 0.05
        FU:Set("raidFrameScale", value)
        sliderLabel:SetText("Scale: " .. math.floor(value * 100) .. "%")
        if FU:Get("scaleRaidFrames") then
            FU:ApplyRaidFrameScale(value)
        end
    end)

    -- Store references for refresh
    panel.chatCheck = chatCheck
    panel.raidCheck = raidCheck
    panel.slider = slider
    panel.sliderLabel = sliderLabel

    ---------------------------------------------------------------------
    -- Refresh function to sync UI with saved settings
    ---------------------------------------------------------------------

    panel.refresh = function()
        isRefreshing = true
        chatCheck:SetChecked(FU:Get("unlockChat"))
        raidCheck:SetChecked(FU:Get("scaleRaidFrames"))
        local scale = FU:Get("raidFrameScale") or 0.8
        slider:SetValue(scale)
        sliderLabel:SetText("Scale: " .. math.floor(scale * 100) .. "%")
        isRefreshing = false
    end

    ---------------------------------------------------------------------
    -- Register with the appropriate settings system
    ---------------------------------------------------------------------

    if hasSettingsAPI then
        -- Modern Settings API (Dragonflight+, TBC Anniversary, etc.)
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        FU.settingsCategory = category
    else
        -- Legacy InterfaceOptions (old Classic clients)
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
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)  -- Called twice due to Blizzard bug
    end
end
