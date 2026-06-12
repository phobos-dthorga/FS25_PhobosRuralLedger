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

RuralLedgerScreen.MAX_ALERT_LINES = 4
RuralLedgerScreen.COMPACT_WIDTH_PX = 1160

function RuralLedgerScreen.new(target, customMt)
    local self = ScreenElement.new(target, customMt or RuralLedgerScreen_mt)

    self.activeSection = RuralLedgerScreen.SECTIONS.OVERVIEW
    self.selectedFarmId = nil
    self.debugVisible = false
    self.isCompactLayout = false
    self.isReloading = false
    self.cachedOverview = nil
    self.cachedFarmRows = {}
    self.cachedFarmDetail = nil
    self.cachedDebug = nil
    self.overviewRows = {}
    self.detailRows = {}
    self.debugRows = {}

    return self
end

local function i18n(key, fallback, ...)
    if PhobosRuralLedger.I18n ~= nil and PhobosRuralLedger.I18n.get ~= nil then
        return PhobosRuralLedger.I18n.get(key, fallback, ...)
    end

    if select("#", ...) > 0 then
        local ok, value = pcall(string.format, fallback or key, ...)
        if ok then
            return value
        end
    end

    return fallback or key
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

local function reloadList(list)
    if list ~= nil and list.reloadData ~= nil then
        list:reloadData()
    end
end

local function cellAttribute(cell, name)
    if cell ~= nil and cell.getAttribute ~= nil then
        return cell:getAttribute(name)
    end

    return nil
end

local function setCellText(cell, name, value)
    setText(cellAttribute(cell, name), value)
end

local function setCellVisible(cell, name, visible)
    setVisible(cellAttribute(cell, name), visible)
end

local function firstFarmId(rows)
    if rows ~= nil and rows[1] ~= nil then
        return rows[1].farmId
    end

    return nil
end

local function pixelWidth(element)
    if element == nil or element.absSize == nil then
        return nil
    end

    local width = tonumber(element.absSize[1])
    if width == nil then
        return nil
    end

    if width > 10 then
        return width
    end

    if g_pixelSizeScaledX ~= nil and g_pixelSizeScaledX > 0 then
        return width / g_pixelSizeScaledX
    end

    return nil
end

function RuralLedgerScreen:onGuiSetupFinished()
    RuralLedgerScreen:superClass().onGuiSetupFinished(self)
    self:setupLists()
    self:refreshModels()
    self:updateDisplay()
end

function RuralLedgerScreen:onOpen()
    RuralLedgerScreen:superClass().onOpen(self)
    self:refreshModels()
    self:updateDisplay()
    logInfo("%s", i18n("rl_log_screen_opened", "Rural Ledger screen opened."))
end

function RuralLedgerScreen:setupLists()
    self:setupList(self.overviewList, false)
    self:setupList(self.farmTable, true)
    self:setupList(self.detailList, false)
    self:setupList(self.debugList, false)
end

function RuralLedgerScreen:setupList(list, tracksSelection)
    if list == nil then
        return
    end

    if list.setDataSource ~= nil then
        list:setDataSource(self)
    end

    if list.setDelegate ~= nil then
        list:setDelegate(self)
    end

    if tracksSelection == true then
        list.onSelectionChanged = function(_, section, index)
            self:onListSelectionChanged(list, section, index)
        end
    end
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
    self.selectedFarmId = self.selectedFarmId or firstFarmId(self.cachedFarmRows)
    self:refreshFarmDetail()
    self:setSection(RuralLedgerScreen.SECTIONS.DETAIL)
end

function RuralLedgerScreen:onClickDebug()
    self:setSection(RuralLedgerScreen.SECTIONS.DEBUG)
end

function RuralLedgerScreen:onClickRefresh()
    if PhobosRuralLedger.refreshMapBackedState ~= nil then
        PhobosRuralLedger.refreshMapBackedState()
    end

    self:refreshModels()
    self:updateDisplay()
    logInfo("%s", i18n("rl_log_display_refreshed", "Rural Ledger display models refreshed."))
end

function RuralLedgerScreen:onClickToggleDebug()
    self.debugVisible = not self.debugVisible
    self:refreshModels()
    self:setSection(RuralLedgerScreen.SECTIONS.DEBUG)
    logInfo(
        "%s",
        i18n(
            "rl_log_debug_visibility",
            "Rural Ledger debug visibility is %s.",
            self.debugVisible and i18n("rl_log_debug_enabled", "enabled") or i18n("rl_log_debug_disabled", "disabled")
        )
    )
end

function RuralLedgerScreen:onListSelectionChanged(list, section, index)
    if self.isReloading or list ~= self.farmTable then
        return
    end

    local row = self.cachedFarmRows[index]
    if row == nil then
        return
    end

    self.selectedFarmId = row.farmId
    self:refreshFarmDetail()
    self:setSection(RuralLedgerScreen.SECTIONS.DETAIL)
end

function RuralLedgerScreen:refreshModels()
    local state = PhobosRuralLedger.getState()

    self:adaptLayout()
    self.cachedOverview = PhobosRuralLedger.UiModels.buildOverview(state, {
        maxAlerts = RuralLedgerScreen.MAX_ALERT_LINES,
        includeDebug = self.debugVisible,
    })
    self.cachedFarmRows = PhobosRuralLedger.UiModels.buildFarmList(state, {
        includeDebug = self.debugVisible,
    })
    self.selectedFarmId = self.selectedFarmId or firstFarmId(self.cachedFarmRows)
    self:refreshFarmDetail()
    self.cachedDebug = PhobosRuralLedger.UiModels.buildDebugSummary(state, {
        includeExactFarmValues = self.debugVisible,
    })
    self:buildListRows()
end

function RuralLedgerScreen:refreshFarmDetail()
    self.cachedFarmDetail = PhobosRuralLedger.UiModels.buildFarmDetail(
        PhobosRuralLedger.getState(),
        self.selectedFarmId,
        {includeDebug = self.debugVisible}
    )
    self.detailRows = (self.cachedFarmDetail or {}).lines or {}
end

function RuralLedgerScreen:adaptLayout()
    local width = pixelWidth(self.farmersPanel) or pixelWidth(self.screenContainer)
    self.isCompactLayout = width ~= nil and width < RuralLedgerScreen.COMPACT_WIDTH_PX
    self:applyFarmHeaderLayout()
end

function RuralLedgerScreen:applyFarmHeaderLayout()
    local compact = self.isCompactLayout == true

    setVisible(self.farmHeaderFarm, not compact)
    setVisible(self.farmHeaderType, not compact)
    setVisible(self.farmHeaderFields, not compact)
    setVisible(self.farmHeaderStress, not compact)
    setVisible(self.farmHeaderPressure, not compact)
    setVisible(self.farmHeaderRelation, not compact)
    setVisible(self.farmHeaderFarmCompact, compact)
    setVisible(self.farmHeaderFieldsCompact, compact)
    setVisible(self.farmHeaderStressCompact, compact)
    setVisible(self.farmHeaderPressureCompact, compact)
end

function RuralLedgerScreen:buildListRows()
    local overview = self.cachedOverview or {}
    local overviewRows = {}

    for _, card in ipairs(overview.cards or {}) do
        overviewRows[#overviewRows + 1] = {
            label = card.label,
            value = card.value,
        }
    end

    for _, alert in ipairs(overview.alerts or {}) do
        overviewRows[#overviewRows + 1] = {
            label = "",
            value = alert,
        }
    end

    self.overviewRows = overviewRows
    self.detailRows = (self.cachedFarmDetail or {}).lines or {}
    self.debugRows = (self.cachedDebug or {}).lines or {}
end

function RuralLedgerScreen:setSection(section)
    self.activeSection = section
    self:updateDisplay()
end

function RuralLedgerScreen:updateDisplay()
    self:updateTabState()
    self:updateOverview()
    self:updateFarmDetail()
    self:updateDebug()
    self:reloadVisibleLists()
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

    setText(self.overviewTitle, model.title or i18n("rl_ui_title", "Phobos' Rural Ledger"))
    setText(self.overviewSubtitle, i18n(
        "rl_overview_period",
        "Period %s / %s",
        tostring(model.period or "-"),
        tostring(model.regionalPreset or "-")
    ))
end

function RuralLedgerScreen:updateFarmDetail()
    local detail = self.cachedFarmDetail or {}
    local status = detail.status or {}
    local explanation = detail.explanation or {}

    setText(self.detailTitle, detail.displayName or i18n("rl_detail_no_farm_title", "No farm selected"))
    setText(self.detailSubtitle, detail.profileLabel or "")
    setText(self.detailHeadline, status.headline or "")
    setText(self.detailCause, i18n(
        "rl_detail_primary_pressure",
        "Primary pressure: %s",
        tostring(explanation.mainCause or i18n("rl_stress_unknown", "Unknown"))
    ))
    setText(self.detailMeaning, explanation.playerMeaning or "")
end

function RuralLedgerScreen:updateDebug()
    local debugModel = self.cachedDebug or {}

    setText(self.debugTitle, debugModel.title or i18n("rl_tab_settings_debug", "Settings / Debug"))
    setText(
        self.debugModeText,
        self.debugVisible and i18n("rl_debug_exact_visible", "Exact debug values visible")
            or i18n("rl_debug_exact_hidden", "Exact debug values hidden")
    )
end

function RuralLedgerScreen:reloadVisibleLists()
    self.isReloading = true
    reloadList(self.overviewList)
    reloadList(self.farmTable)
    reloadList(self.detailList)
    reloadList(self.debugList)
    self.isReloading = false
end

function RuralLedgerScreen:getNumberOfSections()
    return 1
end

function RuralLedgerScreen:getNumberOfItemsInSection(list, section)
    if list == self.overviewList then
        return #self.overviewRows
    elseif list == self.farmTable then
        return #self.cachedFarmRows
    elseif list == self.detailList then
        return #self.detailRows
    elseif list == self.debugList then
        return #self.debugRows
    end

    return 0
end

function RuralLedgerScreen:populateCellForItemInSection(list, section, index, cell)
    if list == self.overviewList then
        self:populateOverviewCell(index, cell)
    elseif list == self.farmTable then
        self:populateFarmCell(index, cell)
    elseif list == self.detailList then
        self:populateTextCell(self.detailRows[index], cell)
    elseif list == self.debugList then
        self:populateTextCell(self.debugRows[index], cell)
    end
end

function RuralLedgerScreen:populateOverviewCell(index, cell)
    local row = self.overviewRows[index] or {}

    setCellText(cell, "label", row.label or "")
    setCellText(cell, "value", row.value or "")
end

function RuralLedgerScreen:populateFarmCell(index, cell)
    local row = self.cachedFarmRows[index]
    if row == nil then
        return
    end

    local compact = self.isCompactLayout == true
    local standardNames = {"farmName", "farmType", "farmFields", "farmStress", "farmPressure", "farmRelation"}
    local compactNames = {"farmNameCompact", "farmFieldsCompact", "farmStressCompact", "farmPressureCompact"}

    for _, name in ipairs(standardNames) do
        setCellVisible(cell, name, not compact)
    end

    for _, name in ipairs(compactNames) do
        setCellVisible(cell, name, compact)
    end

    setCellText(cell, "farmName", row.displayName)
    setCellText(cell, "farmType", row.profileLabel)
    setCellText(cell, "farmFields", tostring(row.fields or ""))
    setCellText(cell, "farmStress", row.stressLabel)
    setCellText(cell, "farmPressure", row.primaryPressureLabel)
    setCellText(cell, "farmRelation", row.sourceConfidenceLabel)

    setCellText(cell, "farmNameCompact", row.displayName)
    setCellText(cell, "farmFieldsCompact", tostring(row.fields or ""))
    setCellText(cell, "farmStressCompact", row.stressLabel)
    setCellText(cell, "farmPressureCompact", row.primaryPressureLabel)
end

function RuralLedgerScreen:populateTextCell(line, cell)
    setCellText(cell, "line", line or "")
end
