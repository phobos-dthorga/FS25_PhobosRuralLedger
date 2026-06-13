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

local missingDetail = UiModels.buildFarmDetail(stateA, "missing_farm")
assertEquals(nil, missingDetail.farmId, "farm detail should not fall back to another farm when selection is missing")
assertEquals("No farm selected", missingDetail.displayName, "missing farm detail should expose the no-selection model")

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
            fieldId = id,
            farmland = farmland,
            fieldArea = id == 170 and 14.98 or 6.25,
            getName = function()
                return "Field " .. tostring(id)
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
    local fieldSource = {field170, field171, field210, {name = "Unnumbered meadow"}}

    g_currentMission = {
        missionInfo = {
            mapId = "smoke_map",
        },
    }
    g_modIsLoaded = {
        FS25_precisionFarming = true,
    }
    g_fieldManager = {
        fields = fieldSource,
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

    fakeRuntime.fields = fieldSource
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
assertEquals(4, mapDiscovery.diagnostics.rawFieldCount, "fake runtime diagnostics should count raw fields")
assertEquals(3, mapDiscovery.diagnostics.rawFarmlandCount, "fake runtime diagnostics should count raw farmlands")
assertEquals(1, mapDiscovery.diagnostics.rawMissionCount, "fake runtime diagnostics should count raw missions")
assertEquals(3, mapDiscovery.diagnostics.usableFieldCount, "fake runtime diagnostics should count usable fields")
assertEquals(1, mapDiscovery.diagnostics.skippedFieldCount, "fake runtime diagnostics should count skipped malformed fields")
assertContains(mapDiscovery.diagnostics.firstSkippedFieldReason, "fieldId", "fake runtime diagnostics should explain skipped fields")
assertEquals("owner", mapDiscovery.diagnostics.propertyGroupingMode, "small owner buckets should stay owner-grouped")
assertEquals(2, mapDiscovery.diagnostics.ownerBucketCount, "fake runtime should count owner and NPC buckets")
assertEquals(0, mapDiscovery.diagnostics.splitOwnerBucketCount, "small owner buckets should not split")

local previousMissions = g_missionManager.missions
g_missionManager.missions = {
    {
        type = {name = "transportMission"},
        status = 1,
        getMissionTypeName = function()
            return "transportMission"
        end,
    },
    "bad mission entry",
}
local missionRobustDiscovery = MapDiscovery.discover({trigger = "manualRefresh", mapReadyAttempted = true})
assertEquals(1, missionRobustDiscovery.discoveredContractCount, "nil-field missions should be retained without crashing")
assertEquals(1, missionRobustDiscovery.diagnostics.skippedMissionCount, "bad mission entries should be skipped")
assertEquals(0, missionRobustDiscovery.diagnostics.missionErrorCount, "plain bad mission entries should not become runtime errors")
g_missionManager.missions = previousMissions

local previousFarmland = fakeRuntime.fields[1].farmland
local previousFieldState = fakeRuntime.fields[1].getFieldState
fakeRuntime.fields[1].farmland = nil
fakeRuntime.fields[1].getFieldState = function()
    return {
        fruitTypeIndex = 1,
        growthState = 5,
    }
end
g_farmlandManager.getFarmlandAtWorldPosition = function()
    return 170
end
local worldPositionDiscovery = MapDiscovery.discover({trigger = "manualRefresh", mapReadyAttempted = true})
assertEquals("map", worldPositionDiscovery.source, "numeric farmland world-position lookup should still create map discovery")
assertEquals(3, worldPositionDiscovery.discoveredFarmlandCount, "numeric world-position farmland IDs should be normalized")
fakeRuntime.fields[1].farmland = previousFarmland
fakeRuntime.fields[1].getFieldState = previousFieldState
g_farmlandManager.getFarmlandAtWorldPosition = nil

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
local mapProfileIds = {}
for _, profileEntry in ipairs(mapStateA.profiles) do
    assertTrue(profileEntry.farmId ~= nil, "map profiles should expose a farm id")
    assertTrue(not mapProfileIds[profileEntry.farmId], "map profile farm ids should be unique")
    mapProfileIds[profileEntry.farmId] = true
end
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

local boundedIds = {}
for index = 1, 20 do
    boundedIds[index] = index
end
local boundedState = {
    profiles = {
        {
            farmId = "bounded",
            displayName = "Bounded Farm",
            profileType = "grain_grower",
            ownedFields = boundedIds,
            fieldIds = boundedIds,
            farmlandIds = boundedIds,
            source = "map",
            discoveryConfidence = "high",
            cropSummary = "wheat",
            fieldConditionCodes = {"tracked"},
            precisionFarmingStatus = "available_pending",
        },
    },
    ledgerSnapshots = {
        {
            farmId = "bounded",
            operatingCash = 100000,
            totalDebt = 20000,
            grossRevenue = 120000,
            seasonProfit = 12000,
            riskBuffer = 20000,
            stressState = Constants.STRESS_STATES.STABLE,
            primaryPressure = Constants.PRESSURE_TYPES.NONE,
        },
    },
}
local boundedRows = UiModels.buildFarmList(boundedState)
assertContains(boundedRows[1].fieldIdsText, "(+12 more)", "farm rows should bound long field ID lists")
local boundedDetail = UiModels.buildFarmDetail(boundedState, "bounded")
local sawBoundedDetailIds = false
for _, line in ipairs(boundedDetail.lines) do
    if string.find(line, "Field IDs") ~= nil and string.find(line, "(+8 more)", 1, true) ~= nil then
        sawBoundedDetailIds = true
    end
end
assertTrue(sawBoundedDetailIds, "farm detail should bound long field ID lists")

local mapDebug = UiModels.buildDebugSummary(mapStateA, {})
local sawDiscoveryDebug = false
for _, line in ipairs(mapDebug.lines) do
    if string.find(line, "Discovered fields") ~= nil then
        sawDiscoveryDebug = true
    end
end
assertTrue(sawDiscoveryDebug, "debug summary should expose discovery diagnostics")

clearFakeMapRuntime()

local function installOversizedOwnerRuntime()
    local farmlands = {}
    local fields = {}

    for index = 1, 30 do
        local farmland = {id = index}
        farmlands[index] = farmland
        fields[index] = {
            fieldId = index,
            farmland = farmland,
            fieldArea = 4.5,
            getName = function()
                return "Field " .. tostring(index)
            end,
            getCenterOfFieldWorldPosition = function()
                return index * 2, index * 3
            end,
            getFieldState = function()
                return {
                    isValid = true,
                    fruitTypeIndex = 1,
                    growthState = 4,
                    weedState = 0,
                    stoneLevel = 0,
                    groundType = 1,
                    sprayLevel = 1,
                    limeLevel = 1,
                    rollerLevel = 1,
                    plowLevel = 1,
                    waterLevel = 0,
                    farmlandId = index,
                    ownerFarmId = 7,
                }
            end,
        }
    end

    g_currentMission = {
        missionInfo = {
            mapId = "oversized_owner_map",
        },
    }
    g_modIsLoaded = {}
    g_fieldManager = {
        fields = fields,
    }
    g_farmlandManager = {
        getFarmlands = function()
            return farmlands
        end,
        getFarmlandOwner = function()
            return 7
        end,
    }
    g_farmManager = {
        getFarmById = function()
            return {name = "Grandpa"}
        end,
    }
    g_missionManager = {
        missions = {},
    }
    g_fruitTypeManager = {
        getFruitTypeByIndex = function()
            return {name = "wheat"}
        end,
    }
end

installOversizedOwnerRuntime()
local oversizedDiscovery = MapDiscovery.discover({trigger = "manualRefresh", mapReadyAttempted = true})
assertEquals(30, oversizedDiscovery.discoveredPropertyCount, "oversized owner buckets should split into farmland-backed properties")
assertEquals("ownerSplitByFarmland", oversizedDiscovery.diagnostics.propertyGroupingMode, "oversized discovery should record split grouping")
assertEquals(1, oversizedDiscovery.diagnostics.ownerBucketCount, "oversized discovery should count the broad owner bucket")
assertEquals(1, oversizedDiscovery.diagnostics.splitOwnerBucketCount, "oversized discovery should count the split owner bucket")
assertEquals(30, oversizedDiscovery.diagnostics.largestOwnerFieldCount, "oversized diagnostics should expose largest owner field count")
assertEquals(30, oversizedDiscovery.diagnostics.largestOwnerFarmlandCount, "oversized diagnostics should expose largest owner farmland count")
assertContains(oversizedDiscovery.properties[1].displayName, "Farmland", "split property names should include farmland identity")
local oversizedState = Persistence.createInitialState({seed = "oversized_selection", mapDiscovery = oversizedDiscovery})
Simulation.calculatePeriod(oversizedState)
local oversizedRows = UiModels.buildFarmList(oversizedState)
assertEquals(30, #oversizedRows, "oversized split state should expose one farm row per split property")
local firstOversizedDetail = UiModels.buildFarmDetail(oversizedState, oversizedRows[1].farmId)
local secondOversizedDetail = UiModels.buildFarmDetail(oversizedState, oversizedRows[2].farmId)
assertEquals(oversizedRows[1].farmId, firstOversizedDetail.farmId, "first split row should open matching detail")
assertEquals(oversizedRows[2].farmId, secondOversizedDetail.farmId, "second split row should open matching detail")
assertTrue(
    firstOversizedDetail.displayName ~= secondOversizedDetail.displayName,
    "split farm details should not collapse to the same display record"
)
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

MessageDialog = {
    new = function(target, customMt)
        local self = target or {}
        if customMt ~= nil then
            setmetatable(self, customMt)
        end

        self.closed = false
        return self
    end,
    onGuiSetupFinished = function() end,
    onOpen = function() end,
    close = function(self)
        self.closed = true
    end,
}

function Class(classObject, superClass)
    classObject.superClass = function()
        return superClass
    end

    return {
        __index = classObject,
    }
end

source("mod/src/RuralLedgerFarmDetailDialog.lua")
source("mod/src/RuralLedgerScreen.lua")

local profileLoadCalls = {}
local guiLoadCalls = {}
g_gui = {
    loadProfiles = function(_, path)
        profileLoadCalls[#profileLoadCalls + 1] = path
    end,
    loadGui = function(_, path, name, screenObject)
        guiLoadCalls[#guiLoadCalls + 1] = {
            path = path,
            name = name,
            screen = screenObject,
        }
        return true
    end,
}
source("mod/src/RuralLedgerGui.lua")
PhobosRuralLedger.Gui.modDirectory = "mod/"
PhobosRuralLedger.Gui.screenLoaded = false
PhobosRuralLedger.Gui.profilesLoaded = false
PhobosRuralLedger.Gui.farmDetailDialogLoaded = false
PhobosRuralLedger.Gui.screen = nil
assertTrue(PhobosRuralLedger.Gui:loadScreen(), "GUI loader should load profiles and screen XML")
assertEquals(1, #profileLoadCalls, "GUI profiles should load before the screen XML")
assertEquals("mod/gui/guiProfiles.xml", profileLoadCalls[1], "GUI loader should load the dedicated Rural Ledger profile file")
assertEquals(2, #guiLoadCalls, "dialog and screen XML should load once on first GUI load")
assertEquals("mod/gui/RuralLedgerFarmDetailDialog.xml", guiLoadCalls[1].path, "farm detail dialog should load before the main screen")
assertEquals(Constants.FARM_DETAIL_DIALOG_NAME, guiLoadCalls[1].name, "farm detail dialog should use the public dialog name")
assertEquals("mod/gui/RuralLedgerScreen.xml", guiLoadCalls[2].path, "screen XML should load after the dialog")
assertTrue(PhobosRuralLedger.Gui:loadScreen(), "second GUI load should reuse the cached screen")
assertEquals(1, #profileLoadCalls, "GUI profiles should not load repeatedly")
assertEquals(2, #guiLoadCalls, "dialog and screen XML should not load repeatedly")
g_gui = nil

local screen = PhobosRuralLedger.RuralLedgerScreen.new()
screen.screenContainer = {absSize = {1300}}
screen.farmersPanel = {absSize = {1300}}
screen.overviewPanel = makeElement()
screen.farmersPanel.setVisible = makeElement().setVisible
screen.debugPanel = makeElement()
screen.overviewTab = makeElement()
screen.farmersTab = makeElement()
screen.debugTab = makeElement()
screen.farmDetailFooterButton = makeElement()
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
screen.debugTitle = makeElement()
screen.debugModeText = makeElement()
screen.overviewNoDataNotice = makeElement()
screen.debugNoDataNotice = makeElement()
screen.overviewList = makeList()
screen.farmTable = makeList()
screen.debugList = makeList()

function PhobosRuralLedger.getState()
    return stateA
end

screen:onGuiSetupFinished()
assertEquals(nil, PhobosRuralLedger.RuralLedgerScreen.SECTIONS.DETAIL, "farm detail should not be a top-level section")
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
assertTrue(screen.farmDetailFooterButton.disabled, "farm detail footer action should start disabled without a selected farm")
assertTrue(screen.farmTable.onDoubleClickCallback ~= nil, "farm table should expose the SmoothList double-click callback")
assertEquals(nil, screen.farmTable.onDoubleClick, "farm table should not depend on a speculative double-click callback")
screen:onListSelectionChanged(screen.farmTable, 1, 0)
assertEquals(nil, screen.selectedFarmId, "farm selection should ignore non-row zero indices")
assertTrue(screen.farmDetailFooterButton.disabled, "farm detail footer action should remain disabled after non-row selection")
screen:onListSelectionChanged(screen.farmTable, 1, 2)
assertEquals(farmRowsA[2].farmId, screen.selectedFarmId, "farm selection should update selected farm")
assertEquals(PhobosRuralLedger.RuralLedgerScreen.SECTIONS.FARMERS, screen.activeSection, "farm selection should keep Farmers as the active top tab")
assertTrue(not screen.farmDetailFooterButton.disabled, "farm detail footer action should enable after selecting a farm")

local shownDialogs = {}
g_gui = {
    showDialog = function(_, name)
        shownDialogs[#shownDialogs + 1] = {
            name = name,
            target = {
                receivedDetail = nil,
                setFarmDetail = function(self, detail)
                    self.receivedDetail = detail
                end,
            },
        }
        return shownDialogs[#shownDialogs]
    end,
}
screen:onClickFarmDetail()
assertEquals(1, #shownDialogs, "farm detail footer action should open one dialog")
assertEquals(Constants.FARM_DETAIL_DIALOG_NAME, shownDialogs[1].name, "farm detail footer action should use the registered dialog")
assertEquals(farmRowsA[2].farmId, shownDialogs[1].target.receivedDetail.farmId, "dialog should receive the selected farm detail model")

local function farmTableElement(index)
    return {
        sectionIndex = 1,
        indexInSection = index,
    }
end

screen:onListDoubleClick(screen.farmTable, 1, 0)
assertEquals(1, #shownDialogs, "farm table double-click should ignore non-row zero indices")
assertEquals(farmRowsA[2].farmId, screen.selectedFarmId, "ignored double-click should keep the previous valid selection")
screen:onListDoubleClick(screen.farmTable, 1, 3)
assertEquals(2, #shownDialogs, "farm table double-click should open one dialog per activation")
assertEquals(farmRowsA[3].farmId, screen.selectedFarmId, "farm table double-click should select the clicked farm")
assertEquals(farmRowsA[3].farmId, shownDialogs[2].target.receivedDetail.farmId, "double-click dialog should receive the clicked farm detail model")

screen.selectedFarmId = farmRowsA[2].farmId
screen.farmTable.onDoubleClickCallback(screen.farmTable, 1, 4, farmTableElement(4), true)
assertEquals(3, #shownDialogs, "SmoothList double-click callback should open the detail dialog")
assertEquals(farmRowsA[4].farmId, screen.selectedFarmId, "SmoothList double-click callback should select the clicked row")
assertEquals(farmRowsA[4].farmId, shownDialogs[3].target.receivedDetail.farmId, "SmoothList callback dialog should receive the clicked farm detail")

screen.selectedFarmId = farmRowsA[2].farmId
screen.farmTable.onDoubleClickCallback({callbackTarget = true}, screen.farmTable, 1, 5, farmTableElement(5), true)
assertEquals(4, #shownDialogs, "target-prefixed SmoothList callback should open the detail dialog")
assertEquals(farmRowsA[5].farmId, screen.selectedFarmId, "target-prefixed SmoothList callback should select the clicked row")
assertEquals(farmRowsA[5].farmId, shownDialogs[4].target.receivedDetail.farmId, "target-prefixed callback dialog should receive the clicked farm detail")

screen.selectedFarmId = farmRowsA[2].farmId
screen.farmTable.onDoubleClickCallback({callbackTarget = true}, 1, 6, farmTableElement(6), true)
assertEquals(5, #shownDialogs, "element-backed SmoothList callback should open the detail dialog")
assertEquals(farmRowsA[6].farmId, screen.selectedFarmId, "element-backed SmoothList callback should select the clicked row")
assertEquals(farmRowsA[6].farmId, shownDialogs[5].target.receivedDetail.farmId, "element-backed callback dialog should receive the clicked farm detail")

screen.farmTable.onDoubleClickCallback(screen.farmTable, 1, 0, {sectionIndex = 1, indexInSection = 0, isHeader = true}, true)
assertEquals(5, #shownDialogs, "SmoothList double-click should ignore header cells")
assertEquals(farmRowsA[6].farmId, screen.selectedFarmId, "ignored header double-click should keep the previous valid selection")
g_gui = nil

screen.selectedFarmId = farmRowsA[2].farmId
screen:refreshModels()
screen:updateDisplay()
assertEquals(farmRowsA[2].farmId, screen.selectedFarmId, "refresh should preserve a still-valid farm selection")
assertTrue(not screen.farmDetailFooterButton.disabled, "refresh should keep the detail footer action enabled for a valid selection")
screen.selectedFarmId = "missing_farm"
screen:refreshModels()
screen:updateDisplay()
assertEquals(nil, screen.selectedFarmId, "refresh should clear a missing farm selection")
assertTrue(screen.farmDetailFooterButton.disabled, "refresh should disable the detail footer action when selection disappears")

local dialog = PhobosRuralLedger.FarmDetailDialog.new()
dialog.detailTitle = makeElement()
dialog.detailSubtitle = makeElement()
dialog.detailHeadline = makeElement()
dialog.detailCause = makeElement()
dialog.detailMeaning = makeElement()
dialog.detailList = makeList()
dialog:onGuiSetupFinished()
dialog:setFarmDetail(UiModels.buildFarmDetail(stateA, farmRowsA[1].farmId))
assertTrue(dialog.detailTitle.text ~= "", "farm detail dialog should render a selected farm title")
assertTrue(#dialog.detailRows > 0, "farm detail dialog should expose public detail rows")
assertEquals(#dialog.detailRows, dialog:getNumberOfItemsInSection(dialog.detailList, 1), "farm detail dialog list count should match detail rows")
dialog:onClickBack()
assertTrue(dialog.closed, "farm detail dialog back action should close the dialog")

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
    seed = "mission_start_smoke",
    skipMapDiscovery = true,
    discoveryTrigger = "bootstrap",
    mapReadyAttempted = false,
})
PhobosRuralLedger.missionStartDiscoveryAttempted = false
installFakeMapRuntime()
local missionStartState, missionStartRan = PhobosRuralLedger.tryMapReadyDiscovery("missionStart")
assertEquals(true, missionStartRan, "mission start should run one authoritative discovery pass")
assertEquals("map", missionStartState.mapDiscovery.source, "mission start should rebuild map-backed state")
assertEquals("missionStart", missionStartState.mapDiscovery.trigger, "mission start discovery should record its trigger")
local logsAfterMissionStart = #capturedLogs
local _, secondMissionStartRan = PhobosRuralLedger.tryMapReadyDiscovery("missionStart")
assertEquals(false, secondMissionStartRan, "mission start discovery should be bounded to one pass")
assertEquals(logsAfterMissionStart, #capturedLogs, "second mission start should not log another discovery pass")
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
