PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.RuralLedgerScreen = PhobosRuralLedger.RuralLedgerScreen or {}

local RuralLedgerScreen = PhobosRuralLedger.RuralLedgerScreen
local RuralLedgerScreen_mt = Class(RuralLedgerScreen, ScreenElement)

RuralLedgerScreen.SECTIONS = {
    OVERVIEW = "overview",
    FARMERS = "farmers",
    DETAIL = "detail",
    DEBUG = "debug",
}

RuralLedgerScreen.MAX_FARM_ROWS = 8
RuralLedgerScreen.MAX_OVERVIEW_CARDS = 6
RuralLedgerScreen.MAX_ALERT_LINES = 4
RuralLedgerScreen.MAX_DETAIL_LINES = 12
RuralLedgerScreen.MAX_DEBUG_LINES = 12

function RuralLedgerScreen.new(target, customMt)
    local self = ScreenElement.new(target, customMt or RuralLedgerScreen_mt)

    self.activeSection = RuralLedgerScreen.SECTIONS.OVERVIEW
    self.selectedFarmId = nil
    self.debugVisible = false
    self.cachedOverview = nil
    self.cachedFarmRows = {}
    self.cachedFarmDetail = nil
    self.cachedDebug = nil

    return self
end

local function logInfo(message, ...)
    if PhobosRuralLedger.logInfo ~= nil then
        PhobosRuralLedger.logInfo(message, ...)
    end
end

local function setText(element, value)
    if element ~= nil and element.setText ~= nil then
        element:setText(tostring(value or ""))
    end
end

local function setVisible(element, visible)
    if element ~= nil and element.setVisible ~= nil then
        element:setVisible(visible == true)
    end
end

local function setButtonSelected(button, selected)
    if button ~= nil and button.setSelected ~= nil then
        button:setSelected(selected == true)
    end
end

local function firstFarmId(rows)
    if rows ~= nil and rows[1] ~= nil then
        return rows[1].farmId
    end

    return nil
end

function RuralLedgerScreen:onGuiSetupFinished()
    RuralLedgerScreen:superClass().onGuiSetupFinished(self)
    self:refreshModels()
    self:updateDisplay()
end

function RuralLedgerScreen:onOpen()
    RuralLedgerScreen:superClass().onOpen(self)
    self:refreshModels()
    self:updateDisplay()
    logInfo("Rural Ledger screen opened.")
end

function RuralLedgerScreen:onClickBack()
    if g_gui ~= nil and g_gui.changeScreen ~= nil then
        g_gui:changeScreen(nil)
    end
end

function RuralLedgerScreen:onClickOverview()
    self:setSection(RuralLedgerScreen.SECTIONS.OVERVIEW)
end

function RuralLedgerScreen:onClickFarmers()
    self:setSection(RuralLedgerScreen.SECTIONS.FARMERS)
end

function RuralLedgerScreen:onClickDetail()
    self:setSection(RuralLedgerScreen.SECTIONS.DETAIL)
end

function RuralLedgerScreen:onClickDebug()
    self:setSection(RuralLedgerScreen.SECTIONS.DEBUG)
end

function RuralLedgerScreen:onClickRefresh()
    self:refreshModels()
    self:updateDisplay()
    logInfo("Rural Ledger display models refreshed.")
end

function RuralLedgerScreen:onClickToggleDebug()
    self.debugVisible = not self.debugVisible
    self:refreshModels()
    self:setSection(RuralLedgerScreen.SECTIONS.DEBUG)
    logInfo("Rural Ledger debug visibility is %s.", self.debugVisible and "enabled" or "disabled")
end

function RuralLedgerScreen:onClickFarmRow(index)
    local row = self.cachedFarmRows[index]
    if row == nil then
        return
    end

    self.selectedFarmId = row.farmId
    self.cachedFarmDetail = PhobosRuralLedger.UiModels.buildFarmDetail(
        PhobosRuralLedger.getState(),
        self.selectedFarmId,
        {includeDebug = self.debugVisible}
    )
    self:setSection(RuralLedgerScreen.SECTIONS.DETAIL)
end

function RuralLedgerScreen:refreshModels()
    local state = PhobosRuralLedger.getState()
    self.cachedOverview = PhobosRuralLedger.UiModels.buildOverview(state, {
        maxAlerts = RuralLedgerScreen.MAX_ALERT_LINES,
        includeDebug = self.debugVisible,
    })
    self.cachedFarmRows = PhobosRuralLedger.UiModels.buildFarmList(state, {
        includeDebug = self.debugVisible,
    })
    self.selectedFarmId = self.selectedFarmId or firstFarmId(self.cachedFarmRows)
    self.cachedFarmDetail = PhobosRuralLedger.UiModels.buildFarmDetail(state, self.selectedFarmId, {
        includeDebug = self.debugVisible,
    })
    self.cachedDebug = PhobosRuralLedger.UiModels.buildDebugSummary(state, {
        includeExactFarmValues = self.debugVisible,
    })
end

function RuralLedgerScreen:setSection(section)
    self.activeSection = section
    self:updateDisplay()
end

function RuralLedgerScreen:updateDisplay()
    self:updateTabState()
    self:updateOverview()
    self:updateFarmList()
    self:updateFarmDetail()
    self:updateDebug()
end

function RuralLedgerScreen:updateTabState()
    local active = self.activeSection

    setVisible(self.overviewPanel, active == RuralLedgerScreen.SECTIONS.OVERVIEW)
    setVisible(self.farmersPanel, active == RuralLedgerScreen.SECTIONS.FARMERS)
    setVisible(self.detailPanel, active == RuralLedgerScreen.SECTIONS.DETAIL)
    setVisible(self.debugPanel, active == RuralLedgerScreen.SECTIONS.DEBUG)

    setButtonSelected(self.overviewTab, active == RuralLedgerScreen.SECTIONS.OVERVIEW)
    setButtonSelected(self.farmersTab, active == RuralLedgerScreen.SECTIONS.FARMERS)
    setButtonSelected(self.detailTab, active == RuralLedgerScreen.SECTIONS.DETAIL)
    setButtonSelected(self.debugTab, active == RuralLedgerScreen.SECTIONS.DEBUG)
end

function RuralLedgerScreen:updateOverview()
    local model = self.cachedOverview or {}

    setText(self.overviewTitle, model.title or "Phobos' Rural Ledger")
    setText(self.overviewSubtitle, string.format(
        "Period %s / %s",
        tostring(model.period or "-"),
        tostring(model.regionalPreset or "-")
    ))

    for index = 1, RuralLedgerScreen.MAX_OVERVIEW_CARDS do
        local card = model.cards ~= nil and model.cards[index] or nil
        setText(self.overviewCardLabel ~= nil and self.overviewCardLabel[index] or nil, card ~= nil and card.label or "")
        setText(self.overviewCardValue ~= nil and self.overviewCardValue[index] or nil, card ~= nil and card.value or "")
    end

    for index = 1, RuralLedgerScreen.MAX_ALERT_LINES do
        local alert = model.alerts ~= nil and model.alerts[index] or nil
        setText(self.overviewAlert ~= nil and self.overviewAlert[index] or nil, alert or "")
    end
end

function RuralLedgerScreen:updateFarmList()
    for index = 1, RuralLedgerScreen.MAX_FARM_ROWS do
        local row = self.cachedFarmRows[index]
        local visible = row ~= nil

        setVisible(self.farmRow ~= nil and self.farmRow[index] or nil, visible)
        setText(self.farmName ~= nil and self.farmName[index] or nil, visible and row.displayName or "")
        setText(self.farmType ~= nil and self.farmType[index] or nil, visible and row.profileLabel or "")
        setText(self.farmFields ~= nil and self.farmFields[index] or nil, visible and tostring(row.fields) or "")
        setText(self.farmStress ~= nil and self.farmStress[index] or nil, visible and row.stressLabel or "")
        setText(self.farmPressure ~= nil and self.farmPressure[index] or nil, visible and row.primaryPressureLabel or "")
        setText(self.farmRelation ~= nil and self.farmRelation[index] or nil, visible and row.relationshipBand or "")
    end
end

function RuralLedgerScreen:updateFarmDetail()
    local detail = self.cachedFarmDetail or {}
    local status = detail.status or {}
    local explanation = detail.explanation or {}

    setText(self.detailTitle, detail.displayName or "No farm selected")
    setText(self.detailSubtitle, detail.profileLabel or "")
    setText(self.detailHeadline, status.headline or "")
    setText(self.detailCause, string.format(
        "Primary pressure: %s",
        tostring(explanation.mainCause or "Unknown")
    ))
    setText(self.detailMeaning, explanation.playerMeaning or "")

    for index = 1, RuralLedgerScreen.MAX_DETAIL_LINES do
        local line = detail.lines ~= nil and detail.lines[index] or nil
        setText(self.detailLine ~= nil and self.detailLine[index] or nil, line or "")
    end
end

function RuralLedgerScreen:updateDebug()
    local debugModel = self.cachedDebug or {}

    setText(self.debugTitle, debugModel.title or "Settings / Debug")
    setText(self.debugModeText, self.debugVisible and "Exact debug values visible" or "Exact debug values hidden")

    for index = 1, RuralLedgerScreen.MAX_DEBUG_LINES do
        local line = debugModel.lines ~= nil and debugModel.lines[index] or nil
        setText(self.debugLine ~= nil and self.debugLine[index] or nil, line or "")
    end
end

for index = 1, RuralLedgerScreen.MAX_FARM_ROWS do
    RuralLedgerScreen["onClickFarmRow" .. index] = function(self)
        self:onClickFarmRow(index)
    end
end
