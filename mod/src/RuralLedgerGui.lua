PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Gui = PhobosRuralLedger.Gui or {}

local RuralLedgerGui = PhobosRuralLedger.Gui
local Constants = PhobosRuralLedger.Constants

RuralLedgerGui.modDirectory = g_currentModDirectory or ""
RuralLedgerGui.screen = nil
RuralLedgerGui.screenLoaded = false
RuralLedgerGui.profilesLoaded = false
RuralLedgerGui.farmDetailDialogLoaded = false
RuralLedgerGui.opportunityDialogLoaded = false
RuralLedgerGui.settingsButtonInstalled = false

local function logInfo(message, ...)
    if PhobosRuralLedger.logInfo ~= nil then
        PhobosRuralLedger.logInfo(message, ...)
    end
end

local function logWarn(message, ...)
    if PhobosRuralLedger.logWarn ~= nil then
        PhobosRuralLedger.logWarn(message, ...)
    end
end

local function text(key, fallback)
    if PhobosRuralLedger.I18n ~= nil and PhobosRuralLedger.I18n.get ~= nil then
        return PhobosRuralLedger.I18n.get(key, fallback)
    end

    return fallback
end

local function ensureSaveHook()
    if PhobosRuralLedger.Savegame ~= nil
        and PhobosRuralLedger.Savegame.ensureHookRegistered ~= nil
    then
        PhobosRuralLedger.Savegame.ensureHookRegistered()
    end
end

function RuralLedgerGui:loadScreen()
    if self.screenLoaded and self.farmDetailDialogLoaded and self.opportunityDialogLoaded then
        return true
    end

    if g_gui == nil or g_gui.loadGui == nil then
        logWarn("Rural Ledger GUI could not load because g_gui is unavailable.")
        return false
    end

    if not self.profilesLoaded then
        if g_gui.loadProfiles == nil then
            logWarn("Rural Ledger GUI profiles could not load because g_gui:loadProfiles is unavailable.")
            return false
        end

        local profilePath = self.modDirectory .. "gui/guiProfiles.xml"
        if fileExists ~= nil and not fileExists(profilePath) then
            logWarn("Rural Ledger GUI profile XML is missing: %s", profilePath)
            return false
        end

        g_gui:loadProfiles(profilePath)
        self.profilesLoaded = true
        logInfo("Rural Ledger GUI profiles loaded from %s.", profilePath)
    end

    if not self.farmDetailDialogLoaded then
        local dialog = PhobosRuralLedger.FarmDetailDialog.new()
        local dialogPath = self.modDirectory .. "gui/RuralLedgerFarmDetailDialog.xml"
        local dialogLoaded = g_gui:loadGui(dialogPath, Constants.FARM_DETAIL_DIALOG_NAME, dialog)

        if dialogLoaded == nil then
            logWarn("Rural Ledger farm detail dialog XML did not load: %s", dialogPath)
            return false
        end

        self.farmDetailDialogLoaded = true
        logInfo("Rural Ledger farm detail dialog loaded from %s.", dialogPath)
    end

    if not self.opportunityDialogLoaded then
        local dialog = PhobosRuralLedger.OpportunityDialog.new()
        local dialogPath = self.modDirectory .. "gui/RuralLedgerOpportunityDialog.xml"
        local dialogLoaded = g_gui:loadGui(dialogPath, Constants.OPPORTUNITY_DIALOG_NAME, dialog)

        if dialogLoaded == nil then
            logWarn("Rural Ledger opportunity dialog XML did not load: %s", dialogPath)
            return false
        end

        self.opportunityDialogLoaded = true
        logInfo("Rural Ledger opportunity dialog loaded from %s.", dialogPath)
    end

    if self.screenLoaded then
        return true
    end

    self.screen = PhobosRuralLedger.RuralLedgerScreen.new()
    local xmlPath = self.modDirectory .. "gui/RuralLedgerScreen.xml"
    local loaded = g_gui:loadGui(xmlPath, Constants.SCREEN_NAME, self.screen)

    if loaded == nil then
        logWarn("Rural Ledger GUI XML did not load: %s", xmlPath)
        self.screen = nil
        return false
    end

    self.screenLoaded = true
    logInfo("Rural Ledger GUI loaded from %s.", xmlPath)
    return true
end

function RuralLedgerGui:openScreen()
    if not self:loadScreen() then
        return
    end

    if g_gui == nil or g_gui.showGui == nil then
        logWarn("Rural Ledger screen could not open because g_gui:showGui is unavailable.")
        return
    end

    g_gui:showGui(Constants.SCREEN_NAME)
end

function RuralLedgerGui.onOpenAction()
    RuralLedgerGui:openScreen()
end

function RuralLedgerGui:addSettingsEntry(frame)
    if frame == nil or frame.phobosRuralLedgerOpenButton ~= nil then
        return
    end

    if frame.gameSettingsLayout == nil or frame.checkTraffic == nil then
        return
    end

    local layout = frame.gameSettingsLayout
    local elementCount = #layout.elements
    if elementCount < 1 then
        return
    end

    local headerTemplate = layout.elements[math.min(7, elementCount)]
    if headerTemplate ~= nil then
        local header = headerTemplate:clone()
        header:applyProfile("fs25_settingsSectionHeader", true)
        header:setText(text("rl_ui_title", Constants.DISPLAY_NAME))
        header.focusChangeData = {}

        if FocusManager ~= nil and FocusManager.serveAutoFocusId ~= nil then
            header.focusId = FocusManager.serveAutoFocusId()
        end

        layout:addElement(header)
    end

    local settingsTemplate = layout.elements[math.min(5, elementCount)]
    local option = frame.checkTraffic:clone()
    option.id = "phobosRuralLedgerOpenButton"
    option.target = RuralLedgerGui
    option.onClickCallback = RuralLedgerGui.onSettingsOpenClicked
    option.buttonLRChange = RuralLedgerGui.onSettingsOpenClicked
    option.texts[1] = text("input_PHOBOS_RURAL_LEDGER_MENU", "Open Rural Ledger")
    option.texts[2] = text("input_PHOBOS_RURAL_LEDGER_MENU", "Open Rural Ledger")

    frame.phobosRuralLedgerOpenButton = option

    if settingsTemplate ~= nil and settingsTemplate.elements ~= nil and settingsTemplate.elements[2] ~= nil then
        local optionTitle = settingsTemplate.elements[2]:clone()
        optionTitle.id = "phobosRuralLedgerOpenTitle"
        optionTitle:applyProfile("fs25_settingsMultiTextOptionTitle", true)
        optionTitle:setText(text("rl_ui_title", Constants.DISPLAY_NAME))

        local optionContainer = settingsTemplate:clone()
        optionContainer.id = "phobosRuralLedgerOpenContainer"
        optionContainer:applyProfile("fs25_multiTextOptionContainer", true)

        for key in pairs(optionContainer.elements) do
            optionContainer.elements[key] = nil
        end

        optionContainer:addElement(optionTitle)
        optionContainer:addElement(option)
        layout:addElement(optionContainer)
    else
        layout:addElement(option)
    end

    if option.setIsChecked ~= nil then
        option:setIsChecked(false, true)
    end

    if option.updateSelection ~= nil then
        option:updateSelection()
    end

    layout:invalidateLayout()
    self.settingsButtonInstalled = true
end

function RuralLedgerGui.onSettingsOpenClicked()
    RuralLedgerGui:openScreen()
end

function RuralLedgerGui:loadMap()
    ensureSaveHook()
    self:loadScreen()
    if PhobosRuralLedger.tryMapReadyDiscovery ~= nil then
        PhobosRuralLedger.tryMapReadyDiscovery("mapLoad")
    end
end

function RuralLedgerGui:onStartMission()
    ensureSaveHook()
    if PhobosRuralLedger.tryMapReadyDiscovery ~= nil then
        PhobosRuralLedger.tryMapReadyDiscovery("missionStart")
    end
end

local function onMissionStarted()
    RuralLedgerGui:onStartMission()
end

local function addPlayerActionEvents(playerInputComponent, superFunc, ...)
    superFunc(playerInputComponent, ...)

    if g_inputBinding == nil
        or g_inputBinding.registerActionEvent == nil
        or InputAction == nil
        or InputAction[Constants.ACTION_OPEN_MENU] == nil
    then
        return
    end

    local _, eventId = g_inputBinding:registerActionEvent(
        InputAction[Constants.ACTION_OPEN_MENU],
        RuralLedgerGui,
        RuralLedgerGui.onOpenAction,
        false,
        true,
        false,
        true
    )

    if eventId ~= nil and g_inputBinding.setActionEventTextVisibility ~= nil then
        g_inputBinding:setActionEventTextVisibility(eventId, true)
    end

    if eventId ~= nil and g_inputBinding.setActionEventText ~= nil then
        g_inputBinding:setActionEventText(eventId, text("input_PHOBOS_RURAL_LEDGER_MENU", Constants.DISPLAY_NAME))
    end
end

if InGameMenuSettingsFrame ~= nil and Utils ~= nil and Utils.appendedFunction ~= nil then
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(
        InGameMenuSettingsFrame.onFrameOpen,
        function(frame)
            RuralLedgerGui:addSettingsEntry(frame)
        end
    )
end

if PlayerInputComponent ~= nil and Utils ~= nil and Utils.overwrittenFunction ~= nil then
    PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.overwrittenFunction(
        PlayerInputComponent.registerGlobalPlayerActionEvents,
        addPlayerActionEvents
    )
end

if Mission00 ~= nil and Mission00.onStartMission ~= nil and Utils ~= nil and Utils.appendedFunction ~= nil then
    Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, onMissionStarted)
end

if addModEventListener ~= nil then
    addModEventListener(RuralLedgerGui)
end
