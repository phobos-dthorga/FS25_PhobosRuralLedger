PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.RuralLedgerScreen = PhobosRuralLedger.RuralLedgerScreen or {}

local RuralLedgerScreen = PhobosRuralLedger.RuralLedgerScreen
local RuralLedgerScreen_mt = Class(RuralLedgerScreen, ScreenElement)
local Constants = PhobosRuralLedger.Constants

RuralLedgerScreen.SECTIONS = {
    OVERVIEW = "overview",
    NEWSPAPER = "newspaper",
    FARMERS = "farmers",
    JOBS = "jobs",
    DEBUG = "debug",
}

RuralLedgerScreen.JOB_MODES = {
    NPC = "npc",
    PLOT = "plot",
}

RuralLedgerScreen.MAX_ALERT_LINES = 4
RuralLedgerScreen.COMPACT_WIDTH_PX = 1160

function RuralLedgerScreen.new(target, customMt)
    local self = ScreenElement.new(target, customMt or RuralLedgerScreen_mt)

    self.activeSection = RuralLedgerScreen.SECTIONS.OVERVIEW
    self.selectedFarmId = nil
    self.selectedJobRequestId = nil
    self.selectedNewspaperEditionId = nil
    self.activeJobMode = RuralLedgerScreen.JOB_MODES.NPC
    self.debugVisible = false
    self.isCompactLayout = false
    self.isReloading = false
    self.cachedOverview = nil
    self.cachedNewspaper = nil
    self.cachedNewspaperRows = {}
    self.cachedNewspaperEdition = nil
    self.cachedFarmRows = {}
    self.cachedFarmDetail = nil
    self.cachedOpportunities = nil
    self.cachedOpportunityFarmId = nil
    self.cachedHistory = nil
    self.cachedJobRows = {}
    self.cachedJobDetail = nil
    self.cachedDebug = nil
    self.overviewRows = {}
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

local function setButtonDisabled(button, disabled)
    if button == nil then
        return
    end

    local value = disabled == true
    button.disabled = value

    if button.setDisabled ~= nil then
        button:setDisabled(value)
    elseif button.setIsDisabled ~= nil then
        button:setIsDisabled(value)
    end
end

local function setButtonAvailable(button, available)
    local visible = available == true
    setVisible(button, visible)
    setButtonDisabled(button, not visible)
end

local function invalidateLayout(element)
    if element ~= nil and element.invalidateLayout ~= nil then
        element:invalidateLayout()
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

local function containsFarmId(rows, farmId)
    if rows == nil or farmId == nil then
        return false
    end

    for _, row in ipairs(rows) do
        if row.farmId == farmId then
            return true
        end
    end

    return false
end

local function containsRequestId(rows, requestId)
    if rows == nil or requestId == nil then
        return false
    end

    for _, row in ipairs(rows) do
        if tostring(row.requestId or "") == tostring(requestId or "") then
            return true
        end
    end

    return false
end

local function containsEditionId(rows, editionId)
    if rows == nil or editionId == nil then
        return false
    end

    for _, row in ipairs(rows) do
        if tostring(row.editionId or "") == tostring(editionId or "") then
            return true
        end
    end

    return false
end

local function rowAtListIndex(rows, index)
    local numericIndex = tonumber(index)

    if rows == nil or numericIndex == nil or numericIndex < 1 then
        return nil
    end

    return rows[numericIndex]
end

local function listElementIndex(element)
    if type(element) ~= "table" then
        return nil
    end

    return tonumber(element.indexInSection or element.index or element.listIndex)
end

local function listElementSection(element)
    if type(element) ~= "table" then
        return nil
    end

    return tonumber(element.sectionIndex or element.section or element.listSection)
end

local function listElementIsInvalid(element)
    if type(element) ~= "table" then
        return false
    end

    return element.isEmptyCell == true
        or element.isHeader == true
        or element.disabled == true
end

local function resolveListCallback(list, ...)
    local args = {...}
    local section = nil
    local index = nil
    local element = nil

    for _, value in ipairs(args) do
        if value ~= list and type(value) == "table" and listElementIndex(value) ~= nil then
            element = value
            section = listElementSection(value) or section
            index = listElementIndex(value)
            break
        end
    end

    if index == nil then
        for position, value in ipairs(args) do
            if value == list then
                section = tonumber(args[position + 1]) or section
                index = tonumber(args[position + 2]) or index
                break
            end
        end
    end

    if index == nil then
        local numericArgs = {}

        for _, value in ipairs(args) do
            if type(value) ~= "boolean" then
                local numericValue = tonumber(value)

                if numericValue ~= nil then
                    numericArgs[#numericArgs + 1] = numericValue
                end
            end
        end

        if #numericArgs >= 2 then
            section = section or numericArgs[1]
            index = numericArgs[2]
        elseif #numericArgs == 1 then
            index = numericArgs[1]
        end
    end

    return section, index, element
end

local function rowFromListCallback(rows, list, ...)
    local _, index, element = resolveListCallback(list, ...)

    if listElementIsInvalid(element) then
        return nil
    end

    return rowAtListIndex(rows, index)
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
    if PhobosRuralLedger.tryMapReadyDiscovery ~= nil then
        PhobosRuralLedger.tryMapReadyDiscovery("screenOpenRetry")
    end

    self:refreshModels()
    self:updateDisplay()
    logInfo("%s", i18n("rl_log_screen_opened", "Rural Ledger screen opened."))
end

function RuralLedgerScreen:setupLists()
    self:setupList(self.overviewList, false)
    self:setupList(self.newspaperTable, true)
    self:setupList(self.farmTable, true)
    self:setupList(self.jobTable, true)
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
        list.onDoubleClickCallback = function(...)
            self:onListDoubleClick(list, ...)
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

function RuralLedgerScreen:onClickNewspaper()
    self:setSection(RuralLedgerScreen.SECTIONS.NEWSPAPER)
end

function RuralLedgerScreen:onClickFarmers()
    self:setSection(RuralLedgerScreen.SECTIONS.FARMERS)
end

function RuralLedgerScreen:onClickJobs()
    self:setSection(RuralLedgerScreen.SECTIONS.JOBS)
end

function RuralLedgerScreen:onClickJobsByNpc()
    self.activeJobMode = RuralLedgerScreen.JOB_MODES.NPC
    self:refreshJobs()
    self:setSection(RuralLedgerScreen.SECTIONS.JOBS)
end

function RuralLedgerScreen:onClickJobsByPlot()
    self.activeJobMode = RuralLedgerScreen.JOB_MODES.PLOT
    self:refreshJobs()
    self:setSection(RuralLedgerScreen.SECTIONS.JOBS)
end

function RuralLedgerScreen:onClickDetail()
    self:onClickFarmDetail()
end

function RuralLedgerScreen:onClickFarmDetail()
    if self.selectedFarmId == nil then
        self:updateFooterButtons()
        return
    end

    self:refreshFarmDetail()
    self:openFarmDetailDialog()
end

function RuralLedgerScreen:onClickOpportunities()
    local farmId = self:getContextFarmId()
    if farmId == nil then
        self:updateFooterButtons()
        return
    end

    self:refreshOpportunities(farmId)
    if #(((self.cachedOpportunities or {}).opportunities) or {}) == 0 then
        self:updateFooterButtons()
        return
    end

    self:openOpportunityDialog()
end

function RuralLedgerScreen:onClickHistory()
    if self.selectedFarmId == nil then
        self:updateFooterButtons()
        return
    end

    self:refreshHistory()
    if #(((self.cachedHistory or {}).history) or {}) == 0 then
        self:updateFooterButtons()
        return
    end

    self:openHistoryDialog()
end

function RuralLedgerScreen:onClickReadNewspaper()
    if self.selectedNewspaperEditionId == nil then
        self:updateFooterButtons()
        return
    end

    self:refreshNewspaperEdition()
    self:openNewspaperDialog()
end

function RuralLedgerScreen:onClickJobDetail()
    if self.selectedJobRequestId == nil then
        self:updateFooterButtons()
        return
    end

    self:refreshJobDetail()
    self:openJobDetailDialog()
end

function RuralLedgerScreen:onClickStartContract()
    if self.selectedJobRequestId == nil then
        self:updateFooterButtons()
        return
    end

    local ok = false
    if PhobosRuralLedger.startJobContract ~= nil then
        ok = PhobosRuralLedger.startJobContract(self.selectedJobRequestId, {mission = g_currentMission})
    end

    self:refreshModels()
    self:setSection(RuralLedgerScreen.SECTIONS.JOBS)

    if ok then
        logInfo("%s", i18n("rl_log_job_start_requested", "Rural Ledger requested contract start."))
    end
end

function RuralLedgerScreen:onClickDebug()
    self:setSection(RuralLedgerScreen.SECTIONS.DEBUG)
end

function RuralLedgerScreen:onClickRefresh()
    if PhobosRuralLedger.refreshMapBackedState ~= nil then
        PhobosRuralLedger.refreshMapBackedState({trigger = "manualRefresh", mapReadyAttempted = true})
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

function RuralLedgerScreen:onClickAdvancePeriod()
    if self.debugVisible ~= true then
        self:updateDebug()
        return
    end

    if PhobosRuralLedger.advanceLedgerPeriod ~= nil then
        PhobosRuralLedger.advanceLedgerPeriod({mission = g_currentMission})
    end

    self:refreshModels()
    self:setSection(RuralLedgerScreen.SECTIONS.DEBUG)
    logInfo("%s", i18n("rl_log_period_advanced", "Rural Ledger period advanced from debug controls."))
end

function RuralLedgerScreen:onListSelectionChanged(list, section, index)
    if self.isReloading then
        return
    end

    if list == self.newspaperTable then
        local row = rowAtListIndex(self.cachedNewspaperRows, index)
        if row == nil then
            self.selectedNewspaperEditionId = nil
            self:refreshNewspaperEdition()
            self:updateFooterButtons()
            return
        end

        self.selectedNewspaperEditionId = row.editionId
        self:refreshNewspaperEdition()
        self:setSection(RuralLedgerScreen.SECTIONS.NEWSPAPER)
        return
    end

    if list == self.jobTable then
        local row = rowAtListIndex(self.cachedJobRows, index)
        if row == nil then
            self.selectedJobRequestId = nil
            self:refreshJobDetail()
            self:refreshOpportunities(nil)
            self:updateFooterButtons()
            return
        end

        self.selectedJobRequestId = row.requestId
        self:refreshJobDetail()
        self:refreshOpportunities(self:getContextFarmId())
        self:setSection(RuralLedgerScreen.SECTIONS.JOBS)
        return
    end

    if list ~= self.farmTable then
        return
    end

    local row = rowAtListIndex(self.cachedFarmRows, index)
    if row == nil then
        self.selectedFarmId = nil
        self:refreshFarmDetail()
        self:refreshOpportunities(nil)
        self:updateFooterButtons()
        return
    end

    self.selectedFarmId = row.farmId
    self:refreshFarmDetail()
    self:refreshOpportunities(self.selectedFarmId)
    self:setSection(RuralLedgerScreen.SECTIONS.FARMERS)
end

function RuralLedgerScreen:onListDoubleClick(list, ...)
    if self.isReloading then
        return
    end

    if list == self.newspaperTable then
        local row = rowFromListCallback(self.cachedNewspaperRows, list, ...)
        if row == nil then
            return
        end

        self.selectedNewspaperEditionId = row.editionId
        self:refreshNewspaperEdition()
        self:setSection(RuralLedgerScreen.SECTIONS.NEWSPAPER)
        self:onClickReadNewspaper()
        return
    end

    if list == self.jobTable then
        local row = rowFromListCallback(self.cachedJobRows, list, ...)
        if row == nil then
            return
        end

        self.selectedJobRequestId = row.requestId
        self:refreshJobDetail()
        self:refreshOpportunities(self:getContextFarmId())
        self:setSection(RuralLedgerScreen.SECTIONS.JOBS)
        self:onClickJobDetail()
        return
    end

    if list ~= self.farmTable then
        return
    end

    local row = rowFromListCallback(self.cachedFarmRows, list, ...)
    if row == nil then
        return
    end

    self.selectedFarmId = row.farmId
    self:refreshFarmDetail()
    self:refreshOpportunities(self.selectedFarmId)
    self:setSection(RuralLedgerScreen.SECTIONS.FARMERS)
    self:onClickFarmDetail()
end

function RuralLedgerScreen:refreshModels()
    if PhobosRuralLedger.refreshJobRequests ~= nil then
        PhobosRuralLedger.refreshJobRequests({trigger = "screen", log = false})
    end

    local state = PhobosRuralLedger.getState()

    self:adaptLayout()
    self.cachedOverview = PhobosRuralLedger.UiModels.buildOverview(state, {
        maxAlerts = RuralLedgerScreen.MAX_ALERT_LINES,
        includeDebug = self.debugVisible,
    })
    self:refreshNewspaperArchive()
    if not containsEditionId(self.cachedNewspaperRows, self.selectedNewspaperEditionId) then
        self.selectedNewspaperEditionId = nil
    end
    self.cachedFarmRows = PhobosRuralLedger.UiModels.buildFarmList(state, {
        includeDebug = self.debugVisible,
    })
    if not containsFarmId(self.cachedFarmRows, self.selectedFarmId) then
        self.selectedFarmId = nil
    end
    self:refreshJobs()
    if not containsRequestId(self.cachedJobRows, self.selectedJobRequestId) then
        self.selectedJobRequestId = nil
    end
    self:refreshFarmDetail()
    self:refreshHistory()
    self:refreshJobDetail()
    self:refreshNewspaperEdition()
    self:refreshOpportunities(self:getContextFarmId())
    self.cachedDebug = PhobosRuralLedger.UiModels.buildDebugSummary(state, {
        includeExactFarmValues = self.debugVisible,
    })
    self:buildListRows()
end

function RuralLedgerScreen:refreshNewspaperArchive()
    self.cachedNewspaper = PhobosRuralLedger.UiModels.buildNewspaperArchive(
        PhobosRuralLedger.getState(),
        {includeDebug = self.debugVisible}
    )
    self.cachedNewspaperRows = (self.cachedNewspaper or {}).rows or {}
end

function RuralLedgerScreen:refreshNewspaperEdition()
    self.cachedNewspaperEdition = PhobosRuralLedger.UiModels.buildNewspaperEdition(
        PhobosRuralLedger.getState(),
        self.selectedNewspaperEditionId,
        {includeDebug = self.debugVisible}
    )
end

function RuralLedgerScreen:refreshJobs()
    self.cachedJobRows = PhobosRuralLedger.UiModels.buildJobList(
        PhobosRuralLedger.getState(),
        {mode = self.activeJobMode, includeDebug = self.debugVisible}
    )
end

function RuralLedgerScreen:refreshFarmDetail()
    self.cachedFarmDetail = PhobosRuralLedger.UiModels.buildFarmDetail(
        PhobosRuralLedger.getState(),
        self.selectedFarmId,
        {includeDebug = self.debugVisible}
    )
    self.detailRows = (self.cachedFarmDetail or {}).lines or {}
end

function RuralLedgerScreen:refreshJobDetail()
    self.cachedJobDetail = PhobosRuralLedger.UiModels.buildJobDetail(
        PhobosRuralLedger.getState(),
        self.selectedJobRequestId,
        {includeDebug = self.debugVisible}
    )
end

function RuralLedgerScreen:getContextFarmId()
    if self.activeSection == RuralLedgerScreen.SECTIONS.FARMERS then
        return self.selectedFarmId
    elseif self.activeSection == RuralLedgerScreen.SECTIONS.JOBS then
        return (self.cachedJobDetail or {}).farmId
    end

    return nil
end

function RuralLedgerScreen:refreshOpportunities(farmId)
    self.cachedOpportunityFarmId = farmId
    self.cachedOpportunities = PhobosRuralLedger.UiModels.buildOpportunities(
        PhobosRuralLedger.getState(),
        farmId,
        {includeDebug = self.debugVisible}
    )
end

function RuralLedgerScreen:refreshHistory()
    self.cachedHistory = PhobosRuralLedger.UiModels.buildHistory(
        PhobosRuralLedger.getState(),
        self.selectedFarmId,
        {includeDebug = self.debugVisible}
    )
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
    self.debugRows = (self.cachedDebug or {}).lines or {}
end

function RuralLedgerScreen:setSection(section)
    self.activeSection = section
    self:updateDisplay()
end

function RuralLedgerScreen:updateDisplay()
    self:updateTabState()
    self:updateOverview()
    self:updateNewspaper()
    self:updateJobs()
    self:updateDebug()
    self:updateFooterButtons()
    self:reloadVisibleLists()
end

function RuralLedgerScreen:updateTabState()
    local active = self.activeSection

    setVisible(self.overviewPanel, active == RuralLedgerScreen.SECTIONS.OVERVIEW)
    setVisible(self.newspaperPanel, active == RuralLedgerScreen.SECTIONS.NEWSPAPER)
    setVisible(self.farmersPanel, active == RuralLedgerScreen.SECTIONS.FARMERS)
    setVisible(self.jobsPanel, active == RuralLedgerScreen.SECTIONS.JOBS)
    setVisible(self.debugPanel, active == RuralLedgerScreen.SECTIONS.DEBUG)

    setButtonSelected(self.overviewTab, active == RuralLedgerScreen.SECTIONS.OVERVIEW)
    setButtonSelected(self.newspaperTab, active == RuralLedgerScreen.SECTIONS.NEWSPAPER)
    setButtonSelected(self.farmersTab, active == RuralLedgerScreen.SECTIONS.FARMERS)
    setButtonSelected(self.jobsTab, active == RuralLedgerScreen.SECTIONS.JOBS)
    setButtonSelected(self.debugTab, active == RuralLedgerScreen.SECTIONS.DEBUG)
end

function RuralLedgerScreen:updateNewspaper()
    local model = self.cachedNewspaper or {}

    setText(self.newspaperTitle, model.title or i18n("rl_newspaper_title", "Local Newspaper"))
    setText(self.newspaperSubtitle, model.subtitle or i18n("rl_newspaper_subtitle", "Recent editions delivered at 06:00."))
    setText(self.newspaperEmptyText, model.emptyText or "")
    setVisible(self.newspaperEmptyText, #((model.rows) or {}) == 0)
end

function RuralLedgerScreen:updateOverview()
    local model = self.cachedOverview or {}
    local notice = model.noDataNotice or {}

    setText(self.overviewTitle, model.title or i18n("rl_ui_title", "Phobos' Rural Ledger"))
    setText(self.overviewSubtitle, i18n(
        "rl_overview_period",
        "Period %s / %s",
        tostring(model.periodLabel or model.period or "-"),
        tostring(model.regionalPresetLabel or model.regionalPreset or "-")
    ))
    setText(self.overviewNoDataNotice, notice.text or "")
    setVisible(self.overviewNoDataNotice, notice.visible == true)
end

function RuralLedgerScreen:updateJobs()
    local isNpcMode = self.activeJobMode == RuralLedgerScreen.JOB_MODES.NPC

    setText(self.jobsTitle, i18n("rl_jobs_title", "NPC Jobs"))
    setText(
        self.jobsSubtitle,
        isNpcMode
            and i18n("rl_jobs_subtitle_npc", "Grouped by NPC name, including farmers without active live contracts.")
            or i18n("rl_jobs_subtitle_plot", "Grouped by plot and field, including plots without active live contracts.")
    )
    setButtonSelected(self.jobsByNpcButton, isNpcMode)
    setButtonSelected(self.jobsByPlotButton, not isNpcMode)
end

function RuralLedgerScreen:updateDebug()
    local debugModel = self.cachedDebug or {}
    local notice = debugModel.noDataNotice or {}

    setText(self.debugTitle, debugModel.title or i18n("rl_tab_settings_debug", "Settings / Debug"))
    setText(
        self.debugModeText,
        self.debugVisible and i18n("rl_debug_exact_visible", "Exact debug values visible")
            or i18n("rl_debug_exact_hidden", "Exact debug values hidden")
    )
    setText(self.debugNoDataNotice, notice.text or "")
    setVisible(self.debugNoDataNotice, notice.visible == true)
    setVisible(self.advancePeriodButton, self.debugVisible == true)
end

function RuralLedgerScreen:updateFooterButtons()
    local canOpenDetail = self.activeSection == RuralLedgerScreen.SECTIONS.FARMERS
        and self.selectedFarmId ~= nil
    local opportunityFarmId = self:getContextFarmId()
    if opportunityFarmId ~= self.cachedOpportunityFarmId then
        self:refreshOpportunities(opportunityFarmId)
    end

    local canOpenOpportunities = (self.activeSection == RuralLedgerScreen.SECTIONS.FARMERS
        or self.activeSection == RuralLedgerScreen.SECTIONS.JOBS)
        and opportunityFarmId ~= nil
        and #(((self.cachedOpportunities or {}).opportunities) or {}) > 0
    local canOpenHistory = canOpenDetail
        and #(((self.cachedHistory or {}).history) or {}) > 0
    local canOpenJobDetail = self.activeSection == RuralLedgerScreen.SECTIONS.JOBS
        and self.selectedJobRequestId ~= nil
    local canStartContract = canOpenJobDetail
        and ((self.cachedJobDetail or {}).launchable == true)
    local canReadNewspaper = self.activeSection == RuralLedgerScreen.SECTIONS.NEWSPAPER
        and self.selectedNewspaperEditionId ~= nil

    setButtonAvailable(self.readNewspaperFooterButton, canReadNewspaper)
    setButtonAvailable(self.farmDetailFooterButton, canOpenDetail)
    setButtonAvailable(self.opportunityFooterButton, canOpenOpportunities)
    setButtonAvailable(self.historyFooterButton, canOpenHistory)
    setButtonAvailable(self.jobDetailFooterButton, canOpenJobDetail)
    setButtonAvailable(self.startContractFooterButton, canStartContract)
    invalidateLayout(self.buttonsPanel)
end

function RuralLedgerScreen:openNewspaperDialog()
    if g_gui == nil or g_gui.showDialog == nil or Constants == nil then
        return
    end

    local dialog = g_gui:showDialog(Constants.NEWSPAPER_DIALOG_NAME)
    local target = dialog ~= nil and dialog.target or nil

    if target ~= nil and target.setEdition ~= nil then
        target:setEdition(self.cachedNewspaperEdition, {source = "screenArchive"})
    end
end

function RuralLedgerScreen:openFarmDetailDialog()
    if g_gui == nil or g_gui.showDialog == nil or Constants == nil then
        return
    end

    local dialog = g_gui:showDialog(Constants.FARM_DETAIL_DIALOG_NAME)
    local target = dialog ~= nil and dialog.target or nil

    if target ~= nil and target.setFarmDetail ~= nil then
        target:setFarmDetail(self.cachedFarmDetail)
    end
end

function RuralLedgerScreen:openOpportunityDialog()
    if g_gui == nil or g_gui.showDialog == nil or Constants == nil then
        return
    end

    local dialog = g_gui:showDialog(Constants.OPPORTUNITY_DIALOG_NAME)
    local target = dialog ~= nil and dialog.target or nil

    if target ~= nil and target.setOpportunities ~= nil then
        target:setOpportunities(self.cachedOpportunities)
    end
end

function RuralLedgerScreen:openHistoryDialog()
    if g_gui == nil or g_gui.showDialog == nil or Constants == nil then
        return
    end

    local dialog = g_gui:showDialog(Constants.HISTORY_DIALOG_NAME)
    local target = dialog ~= nil and dialog.target or nil

    if target ~= nil and target.setHistory ~= nil then
        target:setHistory(self.cachedHistory)
    end
end

function RuralLedgerScreen:openJobDetailDialog()
    if g_gui == nil or g_gui.showDialog == nil or Constants == nil then
        return
    end

    local dialog = g_gui:showDialog(Constants.JOB_DETAIL_DIALOG_NAME)
    local target = dialog ~= nil and dialog.target or nil

    if target ~= nil and target.setJobDetail ~= nil then
        target:setJobDetail(self.cachedJobDetail)
    end
end

function RuralLedgerScreen:reloadVisibleLists()
    self.isReloading = true
    reloadList(self.overviewList)
    reloadList(self.newspaperTable)
    reloadList(self.farmTable)
    reloadList(self.jobTable)
    reloadList(self.debugList)
    self.isReloading = false
end

function RuralLedgerScreen:getNumberOfSections()
    return 1
end

function RuralLedgerScreen:getNumberOfItemsInSection(list, section)
    if list == self.overviewList then
        return #self.overviewRows
    elseif list == self.newspaperTable then
        return #self.cachedNewspaperRows
    elseif list == self.farmTable then
        return #self.cachedFarmRows
    elseif list == self.jobTable then
        return #self.cachedJobRows
    elseif list == self.debugList then
        return #self.debugRows
    end

    return 0
end

function RuralLedgerScreen:populateCellForItemInSection(list, section, index, cell)
    if list == self.overviewList then
        self:populateOverviewCell(index, cell)
    elseif list == self.newspaperTable then
        self:populateNewspaperCell(index, cell)
    elseif list == self.farmTable then
        self:populateFarmCell(index, cell)
    elseif list == self.jobTable then
        self:populateJobCell(index, cell)
    elseif list == self.debugList then
        self:populateTextCell(self.debugRows[index], cell)
    end
end

function RuralLedgerScreen:populateNewspaperCell(index, cell)
    local row = self.cachedNewspaperRows[index]
    if row == nil then
        return
    end

    setCellText(cell, "edition", row.deliveredText or row.dateline or "")
    setCellText(cell, "headline", row.headline or "")
    setCellText(cell, "summary", row.summary or "")
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

function RuralLedgerScreen:populateJobCell(index, cell)
    local row = self.cachedJobRows[index]
    if row == nil then
        return
    end

    setCellText(cell, "jobNpc", row.npcName)
    setCellText(cell, "jobPlot", row.plotLabel)
    setCellText(cell, "jobTitle", row.jobTitle)
    setCellText(cell, "jobStatus", row.statusLabel)
    setCellText(cell, "jobSource", row.sourceLabel)
    setCellText(cell, "jobRelation", row.relationshipLabel)
end

function RuralLedgerScreen:populateTextCell(line, cell)
    setCellText(cell, "line", line or "")
end
