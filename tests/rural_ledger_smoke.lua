local repoRoot = arg[1] or "."

local function source(path)
    dofile(repoRoot .. "/" .. path)
end

source("mod/src/Constants.lua")
source("mod/src/I18n.lua")
source("mod/src/MapDiscovery.lua")
source("mod/src/Profiles.lua")
source("mod/src/Ledgers.lua")
source("mod/src/Simulation.lua")
source("mod/src/UiModels.lua")
source("mod/src/Reports.lua")
source("mod/src/Persistence.lua")

local Constants = PhobosRuralLedger.Constants
local I18n = PhobosRuralLedger.I18n
local Ledgers = PhobosRuralLedger.Ledgers
local MapDiscovery = PhobosRuralLedger.MapDiscovery
local Persistence = PhobosRuralLedger.Persistence
local Reports = PhobosRuralLedger.Reports
local Simulation = PhobosRuralLedger.Simulation
local UiModels = PhobosRuralLedger.UiModels
local capturedLogs = {}

PhobosFS25 = {
    Logging = {
        infoSource = function(source, message, ...)
            capturedLogs[#capturedLogs + 1] = {
                source = source,
                text = string.format(message, ...),
            }
        end,
    },
}

local function assertEquals(expected, actual, message)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTrue(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function assertContains(text, needle, message)
    assertTrue(string.find(tostring(text or ""), needle, 1, true) ~= nil, message)
end

assertEquals("Fallback 7", I18n.get("missing_key", "Fallback %d", 7), "i18n helper should format fallback text")

g_i18n = {
    getText = function(_, key)
        if key == "rl_ui_title" then
            return "Test Ledger"
        elseif key == "rl_stress_stable" then
            return "Stabil"
        end

        return key
    end,
}

assertEquals("Test Ledger", I18n.get("rl_ui_title", "Fallback"), "i18n helper should read runtime translations")
assertEquals("Stabil", UiModels.getStressLabel(Constants.STRESS_STATES.STABLE), "UI models should use runtime translations")
g_i18n = nil

local bootstrapState = Persistence.createInitialState({
    profileCount = 8,
    seed = "bootstrap_smoke",
    skipMapDiscovery = true,
    discoveryTrigger = "bootstrap",
    mapReadyAttempted = false,
})
assertEquals("none", bootstrapState.mapDiscovery.source, "bootstrap should use a safe empty discovery source")
assertEquals("bootstrap", bootstrapState.mapDiscovery.trigger, "bootstrap discovery should record its trigger")
assertTrue(not bootstrapState.mapDiscovery.mapReadyAttempted, "bootstrap should not mark map-ready discovery as attempted")
assertEquals(8, #bootstrapState.profiles, "bootstrap fallback should still create testable profiles")
local bootstrapOverview = UiModels.buildOverview(bootstrapState)
assertTrue(not bootstrapOverview.noDataNotice.visible, "bootstrap fallback should not show the no-data notice before a map-ready attempt")

local function profile(overrides)
    local result = {
        farmId = overrides.farmId,
        displayName = overrides.displayName or overrides.farmId,
        ownedFields = overrides.ownedFields or {"field_01"},
        leasedFields = overrides.leasedFields or {},
        enterpriseMix = overrides.enterpriseMix or {"grain"},
        storageRating = overrides.storageRating or 3,
        machineryRating = overrides.machineryRating or 3,
        debtAttitude = overrides.debtAttitude or "moderate",
        riskAttitude = overrides.riskAttitude or "balanced",
        relationshipScore = overrides.relationshipScore or 3,
    }

    return result
end

local stateA = Persistence.createInitialState({profileCount = 8, seed = "smoke_test"})
local stateB = Persistence.createInitialState({profileCount = 8, seed = "smoke_test"})

Simulation.calculatePeriod(stateA)
Simulation.calculatePeriod(stateB)

assertEquals(8, #stateA.ledgerSnapshots, "expected one ledger snapshot per profile")
assertEquals(
    stateA.ledgerSnapshots[1].operatingCash,
    stateB.ledgerSnapshots[1].operatingCash,
    "same seed should produce identical operating cash"
)
assertEquals(
    stateA.ledgerSnapshots[1].stressState,
    stateB.ledgerSnapshots[1].stressState,
    "same seed should produce identical stress state"
)

local report = Reports.buildEconomyReport(stateA, {maxLines = 3})
assertEquals(4, #report, "report should include a header and requested farm lines")
assertTrue(string.find(report[1], "Local economy report") ~= nil, "report should include a local economy header")
assertTrue(string.find(report[2], "cash") ~= nil, "report should include public cash band wording")

local overviewA = UiModels.buildOverview(stateA)
local overviewB = UiModels.buildOverview(stateB)
assertEquals(8, overviewA.trackedFarms, "overview should count tracked farms")
assertEquals(
    overviewA.localMarketMood,
    overviewB.localMarketMood,
    "overview should be deterministic for the same seed"
)
assertEquals(8, #overviewA.cards, "overview should expose V1 cards plus discovery context")
assertTrue(#overviewA.alerts >= 1, "overview should expose at least one alert or empty-state note")

local farmRowsA = UiModels.buildFarmList(stateA)
local farmRowsB = UiModels.buildFarmList(stateB)
assertEquals(8, #farmRowsA, "farm list should include one row per profile")
assertEquals(
    farmRowsA[1].displayName,
    farmRowsB[1].displayName,
    "farm list ordering should be deterministic"
)
assertTrue(farmRowsA[1].stressRank >= farmRowsA[#farmRowsA].stressRank, "farm list should sort by pressure first")
assertEquals("fallback", farmRowsA[1].source, "no-runtime farm rows should be marked as fallback")
assertEquals("Fallback", farmRowsA[1].sourceLabel, "no-runtime farm rows should expose fallback source label")

local publicDetail = UiModels.buildFarmDetail(stateA, farmRowsA[1].farmId)
assertEquals(farmRowsA[1].farmId, publicDetail.farmId, "farm detail should select the requested farm")
assertTrue(#publicDetail.lines >= 6, "farm detail should include public-band lines")
for _, line in ipairs(publicDetail.lines) do
    assertTrue(string.find(line, "Debug") == nil, "public farm detail must not expose debug exact values")
end

local debugDetail = UiModels.buildFarmDetail(stateA, farmRowsA[1].farmId, {includeDebug = true})
local sawDebugCash = false
for _, line in ipairs(debugDetail.lines) do
    if string.find(line, "Debug cash") ~= nil then
        sawDebugCash = true
    end
end
assertTrue(sawDebugCash, "debug farm detail should expose exact debug values only when requested")

local debugSummary = UiModels.buildDebugSummary(stateA, {includeExactFarmValues = true})
assertTrue(#debugSummary.lines >= 10, "debug summary should expose bounded diagnostics")

local noDataState = Persistence.createInitialState({
    profileCount = 8,
    seed = "missing_map_smoke",
    mapDiscovery = MapDiscovery.discover({trigger = "manualRefresh", mapReadyAttempted = true}),
})
local noDataOverview = UiModels.buildOverview(noDataState)
assertTrue(noDataOverview.noDataNotice.visible, "no-data notice should appear after a map-ready empty discovery")
assertContains(noDataOverview.noDataNotice.text, "No map data available", "no-data notice should explain the missing map data")
local noDataDebug = UiModels.buildDebugSummary(noDataState, {})
assertTrue(noDataDebug.noDataNotice.visible, "debug screen should also expose the no-data notice")

local fakeRuntime = {}

local function installFakeMapRuntime()
    local farmland170 = {
        id = 170,
        getNPC = function()
            return {name = "Walter"}
        end,
    }
    local farmland171 = {id = 171}
    local farmland210 = {
        id = 210,
        npcIndex = 210,
    }

    local function field(id, farmland, ownerFarmId, fruitTypeIndex, growthState, stateOverrides)
        local state = {
            isValid = true,
            fruitTypeIndex = fruitTypeIndex,
            growthState = growthState,
            weedState = 0,
            stoneLevel = 0,
            groundType = 1,
            sprayLevel = 1,
            sprayType = 0,
            limeLevel = 1,
            rollerLevel = 1,
            plowLevel = 1,
            stubbleShredLevel = 0,
            waterLevel = 0,
            farmlandId = farmland.id,
            ownerFarmId = ownerFarmId,
        }

        for key, value in pairs(stateOverrides or {}) do
            state[key] = value
        end

        return {
            farmland = farmland,
            getId = function()
                return id
            end,
            getName = function()
                return "Field " .. tostring(id)
            end,
            getAreaHa = function()
                return id == 170 and 14.98 or 6.25
            end,
            getCenterOfFieldWorldPosition = function()
                return id * 2, id * 3
            end,
            getFieldState = function()
                return state
            end,
        }
    end

    local field170 = field(170, farmland170, 7, 1, 5, {weedState = 2, rollerLevel = 0})
    local field171 = field(171, farmland171, 7, 2, 3)
    local field210 = field(210, farmland210, nil, 3, 4, {stoneLevel = 1, plowLevel = 0})

    g_currentMission = {
        missionInfo = {
            mapId = "smoke_map",
        },
    }
    g_modIsLoaded = {
        FS25_precisionFarming = true,
    }
    g_fieldManager = {
        fields = {field170, field171, field210},
    }
    g_farmlandManager = {
        getFarmlandOwner = function(_, farmlandId)
            return farmlandId == 170 and 7 or farmlandId == 171 and 7 or 0
        end,
        getFarmlands = function()
            return {farmland170, farmland171, farmland210}
        end,
    }
    g_farmManager = {
        getFarmById = function(_, farmId)
            if farmId == 7 then
                return {name = "Walter Farm"}
            end

            return nil
        end,
    }
    g_npcManager = {
        getNPCByIndex = function(_, npcIndex)
            if npcIndex == 210 then
                return {name = "Miller"}
            end

            return nil
        end,
    }
    g_fruitTypeManager = {
        getFruitTypeByIndex = function(_, fruitTypeIndex)
            local names = {
                [1] = {name = "wheat"},
                [2] = {name = "barley"},
                [3] = {name = "canola"},
            }

            return names[fruitTypeIndex]
        end,
    }
    g_missionManager = {
        missions = {
            {
                field = field170,
                type = {name = "baleWrapping"},
                status = 1,
                getMissionTypeName = function()
                    return "baleWrapping"
                end,
                getReward = function()
                    return 28087
                end,
                getNPC = function()
                    return {name = "Walter"}
                end,
            },
        },
    }

    fakeRuntime.fields = {field170, field171, field210}
end

local function clearFakeMapRuntime()
    g_currentMission = nil
    g_modIsLoaded = nil
    g_fieldManager = nil
    g_farmlandManager = nil
    g_farmManager = nil
    g_npcManager = nil
    g_fruitTypeManager = nil
    g_missionManager = nil
end

installFakeMapRuntime()
local mapDiscovery = MapDiscovery.discover({trigger = "mapLoad", mapReadyAttempted = true})
assertEquals("map", mapDiscovery.source, "fake runtime should create map discovery")
assertEquals("high", mapDiscovery.confidence, "owner-backed map discovery should be high confidence")
assertEquals("mapLoad", mapDiscovery.trigger, "fake runtime discovery should record its trigger")
assertTrue(mapDiscovery.mapReadyAttempted, "fake runtime discovery should mark map-ready attempt")
assertEquals(2, mapDiscovery.discoveredPropertyCount, "fake runtime should group fields into map properties")
assertEquals(3, mapDiscovery.discoveredFieldCount, "fake runtime should discover all fake fields")
assertEquals(3, mapDiscovery.discoveredFarmlandCount, "fake runtime should discover all fake farmlands")
assertEquals(1, mapDiscovery.discoveredContractCount, "fake runtime should discover fake field mission")
assertTrue(mapDiscovery.precisionFarmingAvailable, "fake runtime should detect optional Precision Farming")
assertEquals(3, mapDiscovery.diagnostics.rawFieldCount, "fake runtime diagnostics should count raw fields")
assertEquals(3, mapDiscovery.diagnostics.rawFarmlandCount, "fake runtime diagnostics should count raw farmlands")
assertEquals(1, mapDiscovery.diagnostics.rawMissionCount, "fake runtime diagnostics should count raw missions")

local mapStateA = Persistence.createInitialState({seed = "map_smoke", mapDiscovery = mapDiscovery})
local mapStateB = Persistence.createInitialState({seed = "map_smoke", mapDiscovery = mapDiscovery})
Simulation.calculatePeriod(mapStateA)
Simulation.calculatePeriod(mapStateB)
assertEquals(2, #mapStateA.profiles, "map state should create one profile per discovered property")
assertEquals("map", mapStateA.profiles[1].source, "map profile should be marked as map-sourced")
assertEquals(
    mapStateA.profiles[1].farmId,
    mapStateA.ledgerSnapshots[1].farmId,
    "ledger snapshot should use map-derived profile id"
)
assertEquals(
    mapStateA.ledgerSnapshots[1].operatingCash,
    mapStateB.ledgerSnapshots[1].operatingCash,
    "map-backed state should remain deterministic"
)

local mapRows = UiModels.buildFarmList(mapStateA)
assertEquals(2, #mapRows, "map farm list should include one row per discovered property")
assertEquals("map", mapRows[1].source, "map farm rows should expose source")
assertTrue(mapRows[1].fieldIdsText ~= "Unknown", "map farm rows should expose field IDs")
assertTrue(mapRows[1].cropSummary ~= "unknown", "map farm rows should expose crop context")

local mapOverview = UiModels.buildOverview(mapStateA)
assertEquals(8, #mapOverview.cards, "map overview should include discovery cards")
assertEquals(3, mapOverview.discovery.discoveredFields, "map overview should expose discovered field count")

local mapDetail = UiModels.buildFarmDetail(mapStateA, mapRows[1].farmId)
local sawFieldIds = false
local sawPrecisionFarming = false
for _, line in ipairs(mapDetail.lines) do
    if string.find(line, "Field IDs") ~= nil then
        sawFieldIds = true
    elseif string.find(line, "Precision Farming") ~= nil then
        sawPrecisionFarming = true
    end
end
assertTrue(sawFieldIds, "map farm detail should expose field IDs")
assertTrue(sawPrecisionFarming, "map farm detail should expose Precision Farming status")

local mapDebug = UiModels.buildDebugSummary(mapStateA, {})
local sawDiscoveryDebug = false
for _, line in ipairs(mapDebug.lines) do
    if string.find(line, "Discovered fields") ~= nil then
        sawDiscoveryDebug = true
    end
end
assertTrue(sawDiscoveryDebug, "debug summary should expose discovery diagnostics")

clearFakeMapRuntime()

local function makeElement()
    return {
        text = "",
        visible = true,
        setText = function(self, value)
            self.text = value
        end,
        setVisible = function(self, value)
            self.visible = value
        end,
        setSelected = function(self, value)
            self.selected = value
        end,
    }
end

local function makeList()
    return {
        reloads = 0,
        setDataSource = function(self, value)
            self.dataSource = value
        end,
        setDelegate = function(self, value)
            self.delegate = value
        end,
        reloadData = function(self)
            self.reloads = self.reloads + 1
        end,
    }
end

local function makeCell(names)
    local attributes = {}
    for _, name in ipairs(names) do
        attributes[name] = makeElement()
    end

    return {
        attributes = attributes,
        getAttribute = function(self, name)
            return self.attributes[name]
        end,
    }
end

ScreenElement = {
    new = function(target, customMt)
        local self = target or {}
        if customMt ~= nil then
            setmetatable(self, customMt)
        end

        return self
    end,
    onGuiSetupFinished = function() end,
    onOpen = function() end,
}

function Class(classObject, superClass)
    classObject.superClass = function()
        return superClass
    end

    return {
        __index = classObject,
    }
end

source("mod/src/RuralLedgerScreen.lua")

local screen = PhobosRuralLedger.RuralLedgerScreen.new()
screen.screenContainer = {absSize = {1300}}
screen.farmersPanel = {absSize = {1300}}
screen.overviewPanel = makeElement()
screen.farmersPanel.setVisible = makeElement().setVisible
screen.detailPanel = makeElement()
screen.debugPanel = makeElement()
screen.overviewTab = makeElement()
screen.farmersTab = makeElement()
screen.detailTab = makeElement()
screen.debugTab = makeElement()
screen.farmHeaderFarm = makeElement()
screen.farmHeaderType = makeElement()
screen.farmHeaderFields = makeElement()
screen.farmHeaderStress = makeElement()
screen.farmHeaderPressure = makeElement()
screen.farmHeaderRelation = makeElement()
screen.farmHeaderFarmCompact = makeElement()
screen.farmHeaderFieldsCompact = makeElement()
screen.farmHeaderStressCompact = makeElement()
screen.farmHeaderPressureCompact = makeElement()
screen.overviewTitle = makeElement()
screen.overviewSubtitle = makeElement()
screen.detailTitle = makeElement()
screen.detailSubtitle = makeElement()
screen.detailHeadline = makeElement()
screen.detailCause = makeElement()
screen.detailMeaning = makeElement()
screen.debugTitle = makeElement()
screen.debugModeText = makeElement()
screen.overviewNoDataNotice = makeElement()
screen.debugNoDataNotice = makeElement()
screen.overviewList = makeList()
screen.farmTable = makeList()
screen.detailList = makeList()
screen.debugList = makeList()

function PhobosRuralLedger.getState()
    return stateA
end

screen:onGuiSetupFinished()
assertTrue(screen.farmTable.dataSource == screen, "farm table should use the screen as data source")
assertEquals(#farmRowsA, screen:getNumberOfItemsInSection(screen.farmTable, 1), "farm table item count should match cached rows")

local farmCell = makeCell({
    "farmName",
    "farmType",
    "farmFields",
    "farmStress",
    "farmPressure",
    "farmRelation",
    "farmNameCompact",
    "farmFieldsCompact",
    "farmStressCompact",
    "farmPressureCompact",
})
screen:populateCellForItemInSection(screen.farmTable, 1, 1, farmCell)
assertTrue(farmCell.attributes.farmName.visible, "standard layout should show standard farm column")
assertTrue(not farmCell.attributes.farmNameCompact.visible, "standard layout should hide compact farm column")

screen.screenContainer.absSize = {900}
screen.farmersPanel.absSize = {900}
screen:adaptLayout()
screen:populateCellForItemInSection(screen.farmTable, 1, 1, farmCell)
assertTrue(not farmCell.attributes.farmType.visible, "compact layout should hide lower-priority type column")
assertTrue(not farmCell.attributes.farmRelation.visible, "compact layout should hide lower-priority relationship column")
assertTrue(farmCell.attributes.farmNameCompact.visible, "compact layout should show compact farm column")

screen.isReloading = false
screen:onListSelectionChanged(screen.farmTable, 1, 2)
assertEquals(farmRowsA[2].farmId, screen.selectedFarmId, "farm selection should update selected farm")
assertEquals(PhobosRuralLedger.RuralLedgerScreen.SECTIONS.DETAIL, screen.activeSection, "farm selection should switch to detail")

source("mod/src/PhobosRuralLedger.lua")

assertEquals(
    Constants.DEFAULT_LOG_REPORT_FARM_LINES + 2,
    #capturedLogs,
    "bootstrap logging should include discovery plus one header and the default farm line count"
)
assertEquals("PhobosRuralLedger", capturedLogs[1].source, "bootstrap log lines should use the Rural Ledger source")
assertTrue(
    string.find(capturedLogs[1].text, "Map discovery") ~= nil,
    "bootstrap log should include the discovery summary"
)
assertTrue(
    string.find(capturedLogs[2].text, "Local economy report") ~= nil,
    "bootstrap log should include the report header"
)
assertEquals("none", PhobosRuralLedger.getState().mapDiscovery.source, "bootstrap should not permanently run real discovery")
assertTrue(
    not PhobosRuralLedger.getState().mapDiscovery.mapReadyAttempted,
    "bootstrap state should remain not map-ready until a later lifecycle pass"
)

local publicReportA = PhobosRuralLedger.getEconomyReport({maxLines = 2})
local publicReportB = PhobosRuralLedger.getEconomyReport({maxLines = 2})
assertEquals(3, #publicReportA, "public economy report should include one header plus requested farm lines")
assertEquals(publicReportA[1], publicReportB[1], "public economy report should be deterministic")
publicReportA[1] = "mutated"
assertTrue(publicReportB[1] ~= "mutated", "public report access should not return shared mutable report lines")

local profileSummary = PhobosRuralLedger.getProfileSummary()
assertEquals(
    Constants.DEFAULT_PROFILE_COUNT,
    #profileSummary,
    "public profile summary should include one line per generated profile"
)

capturedLogs = {}
local logOptions = {maxLines = 2}
local loggedReport = PhobosRuralLedger.logEconomyReport(logOptions)
assertEquals(3, #loggedReport, "explicit report logging should respect maxLines")
assertEquals(3, #capturedLogs, "explicit report logging should write the bounded number of lines")
assertEquals(2, logOptions.maxLines, "report logging should not mutate caller options")
assertEquals("PhobosRuralLedger", capturedLogs[1].source, "explicit report logging should use fake PhobosLib logger")

capturedLogs = {}
installFakeMapRuntime()
local refreshedState = PhobosRuralLedger.refreshMapBackedState({trigger = "manualRefresh", mapReadyAttempted = true})
assertEquals("map", refreshedState.mapDiscovery.source, "manual refresh should rebuild map-backed state")
assertEquals("manualRefresh", refreshedState.mapDiscovery.trigger, "manual refresh should record its trigger")
assertEquals(2, #refreshedState.profiles, "manual refresh should create map-sourced profiles")
assertContains(capturedLogs[1].text, "Map discovery", "manual refresh should log one discovery summary")
local refreshedRows = UiModels.buildFarmList(refreshedState)
assertEquals("map", refreshedRows[1].source, "refreshed UI rows should remain map-sourced")
clearFakeMapRuntime()

capturedLogs = {}
PhobosRuralLedger.state = Persistence.createInitialState({
    profileCount = 8,
    seed = "screen_retry_smoke",
    skipMapDiscovery = true,
    discoveryTrigger = "bootstrap",
    mapReadyAttempted = false,
})
PhobosRuralLedger.screenOpenDiscoveryAttempted = false
installFakeMapRuntime()
screen:onOpen()
assertEquals("map", PhobosRuralLedger.getState().mapDiscovery.source, "screen open should retry discovery once when still empty")
assertEquals("screenOpenRetry", PhobosRuralLedger.getState().mapDiscovery.trigger, "screen-open retry should record its trigger")
local logsAfterFirstOpen = #capturedLogs
screen:onOpen()
assertEquals(logsAfterFirstOpen + 1, #capturedLogs, "second screen open should not run another discovery pass")
clearFakeMapRuntime()

local stable = Ledgers.calculateSnapshot(profile({
    farmId = "stable",
    ownedFields = {"f1", "f2", "f3"},
    enterpriseMix = {"grain", "livestock", "contracts"},
    storageRating = 5,
    machineryRating = 5,
    debtAttitude = "low_debt",
    riskAttitude = "steady",
    relationshipScore = 5,
}), "season_test")

local watch = Ledgers.calculateSnapshot(profile({
    farmId = "watch",
    ownedFields = {"f1", "f2"},
    enterpriseMix = {"grain", "oilseed", "livestock"},
    storageRating = 4,
    machineryRating = 4,
    debtAttitude = "moderate",
    riskAttitude = "balanced",
    relationshipScore = 3,
}), "season_test")

local strained = Ledgers.calculateSnapshot(profile({
    farmId = "strained",
    ownedFields = {"f1", "f2"},
    enterpriseMix = {"grain", "oilseed"},
    storageRating = 2,
    machineryRating = 2,
    debtAttitude = "equipment_debt",
    riskAttitude = "market_exposed",
    relationshipScore = 3,
}), "season_test")

local severe = Ledgers.calculateSnapshot(profile({
    farmId = "severe",
    ownedFields = {"f1"},
    enterpriseMix = {"grain"},
    storageRating = 1,
    machineryRating = 1,
    debtAttitude = "high_operating_debt",
    riskAttitude = "vulnerable",
    relationshipScore = 1,
}), "season_test")

assertEquals(Constants.STRESS_STATES.STABLE, stable.stressState, "stable profile should remain stable")
assertEquals(Constants.STRESS_STATES.WATCH, watch.stressState, "watch profile should enter watch state")
assertEquals(Constants.STRESS_STATES.STRAINED, strained.stressState, "strained profile should enter strained state")
assertTrue(
    severe.stressState == Constants.STRESS_STATES.DISTRESSED
        or severe.stressState == Constants.STRESS_STATES.INSOLVENT,
    "severe profile should enter a distress-style state"
)
