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
source("mod/src/Opportunities.lua")
source("mod/src/JobRequests.lua")
source("mod/src/UiModels.lua")
source("mod/src/Newspaper.lua")
source("mod/src/Reports.lua")
source("mod/src/Persistence.lua")
source("mod/src/Savegame.lua")

local Constants = PhobosRuralLedger.Constants
local I18n = PhobosRuralLedger.I18n
local Ledgers = PhobosRuralLedger.Ledgers
local MapDiscovery = PhobosRuralLedger.MapDiscovery
local Opportunities = PhobosRuralLedger.Opportunities
local JobRequests = PhobosRuralLedger.JobRequests
local Newspaper = PhobosRuralLedger.Newspaper
local Persistence = PhobosRuralLedger.Persistence
local Reports = PhobosRuralLedger.Reports
local Simulation = PhobosRuralLedger.Simulation
local UiModels = PhobosRuralLedger.UiModels
local capturedLogs = {}

local function captureLog(level, source, message, ...)
    capturedLogs[#capturedLogs + 1] = {
        level = level,
        source = source,
        text = string.format(message, ...),
    }
    return true
end

_G["Phobos" .. "FS25"] = nil
local originalPrint = print
print = function(message)
    local source, level, text = tostring(message or ""):match("^%[([^%]]+)%]%[([^%]]+)%]%s*(.*)$")
    if source ~= nil and level ~= nil then
        captureLog(level, source, "%s", text or "")
        return
    end

    originalPrint(message)
end

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
                info = {
                    profit = 28087,
                    workTime = 3600,
                    perMin = 463,
                    usage = 320,
                    leaseCost = 320,
                    delivery = "Deliver wrapped bales",
                    keep = false,
                },
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
assertEquals("Season 1", mapOverview.periodLabel, "overview should expose a player-facing period label")
assertEquals("Temperate mixed", mapOverview.regionalPresetLabel, "overview should expose a player-facing regional label")
for _, alert in ipairs(mapOverview.alerts or {}) do
    assertTrue(string.find(alert, "rl_", 1, true) == nil, "overview alerts should not leak l10n keys")
end

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

MissionStatus = {CREATED = 1, RUNNING = 2, FINISHED = 3}
BetterContracts = {
    config = {
        hardMode = true,
        hardLimit = 2,
    },
}
g_modIsLoaded.FS25_BetterContracts = true
g_currentMission.getFarmId = function()
    return 1
end
g_farmManager.getFarmById = function(_, farmId)
    if farmId == 1 then
        return {
            stats = {
                jobsLeft = 2,
            },
        }
    end

    return {name = "Walter Farm"}
end

JobRequests.refresh(mapStateA, {trigger = "job_smoke"})
assertEquals(2, #mapStateA.jobRequests, "jobs should include live contracts plus generated gap-fill rows")
assertEquals("betterContracts", mapStateA.jobDiagnostics.sourcePriority, "BetterContracts should be the preferred source when loaded")
assertEquals(1, mapStateA.jobDiagnostics.launchableRequests, "created live contracts should be launchable")
assertEquals(1, mapStateA.jobDiagnostics.generatedRequests, "properties without live contracts should receive generated requests")

local jobRowsByNpc = UiModels.buildJobList(mapStateA, {mode = "npc"})
local jobRowsByPlot = UiModels.buildJobList(mapStateA, {mode = "plot"})
assertEquals(#mapStateA.jobRequests, #jobRowsByNpc, "NPC job rows should cover every request")
assertEquals(#mapStateA.jobRequests, #jobRowsByPlot, "plot job rows should cover every request")
assertTrue(jobRowsByNpc[1].requestId ~= nil, "job rows should expose stable request ids")
for _, row in ipairs(jobRowsByNpc) do
    assertTrue(string.find(row.jobTitle, "fieldwork_support", 1, true) == nil, "generated job titles should be localized for players")
    assertTrue(string.find(row.jobTitle, "_request", 1, true) == nil, "generated job titles should not leak internal request codes")
end

local launchableRequest = nil
for _, request in ipairs(mapStateA.jobRequests) do
    if request.launchable == true then
        launchableRequest = request
        break
    end
end
assertTrue(launchableRequest ~= nil, "fake runtime should produce one launchable live contract")

local sentEvents = {}
MissionStartEvent = {
    new = function(mission, farmId, hasLeasing)
        return {
            mission = mission,
            farmId = farmId,
            hasLeasing = hasLeasing,
        }
    end,
}
g_client = {
    getServerConnection = function()
        return {
            sendEvent = function(_, event)
                sentEvents[#sentEvents + 1] = event
            end,
        }
    end,
}
local canStart, startReason = JobRequests.canStartContract(mapStateA, launchableRequest.requestId)
assertEquals(true, canStart, "launchable live contract should pass start checks")
assertEquals("ready", startReason, "launchable live contract should report ready")
local launchableJobDetail = UiModels.buildJobDetail(mapStateA, launchableRequest.requestId)
local detailText = table.concat(launchableJobDetail.rows, "\n")
assertContains(detailText, "Estimated field area", "job detail should include estimated field area")
assertContains(detailText, "Estimated profit", "job detail should include enriched profit")
assertContains(detailText, "Estimated work time", "job detail should include enriched work time")
assertContains(detailText, "Profit per minute", "job detail should include enriched profit per minute")
assertContains(detailText, "Usage cost", "job detail should include BetterContracts usage cost")
assertContains(detailText, "BetterContracts monthly jobs left", "job detail should explain monthly start capacity")
local started, launchStatus = JobRequests.startContract(mapStateA, launchableRequest.requestId)
assertEquals(true, started, "start contract should dispatch the normal MissionStartEvent")
assertEquals("started", launchStatus, "start contract should report a started status")
assertEquals(1, #sentEvents, "start contract should send one event")
assertEquals(false, sentEvents[1].hasLeasing, "first launch slice should not lease equipment")
assertEquals(1, sentEvents[1].jobsLeft, "BetterContracts monthly jobsLeft should be mirrored on the event")

g_farmManager.getFarmById = function()
    return {
        stats = {
            jobsLeft = 0,
        },
    }
end
local monthlyOk, monthlyReason = JobRequests.canStartContract(mapStateA, launchableRequest.requestId)
assertEquals(false, monthlyOk, "BetterContracts hard monthly limit should block launch")
assertEquals("monthly_job_limit", monthlyReason, "monthly limit should return a localized reason key")

local launchedProfile = nil
for _, profileEntry in ipairs(mapStateA.profiles) do
    if tostring(profileEntry.farmId or "") == tostring(launchableRequest.farmId or "") then
        launchedProfile = profileEntry
        break
    end
end
assertTrue(launchedProfile ~= nil, "launchable request should map back to a profile")
local beforeRelationship = launchedProfile.relationshipScore or 3
function PhobosRuralLedger.getState()
    return mapStateA
end
JobRequests.recordMissionOutcome(launchableRequest.missionRef, true)
assertEquals(math.min(5, beforeRelationship + 1), launchedProfile.relationshipScore, "successful linked job should raise relationship one band")
assertTrue(#mapStateA.jobHistory > 0, "job outcome should append bounded job history")

MissionStartEvent = nil
g_client = nil
BetterContracts = nil
MissionStatus = nil
g_modIsLoaded.FS25_BetterContracts = nil

local opportunityState = {
    periodId = "season_0001",
    mapDiscovery = {source = "map"},
    profiles = {},
    ledgerSnapshots = {},
    opportunities = {},
    eventHistory = {},
    cooldowns = {},
}
for index = 1, 14 do
    local farmId = string.format("opp_farm_%02d", index)
    opportunityState.profiles[index] = {
        farmId = farmId,
        displayName = string.format("Opportunity Farm %02d", index),
        profileType = "grain_grower",
        ownedFields = {index},
        fieldIds = {index},
        farmlandIds = {index},
        source = "map",
        discoveryConfidence = "high",
        cropSummary = "wheat",
        fieldConditionCodes = {"tracked"},
        storageRating = 2,
        machineryRating = 2,
        relationshipScore = 3,
    }
    opportunityState.ledgerSnapshots[index] = {
        farmId = farmId,
        operatingCash = -25000 - index,
        totalDebt = 140000,
        grossRevenue = 80000,
        seasonProfit = -12000,
        riskBuffer = 2000,
        stressScore = 70 + index,
        stressState = index == 1 and Constants.STRESS_STATES.INSOLVENT or Constants.STRESS_STATES.STRAINED,
        primaryPressure = Constants.PRESSURE_TYPES.NEGATIVE_CASH,
    }
end
local generatedOpportunities = Opportunities.reconcile(opportunityState)
assertEquals(Constants.MAX_ACTIVE_OPPORTUNITIES, #generatedOpportunities, "opportunity generation should respect the global cap")
assertEquals(Constants.MAX_ACTIVE_OPPORTUNITIES, #opportunityState.eventHistory, "new opportunities should write bounded event history")
assertEquals("opp_farm_01", generatedOpportunities[1].farmId, "highest severity farm should receive the first opportunity")
assertEquals("season_0002", generatedOpportunities[1].expiresPeriod, "opportunities should expire in the next period")
local repeatedOpportunities = Opportunities.reconcile(opportunityState)
assertEquals(Constants.MAX_ACTIVE_OPPORTUNITIES, #repeatedOpportunities, "reconcile should retain existing opportunities without duplicates")
assertEquals(Constants.MAX_ACTIVE_OPPORTUNITIES, #opportunityState.eventHistory, "reconcile should not add duplicate history for retained opportunities")

local fallbackOpportunityState = {
    periodId = "season_0001",
    mapDiscovery = {source = "fallback"},
    profiles = opportunityState.profiles,
    ledgerSnapshots = opportunityState.ledgerSnapshots,
    opportunities = {},
    eventHistory = {},
    cooldowns = {},
}
Opportunities.reconcile(fallbackOpportunityState)
assertEquals(0, #fallbackOpportunityState.opportunities, "fallback profiles should not generate public opportunities by default")

local opportunityRows = UiModels.buildFarmList(opportunityState)
assertTrue(opportunityRows[1].activeOpportunityCount > 0, "farm rows should expose selected-property opportunity counts")
local opportunityDetail = UiModels.buildFarmDetail(opportunityState, "opp_farm_01")
assertTrue(#opportunityDetail.opportunities > 0, "farm detail should include read-only opportunity views")
assertContains(opportunityDetail.explanation.playerMeaning, "read-only", "farm detail should explain read-only opportunities")
local opportunityModel = UiModels.buildOpportunities(opportunityState, "opp_farm_01")
assertEquals("opp_farm_01", opportunityModel.farmId, "opportunity dialog model should match the selected farm")
assertTrue(#opportunityModel.rows >= 3, "opportunity dialog model should include candidate rows")
local missingOpportunityModel = UiModels.buildOpportunities(opportunityState, "missing")
assertEquals(nil, missingOpportunityModel.farmId, "missing opportunity model should not fall back to another farm")
local historyModel = UiModels.buildHistory(opportunityState, "opp_farm_01")
assertEquals("opp_farm_01", historyModel.farmId, "history dialog model should match the selected farm")
assertTrue(#historyModel.history > 0, "history model should expose public farm history events")
assertTrue(#historyModel.rows > 0, "history dialog model should include display rows")
local missingHistoryModel = UiModels.buildHistory(opportunityState, "missing")
assertEquals(nil, missingHistoryModel.farmId, "missing history model should not fall back to another farm")

local clockHours = Newspaper.readClock({environment = {currentDay = 2, dayTime = 6}})
assertEquals(true, clockHours.available, "newspaper clock should read hour-shaped dayTime")
assertEquals(360, clockHours.minute, "hour-shaped dayTime should normalize to minutes")
local clockMinutes = Newspaper.readClock({environment = {currentDay = 2, dayTime = 361}})
assertEquals("minutes", clockMinutes.source, "minute-shaped dayTime should be detected")
assertEquals(361, clockMinutes.minute, "minute-shaped dayTime should remain minutes")
local clockMilliseconds = Newspaper.readClock({environment = {currentDay = 2, dayTime = 21600000}})
assertEquals("milliseconds", clockMilliseconds.source, "millisecond-shaped dayTime should be detected")
assertEquals(360, clockMilliseconds.minute, "millisecond-shaped dayTime should normalize to minutes")

local newspaperState = {
    periodId = opportunityState.periodId,
    regionalPreset = Constants.DEFAULT_REGIONAL_PRESET,
    mapDiscovery = opportunityState.mapDiscovery,
    profiles = opportunityState.profiles,
    ledgerSnapshots = opportunityState.ledgerSnapshots,
    opportunities = opportunityState.opportunities,
    eventHistory = opportunityState.eventHistory,
    jobRequests = {},
    jobHistory = {},
    newspaper = Newspaper.createEmptyState(),
}
local loadAfterSixEdition, loadAfterSixStatus = Newspaper.deliverIfDue(newspaperState, {
    clock = {available = true, day = 123, minute = 1271, source = "minutes", timeLabel = "21:11"},
    trigger = "mapLoad",
})
assertEquals(nil, loadAfterSixEdition, "newspaper should not catch up when the first loaded clock sample is after 06:00")
assertEquals("baseline", loadAfterSixStatus, "first loaded clock sample after 06:00 should only establish the baseline")
assertEquals(0, #newspaperState.newspaper.editions, "after-06 load baseline should not add an archive edition")
newspaperState.newspaper = Newspaper.createEmptyState()
local beforeEdition, beforeStatus = Newspaper.deliverIfDue(newspaperState, {
    clock = {available = true, day = 7, minute = Constants.NEWSPAPER_DELIVERY_MINUTE - 1, source = "minutes"},
})
assertEquals(nil, beforeEdition, "newspaper should not deliver before 06:00")
assertEquals("baseline", beforeStatus, "first pre-delivery check should establish the baseline")
local exactEdition, exactStatus = Newspaper.deliverIfDue(newspaperState, {
    clock = {available = true, day = 7, minute = Constants.NEWSPAPER_DELIVERY_MINUTE, source = "minutes"},
})
assertEquals("delivered", exactStatus, "newspaper should deliver when an existing baseline crosses exactly 06:00")
assertEquals("daily_0007", exactEdition.editionId, "newspaper edition ID should be day-stable")
assertEquals(exactEdition.editionId, newspaperState.newspaper.pendingEditionId, "newspaper delivery should queue the latest edition")
assertEquals(1, #newspaperState.newspaper.editions, "newspaper delivery should add one archive edition")
local duplicateEdition, duplicateStatus = Newspaper.deliverIfDue(newspaperState, {
    clock = {available = true, day = 7, minute = 720, source = "minutes"},
})
assertEquals(nil, duplicateEdition, "newspaper should not duplicate same-day delivery")
assertEquals("not_due", duplicateStatus, "same-day duplicate check should report not due")
assertTrue(Newspaper.markPendingShown(newspaperState, exactEdition.editionId), "marking a pending paper as shown should clear pending state")
assertEquals(nil, newspaperState.newspaper.pendingEditionId, "shown newspaper should no longer be pending")

local sleepJumpState = {
    periodId = opportunityState.periodId,
    regionalPreset = Constants.DEFAULT_REGIONAL_PRESET,
    mapDiscovery = opportunityState.mapDiscovery,
    profiles = opportunityState.profiles,
    ledgerSnapshots = opportunityState.ledgerSnapshots,
    opportunities = opportunityState.opportunities,
    eventHistory = opportunityState.eventHistory,
    jobRequests = {},
    newspaper = Newspaper.createEmptyState({lastCheckedDay = 8, lastCheckedMinute = 300}),
}
local sleepEdition, sleepStatus = Newspaper.deliverIfDue(sleepJumpState, {
    clock = {available = true, day = 8, minute = 480, source = "minutes"},
})
assertEquals("delivered", sleepStatus, "newspaper should deliver after a sleep-style jump past 06:00")
assertEquals(true, sleepJumpState.newspaper.diagnostics.crossedDelivery, "sleep jump delivery should record that 06:00 was crossed")

local baselineOnlyState = {
    periodId = opportunityState.periodId,
    mapDiscovery = opportunityState.mapDiscovery,
    profiles = opportunityState.profiles,
    ledgerSnapshots = opportunityState.ledgerSnapshots,
    opportunities = opportunityState.opportunities,
    eventHistory = opportunityState.eventHistory,
    jobRequests = {},
    newspaper = Newspaper.createEmptyState({lastCheckedDay = 9, lastCheckedMinute = Constants.NEWSPAPER_DELIVERY_MINUTE - 1}),
}
local baselineOnlyEdition, baselineOnlyStatus = Newspaper.deliverIfDue(baselineOnlyState, {
    clock = {available = true, day = 9, minute = Constants.NEWSPAPER_DELIVERY_MINUTE, source = "minutes"},
    baselineOnly = true,
})
assertEquals(nil, baselineOnlyEdition, "baseline-only lifecycle checks should not deliver even when 06:00 is crossed")
assertEquals("baseline", baselineOnlyStatus, "baseline-only lifecycle checks should report baseline status")
assertEquals(0, #baselineOnlyState.newspaper.editions, "baseline-only lifecycle checks should not add archive editions")

local archiveState = newspaperState
for day = 8, 16 do
    archiveState.newspaper.pendingEditionId = nil
    Newspaper.deliverIfDue(archiveState, {
        clock = {available = true, day = day, minute = Constants.NEWSPAPER_DELIVERY_MINUTE, source = "minutes"},
    })
end
assertEquals(Constants.MAX_NEWSPAPER_EDITIONS, #archiveState.newspaper.editions, "newspaper archive should cap to the latest seven editions")
assertEquals(16, archiveState.newspaper.editions[1].day, "newspaper archive should keep newest editions first")
assertEquals(10, archiveState.newspaper.editions[#archiveState.newspaper.editions].day, "newspaper archive should drop oldest editions past the cap")

local archiveModel = UiModels.buildNewspaperArchive(archiveState)
assertEquals(Constants.MAX_NEWSPAPER_EDITIONS, #archiveModel.rows, "newspaper archive UI model should expose capped rows")
local editionModel = UiModels.buildNewspaperEdition(archiveState, archiveModel.rows[1].editionId)
assertTrue(#editionModel.rows >= 5, "newspaper edition model should include article sections")
assertTrue(string.find(editionModel.headline, "rl_", 1, true) == nil, "newspaper headline should not leak l10n keys")
for _, row in ipairs(editionModel.rows) do
    assertTrue(string.find(row.title or "", "rl_", 1, true) == nil, "newspaper section title should not leak l10n keys")
    assertTrue(string.find(row.body or "", "rl_", 1, true) == nil, "newspaper section body should not leak l10n keys")
end
local unavailableEdition, unavailableStatus, unavailableClock = Newspaper.deliverIfDue({
    newspaper = Newspaper.createEmptyState(),
}, {clock = {available = false, reason = "clock_missing", source = "unavailable"}})
assertEquals(nil, unavailableEdition, "unavailable clock should not create an edition")
assertEquals("clock_unavailable", unavailableStatus, "unavailable clock should report diagnostics status")
assertEquals("clock_missing", unavailableClock.reason, "unavailable clock should preserve the reason")
opportunityState.newspaper = archiveState.newspaper

local advanceState = {
    periodId = "season_0001",
    mapDiscovery = {source = "map"},
    profiles = opportunityState.profiles,
    ledgerSnapshots = opportunityState.ledgerSnapshots,
    opportunities = {},
    eventHistory = {},
    cooldowns = {},
}
Opportunities.reconcile(advanceState)
local advanceSummary = Opportunities.advancePeriod(advanceState)
assertEquals("season_0002", advanceState.periodId, "period advance should move to the next deterministic period")
assertTrue(advanceSummary.expiredOpportunities > 0, "period advance should expire one-period read-only opportunities")
assertTrue(#advanceState.eventHistory >= advanceSummary.expiredOpportunities, "period advance should write bounded history for expired opportunities")

local savedXmlFile = nil
local currentXmlFile = nil
local function markNode(file, key)
    local nodeKey = string.match(key, "^(.-)#") or key
    file.nodes[nodeKey] = true
    file.nodes[key] = true
end

local function installFakeXmlFile()
    XMLFile = {
        create = function(label, filename, rootKey)
            savedXmlFile = {
                label = label,
                filename = filename,
                rootKey = rootKey,
                values = {},
                nodes = {},
                saved = false,
                deleted = false,
                hasProperty = function(self, key)
                    return self.nodes[key] == true
                end,
                getString = function(self, key, defaultValue)
                    local value = self.values[key]
                    return value ~= nil and tostring(value) or defaultValue
                end,
                getInt = function(self, key, defaultValue)
                    local value = tonumber(self.values[key])
                    return value ~= nil and math.floor(value) or defaultValue
                end,
                getBool = function(self, key, defaultValue)
                    local value = self.values[key]
                    if value == nil then
                        return defaultValue
                    end
                    return value == true or value == "true"
                end,
                setString = function(self, key, value)
                    self.values[key] = tostring(value)
                    markNode(self, key)
                    return true
                end,
                setInt = function(self, key, value)
                    self.values[key] = tonumber(value)
                    markNode(self, key)
                    return true
                end,
                setBool = function(self, key, value)
                    self.values[key] = value == true and "true" or "false"
                    markNode(self, key)
                    return true
                end,
                save = function(self)
                    self.saved = true
                    return true
                end,
                delete = function(self)
                    self.deleted = true
                    return true
                end,
            }
            savedXmlFile.nodes[rootKey] = true
            currentXmlFile = savedXmlFile
            return savedXmlFile
        end,
        loadIfExists = function()
            return currentXmlFile
        end,
    }
end

g_currentMission = {
    missionInfo = {
        savegameDirectory = "savegame",
    },
}
installFakeXmlFile()
opportunityState.relationshipOverrides = {
    ["npc:test_farmer"] = 4,
}
opportunityState.jobHistory = {
    JobRequests.normalizeHistory({
        eventId = "job_history_smoke",
        periodId = "season_0001",
        requestId = "job_smoke_001",
        farmId = "opp_farm_01",
        npcKey = "npc:test_farmer",
        npcName = "Test Farmer",
        farmlandId = 1,
        fieldId = 1,
        type = "job_outcome",
        status = "completed",
        relationshipDelta = 1,
        message = "Smoke job completed.",
    }),
}
local saved, saveStatus = PhobosRuralLedger.Savegame.write(opportunityState)
assertEquals(true, saved, "opportunity savegame write should succeed with fake XMLFile helpers")
assertEquals("saved", saveStatus, "opportunity savegame write should report saved status")
assertEquals("savegame/FS25_PhobosRuralLedger.xml", savedXmlFile.filename, "savegame write should target the dedicated Rural Ledger XML file")
local saveDiagnostics = PhobosRuralLedger.Savegame.getDiagnostics()
assertEquals("saved (savegame/FS25_PhobosRuralLedger.xml)", saveDiagnostics.lastSave, "save diagnostics should expose the last saved path")
assertEquals("XMLFile", saveDiagnostics.xmlAdapterSource, "Rural Ledger should use the direct FS25 XMLFile adapter")
assertEquals("missionInfo", saveDiagnostics.pathSource, "save diagnostics should report the local missionInfo path source")
assertEquals(Constants.MAX_NEWSPAPER_EDITIONS, saveDiagnostics.lastSaveCounts.newspaperEditions, "save diagnostics should include newspaper edition counts")
local loadedSave, loadStatus = PhobosRuralLedger.Savegame.read()
assertEquals("loaded", loadStatus, "opportunity savegame read should load the fake XML file")
assertEquals(Constants.MAX_ACTIVE_OPPORTUNITIES, #loadedSave.opportunities, "savegame read should round-trip opportunities")
assertEquals(Constants.MAX_ACTIVE_OPPORTUNITIES, #loadedSave.eventHistory, "savegame read should round-trip event history")
assertEquals(1, #loadedSave.jobHistory, "savegame read should round-trip job history")
assertEquals(4, loadedSave.relationshipOverrides["npc:test_farmer"], "savegame read should round-trip relationship overrides")
assertEquals(Constants.MAX_NEWSPAPER_EDITIONS, #loadedSave.newspaper.editions, "savegame read should round-trip newspaper editions")
assertEquals(16, loadedSave.newspaper.editions[1].day, "savegame read should preserve newest newspaper edition first")
assertEquals(generatedOpportunities[1].farmId, loadedSave.opportunities[1].farmId, "savegame read should preserve opportunity farm identity")
saveDiagnostics = PhobosRuralLedger.Savegame.getDiagnostics()
assertEquals("loaded (savegame/FS25_PhobosRuralLedger.xml)", saveDiagnostics.lastLoad, "save diagnostics should expose the last loaded path")
assertEquals(Constants.MAX_ACTIVE_OPPORTUNITIES, saveDiagnostics.lastLoadCounts.opportunities, "load diagnostics should include opportunity counts")
assertEquals(1, saveDiagnostics.lastLoadCounts.jobHistory, "load diagnostics should include job history counts")
assertEquals(1, saveDiagnostics.lastLoadCounts.relationships, "load diagnostics should include relationship counts")
assertEquals(Constants.MAX_NEWSPAPER_EDITIONS, saveDiagnostics.lastLoadCounts.newspaperEditions, "load diagnostics should include newspaper edition counts")

currentXmlFile = XMLFile.create("MissingNewspaperSmoke", "savegame/FS25_PhobosRuralLedger.xml", Constants.SAVE_KEYS.ROOT)
currentXmlFile:setInt(Constants.SAVE_KEYS.ROOT .. "#schemaVersion", Constants.SAVE_SCHEMA_VERSION)
currentXmlFile:setString(Constants.SAVE_KEYS.ROOT .. "#modVersion", "0.1.8.1")
currentXmlFile:setString(Constants.SAVE_KEYS.ROOT .. ".state#periodId", "season_0001")
local noPaperSave, noPaperStatus = PhobosRuralLedger.Savegame.read()
assertEquals("loaded", noPaperStatus, "savegame read should tolerate saves without newspaper nodes")
assertEquals(0, #noPaperSave.newspaper.editions, "missing newspaper nodes should load as an empty archive")
assertEquals(nil, noPaperSave.newspaper.pendingEditionId, "missing newspaper nodes should not create pending delivery")

currentXmlFile = XMLFile.create("PendingMigrationSmoke", "savegame/FS25_PhobosRuralLedger.xml", Constants.SAVE_KEYS.ROOT)
currentXmlFile:setInt(Constants.SAVE_KEYS.ROOT .. "#schemaVersion", Constants.SAVE_SCHEMA_VERSION)
currentXmlFile:setString(Constants.SAVE_KEYS.ROOT .. "#modVersion", "0.1.9.0")
currentXmlFile:setString(Constants.SAVE_KEYS.ROOT .. ".state#periodId", "season_0001")
local oldPaperRoot = Constants.SAVE_KEYS.ROOT .. ".newspaper"
currentXmlFile:setInt(oldPaperRoot .. "#lastDeliveredDay", 123)
currentXmlFile:setInt(oldPaperRoot .. "#lastCheckedDay", 123)
currentXmlFile:setInt(oldPaperRoot .. "#lastCheckedMinute", 1271)
currentXmlFile:setString(oldPaperRoot .. "#pendingEditionId", "daily_0123")
currentXmlFile:setString(oldPaperRoot .. ".edition(0)#editionId", "daily_0123")
currentXmlFile:setInt(oldPaperRoot .. ".edition(0)#day", 123)
currentXmlFile:setInt(oldPaperRoot .. ".edition(0)#deliveryMinute", Constants.NEWSPAPER_DELIVERY_MINUTE)
currentXmlFile:setString(oldPaperRoot .. ".edition(0)#dateline", "Day 123, 06:00 edition")
currentXmlFile:setString(oldPaperRoot .. ".edition(0)#masthead", "The Rural Ledger")
currentXmlFile:setString(oldPaperRoot .. ".edition(0)#headline", "Accidental Load Paper")
currentXmlFile:setString(oldPaperRoot .. ".edition(0)#summary", "Saved from v0.1.9.0")
local migratedPaperSave, migratedPaperStatus = PhobosRuralLedger.Savegame.read()
assertEquals("loaded", migratedPaperStatus, "savegame read should load v0.1.9.0 newspaper data")
assertEquals(1, #migratedPaperSave.newspaper.editions, "v0.1.9.0 migration should preserve archived editions")
assertEquals(nil, migratedPaperSave.newspaper.pendingEditionId, "v0.1.9.0 migration should clear stale pending newspaper auto-open state")

currentXmlFile = nil
local missingSave, missingStatus = PhobosRuralLedger.Savegame.read()
assertEquals(nil, missingSave, "missing savegame read should return nil data")
assertEquals("missing", missingStatus, "missing savegame read should report missing status")
saveDiagnostics = PhobosRuralLedger.Savegame.getDiagnostics()
assertEquals("missing (savegame/FS25_PhobosRuralLedger.xml)", saveDiagnostics.lastLoad, "save diagnostics should expose missing-save paths")

g_currentMission = {
    missionInfo = {
        savegameDirectory = "fallbackSave",
    },
}
local fallbackSaved, fallbackStatus = PhobosRuralLedger.Savegame.write(opportunityState)
assertEquals(true, fallbackSaved, "opportunity savegame write should use missionInfo fallback paths")
assertEquals("saved", fallbackStatus, "fallback savegame write should report saved status")
assertEquals("fallbackSave/FS25_PhobosRuralLedger.xml", savedXmlFile.filename, "fallback savegame write should normalize missionInfo paths")
saveDiagnostics = PhobosRuralLedger.Savegame.getDiagnostics()
assertEquals("missionInfo", saveDiagnostics.pathSource, "save diagnostics should report the local missionInfo fallback source")
g_currentMission = nil

XMLFile = nil
local unavailableSaved, unavailableStatus, unavailableDetails = PhobosRuralLedger.Savegame.write(opportunityState)
assertEquals(false, unavailableSaved, "savegame write should fail clearly when XMLFile is unavailable")
assertEquals("unavailable", unavailableStatus, "unavailable savegame write should report unavailable status")
assertEquals("xml_api_unavailable", unavailableDetails.reason, "unavailable savegame write should expose the missing XMLFile reason")

PhobosRuralLedger.Savegame._resetDiagnosticsForTests()
savedXmlFile = nil
currentXmlFile = nil
g_currentMission = {
    missionInfo = {
        savegameDirectory = "directXml",
    },
}
installFakeXmlFile()
local directSaved, directStatus = PhobosRuralLedger.Savegame.write(opportunityState)
assertEquals(true, directSaved, "direct XMLFile adapter should save opportunity state")
assertEquals("saved", directStatus, "direct XMLFile adapter should report saved status")
assertEquals("directXml/FS25_PhobosRuralLedger.xml", savedXmlFile.filename, "direct XMLFile adapter should target the dedicated XML file")
saveDiagnostics = PhobosRuralLedger.Savegame.getDiagnostics()
assertEquals("XMLFile", saveDiagnostics.xmlAdapterSource, "save diagnostics should expose the direct XMLFile adapter")
local directLoaded, directLoadStatus = PhobosRuralLedger.Savegame.read()
assertEquals("loaded", directLoadStatus, "direct XMLFile adapter should load opportunity state")
assertEquals(Constants.MAX_ACTIVE_OPPORTUNITIES, #directLoaded.opportunities, "direct XMLFile adapter should round-trip opportunities")
assertEquals(generatedOpportunities[1].farmId, directLoaded.opportunities[1].farmId, "direct XMLFile adapter should preserve opportunity farm identity")
g_currentMission = nil
XMLFile = nil

-- Retired shared-library globals must not be required for any save path.
assertEquals(nil, _G["Phobos" .. "FS25"], "Rural Ledger smoke tests should not install retired shared-library globals")

PhobosRuralLedger.Savegame._resetDiagnosticsForTests()
local originalSaveCalls = 0
local appendedSaveCalls = 0
local lastHookMission = nil
FSBaseMission = {
    saveSavegame = function()
        originalSaveCalls = originalSaveCalls + 1
    end,
}
Utils = {
    appendedFunction = function(original, appended)
        return function(...)
            original(...)
            appended(...)
        end
    end,
}
local previousSaveOpportunityState = PhobosRuralLedger.saveOpportunityState
PhobosRuralLedger.saveOpportunityState = function(mission)
    appendedSaveCalls = appendedSaveCalls + 1
    lastHookMission = mission
    return true
end
local hookRegistered, hookStatus = PhobosRuralLedger.Savegame.ensureHookRegistered()
assertEquals(true, hookRegistered, "save hook should register when FSBaseMission and Utils are available")
assertEquals("registered", hookStatus, "save hook should report registered status")
assertEquals("FSBaseMission.saveSavegame", PhobosRuralLedger.Savegame.hookTarget, "save hook should prefer FSBaseMission")
local secondHookRegistered, secondHookStatus = PhobosRuralLedger.Savegame.ensureHookRegistered()
assertEquals(true, secondHookRegistered, "second save hook registration call should remain successful")
assertEquals("already_registered", secondHookStatus, "second save hook registration should be idempotent")
FSBaseMission.saveSavegame("missionFromHook")
assertEquals(1, originalSaveCalls, "save hook should preserve the original save function")
assertEquals(1, appendedSaveCalls, "save hook should append exactly one Rural Ledger save callback")
assertEquals("missionFromHook", lastHookMission, "save hook should pass the mission/self argument through")
local hookDiagnostics = PhobosRuralLedger.Savegame.getDiagnostics()
assertEquals("already_registered", hookDiagnostics.hookStatus, "save diagnostics should expose idempotent hook state")
assertEquals(1, hookDiagnostics.hookAttempts, "save hook should not retry after successful registration")
PhobosRuralLedger.saveOpportunityState = previousSaveOpportunityState
FSBaseMission = nil
Utils = nil

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
source("mod/src/RuralLedgerOpportunityDialog.lua")
source("mod/src/RuralLedgerHistoryDialog.lua")
source("mod/src/RuralLedgerJobDetailDialog.lua")
source("mod/src/RuralLedgerNewspaperDialog.lua")
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
PhobosRuralLedger.Gui.opportunityDialogLoaded = false
PhobosRuralLedger.Gui.historyDialogLoaded = false
PhobosRuralLedger.Gui.jobDetailDialogLoaded = false
PhobosRuralLedger.Gui.newspaperDialogLoaded = false
PhobosRuralLedger.Gui.screen = nil
assertTrue(PhobosRuralLedger.Gui:loadScreen(), "GUI loader should load profiles and screen XML")
assertEquals(1, #profileLoadCalls, "GUI profiles should load before the screen XML")
assertEquals("mod/gui/guiProfiles.xml", profileLoadCalls[1], "GUI loader should load the dedicated Rural Ledger profile file")
assertEquals(6, #guiLoadCalls, "dialogs and screen XML should load once on first GUI load")
assertEquals("mod/gui/RuralLedgerFarmDetailDialog.xml", guiLoadCalls[1].path, "farm detail dialog should load before the main screen")
assertEquals(Constants.FARM_DETAIL_DIALOG_NAME, guiLoadCalls[1].name, "farm detail dialog should use the public dialog name")
assertEquals("mod/gui/RuralLedgerOpportunityDialog.xml", guiLoadCalls[2].path, "opportunity dialog should load before the main screen")
assertEquals(Constants.OPPORTUNITY_DIALOG_NAME, guiLoadCalls[2].name, "opportunity dialog should use the public dialog name")
assertEquals("mod/gui/RuralLedgerHistoryDialog.xml", guiLoadCalls[3].path, "history dialog should load before the main screen")
assertEquals(Constants.HISTORY_DIALOG_NAME, guiLoadCalls[3].name, "history dialog should use the public dialog name")
assertEquals("mod/gui/RuralLedgerJobDetailDialog.xml", guiLoadCalls[4].path, "job detail dialog should load before the main screen")
assertEquals(Constants.JOB_DETAIL_DIALOG_NAME, guiLoadCalls[4].name, "job detail dialog should use the public dialog name")
assertEquals("mod/gui/RuralLedgerNewspaperDialog.xml", guiLoadCalls[5].path, "newspaper dialog should load before the main screen")
assertEquals(Constants.NEWSPAPER_DIALOG_NAME, guiLoadCalls[5].name, "newspaper dialog should use the public dialog name")
assertEquals("mod/gui/RuralLedgerScreen.xml", guiLoadCalls[6].path, "screen XML should load after the dialogs")
assertTrue(PhobosRuralLedger.Gui:loadScreen(), "second GUI load should reuse the cached screen")
assertEquals(1, #profileLoadCalls, "GUI profiles should not load repeatedly")
assertEquals(6, #guiLoadCalls, "dialogs and screen XML should not load repeatedly")
g_gui = nil

local screen = PhobosRuralLedger.RuralLedgerScreen.new()
screen.screenContainer = {absSize = {1300}}
screen.farmersPanel = {absSize = {1300}}
screen.overviewPanel = makeElement()
screen.newspaperPanel = makeElement()
screen.farmersPanel.setVisible = makeElement().setVisible
screen.jobsPanel = makeElement()
screen.debugPanel = makeElement()
screen.buttonsPanel = makeElement()
screen.buttonsPanel.invalidateCount = 0
screen.buttonsPanel.invalidateLayout = function(self)
    self.invalidateCount = self.invalidateCount + 1
end
screen.overviewTab = makeElement()
screen.newspaperTab = makeElement()
screen.farmersTab = makeElement()
screen.jobsTab = makeElement()
screen.debugTab = makeElement()
screen.readNewspaperFooterButton = makeElement()
screen.farmDetailFooterButton = makeElement()
screen.opportunityFooterButton = makeElement()
screen.historyFooterButton = makeElement()
screen.jobDetailFooterButton = makeElement()
screen.startContractFooterButton = makeElement()
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
screen.newspaperTitle = makeElement()
screen.newspaperSubtitle = makeElement()
screen.jobsTitle = makeElement()
screen.jobsSubtitle = makeElement()
screen.jobsByNpcButton = makeElement()
screen.jobsByPlotButton = makeElement()
screen.debugTitle = makeElement()
screen.debugModeText = makeElement()
screen.overviewNoDataNotice = makeElement()
screen.newspaperEmptyText = makeElement()
screen.debugNoDataNotice = makeElement()
screen.overviewList = makeList()
screen.newspaperTable = makeList()
screen.farmTable = makeList()
screen.jobTable = makeList()
screen.debugList = makeList()

function PhobosRuralLedger.getState()
    return stateA
end

stateA.newspaper = archiveState.newspaper
JobRequests.refresh(stateA, {trigger = "screen_smoke"})
screen:onGuiSetupFinished()
assertEquals(nil, PhobosRuralLedger.RuralLedgerScreen.SECTIONS.DETAIL, "farm detail should not be a top-level section")
assertEquals("newspaper", PhobosRuralLedger.RuralLedgerScreen.SECTIONS.NEWSPAPER, "newspaper should be a top-level overview section")
assertTrue(screen.farmTable.dataSource == screen, "farm table should use the screen as data source")
assertTrue(screen.jobTable.dataSource == screen, "job table should use the screen as data source")
assertTrue(screen.newspaperTable.dataSource == screen, "newspaper archive should use the screen as data source")
assertEquals(#farmRowsA, screen:getNumberOfItemsInSection(screen.farmTable, 1), "farm table item count should match cached rows")
assertEquals(#screen.cachedJobRows, screen:getNumberOfItemsInSection(screen.jobTable, 1), "job table item count should match cached rows")
assertEquals(Constants.MAX_NEWSPAPER_EDITIONS, screen:getNumberOfItemsInSection(screen.newspaperTable, 1), "newspaper archive count should match cached rows")

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

local jobCell = makeCell({
    "jobNpc",
    "jobPlot",
    "jobTitle",
    "jobStatus",
    "jobSource",
    "jobRelation",
})
screen:populateCellForItemInSection(screen.jobTable, 1, 1, jobCell)
assertTrue(jobCell.attributes.jobNpc.text ~= "", "job rows should render NPC text")
assertTrue(jobCell.attributes.jobTitle.text ~= "", "job rows should render a job title")

local newspaperCell = makeCell({
    "edition",
    "headline",
    "summary",
})
screen:populateCellForItemInSection(screen.newspaperTable, 1, 1, newspaperCell)
assertTrue(newspaperCell.attributes.edition.text ~= "", "newspaper archive should render an edition label")
assertTrue(newspaperCell.attributes.headline.text ~= "", "newspaper archive should render a headline")

screen.screenContainer.absSize = {900}
screen.farmersPanel.absSize = {900}
screen:adaptLayout()
screen:populateCellForItemInSection(screen.farmTable, 1, 1, farmCell)
assertTrue(not farmCell.attributes.farmType.visible, "compact layout should hide lower-priority type column")
assertTrue(not farmCell.attributes.farmRelation.visible, "compact layout should hide lower-priority relationship column")
assertTrue(farmCell.attributes.farmNameCompact.visible, "compact layout should show compact farm column")

screen.isReloading = false
assertTrue(not screen.readNewspaperFooterButton.visible, "read paper footer action should start hidden without an archive selection")
assertTrue(not screen.farmDetailFooterButton.visible, "farm detail footer action should start hidden without a selected farm")
assertTrue(not screen.opportunityFooterButton.visible, "opportunity footer action should start hidden without a selected farm")
assertTrue(not screen.historyFooterButton.visible, "history footer action should start hidden without a selected farm")
assertTrue(not screen.jobDetailFooterButton.visible, "job detail footer action should start hidden without a selected job")
assertTrue(not screen.startContractFooterButton.visible, "start contract footer action should start hidden without a selected job")
assertTrue(screen.farmTable.onDoubleClickCallback ~= nil, "farm table should expose the SmoothList double-click callback")
assertTrue(screen.jobTable.onDoubleClickCallback ~= nil, "job table should expose the SmoothList double-click callback")
assertEquals(nil, screen.farmTable.onDoubleClick, "farm table should not depend on a speculative double-click callback")
screen:onListSelectionChanged(screen.farmTable, 1, 0)
assertEquals(nil, screen.selectedFarmId, "farm selection should ignore non-row zero indices")
assertTrue(not screen.farmDetailFooterButton.visible, "farm detail footer action should remain hidden after non-row selection")
assertTrue(not screen.opportunityFooterButton.visible, "opportunity footer action should remain hidden after non-row selection")
assertTrue(not screen.historyFooterButton.visible, "history footer action should remain hidden after non-row selection")
screen:onListSelectionChanged(screen.farmTable, 1, 2)
assertEquals(farmRowsA[2].farmId, screen.selectedFarmId, "farm selection should update selected farm")
assertEquals(PhobosRuralLedger.RuralLedgerScreen.SECTIONS.FARMERS, screen.activeSection, "farm selection should keep Farmers as the active top tab")
assertTrue(screen.farmDetailFooterButton.visible, "farm detail footer action should appear after selecting a farm")
assertTrue(not screen.opportunityFooterButton.visible, "opportunity footer action should stay hidden when selected farm has no opportunities")
assertTrue(not screen.historyFooterButton.visible, "history footer action should stay hidden when selected farm has no history")

local shownDialogs = {}
g_gui = {
    showDialog = function(_, name)
        shownDialogs[#shownDialogs + 1] = {
            name = name,
            target = {
                receivedDetail = nil,
                receivedOpportunities = nil,
                receivedHistory = nil,
                receivedJobDetail = nil,
                receivedEdition = nil,
                setFarmDetail = function(self, detail)
                    self.receivedDetail = detail
                end,
                setOpportunities = function(self, model)
                    self.receivedOpportunities = model
                end,
                setHistory = function(self, model)
                    self.receivedHistory = model
                end,
                setJobDetail = function(self, model)
                    self.receivedJobDetail = model
                end,
                setEdition = function(self, model)
                    self.receivedEdition = model
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

stateA.opportunities = {
    Opportunities.normalizeOpportunity({
        farmId = farmRowsA[2].farmId,
        type = "urgent_work",
        causeCode = Constants.PRESSURE_TYPES.NEGATIVE_CASH,
        sourcePeriod = "season_0001",
        expiresPeriod = "season_0002",
        severity = Constants.STRESS_STATES.STRAINED,
    }),
}
stateA.eventHistory = {
    Opportunities.normalizeHistory({
        farmId = farmRowsA[2].farmId,
        periodId = "season_0001",
        type = "generated",
        causeCode = Constants.PRESSURE_TYPES.NEGATIVE_CASH,
        message = "Generated read-only opportunity for selected farm.",
    }),
}
screen:refreshModels()
screen:updateDisplay()
assertTrue(screen.opportunityFooterButton.visible, "opportunity footer action should appear when selected farm has candidates")
assertTrue(screen.historyFooterButton.visible, "history footer action should appear when selected farm has history")
screen:onClickOpportunities()
assertEquals(2, #shownDialogs, "opportunity footer action should open one dialog")
assertEquals(Constants.OPPORTUNITY_DIALOG_NAME, shownDialogs[2].name, "opportunity footer action should use the registered dialog")
assertEquals(farmRowsA[2].farmId, shownDialogs[2].target.receivedOpportunities.farmId, "opportunity dialog should receive the selected farm model")
screen:onClickHistory()
assertEquals(3, #shownDialogs, "history footer action should open one dialog")
assertEquals(Constants.HISTORY_DIALOG_NAME, shownDialogs[3].name, "history footer action should use the registered dialog")
assertEquals(farmRowsA[2].farmId, shownDialogs[3].target.receivedHistory.farmId, "history dialog should receive the selected farm model")
stateA.opportunities = {}
stateA.eventHistory = {}
screen:refreshModels()
screen:updateDisplay()
assertTrue(not screen.opportunityFooterButton.visible, "opportunity footer action should hide again when candidates disappear")
assertTrue(not screen.historyFooterButton.visible, "history footer action should hide again when history disappears")

screen:onClickJobs()
assertEquals(PhobosRuralLedger.RuralLedgerScreen.SECTIONS.JOBS, screen.activeSection, "Jobs tab should become the active top-level section")
assertTrue(not screen.jobDetailFooterButton.visible, "job detail footer action should remain hidden before a job selection")
screen:onListSelectionChanged(screen.jobTable, 1, 1)
assertEquals(screen.cachedJobRows[1].requestId, screen.selectedJobRequestId, "job selection should store the selected request id")
assertEquals(PhobosRuralLedger.RuralLedgerScreen.SECTIONS.JOBS, screen.activeSection, "job selection should keep Jobs as the active top tab")
assertTrue(screen.jobDetailFooterButton.visible, "job detail footer action should appear after selecting a job")
assertTrue(not screen.startContractFooterButton.visible, "start contract action should stay hidden for generated non-launchable requests")
screen:onClickJobDetail()
assertEquals(4, #shownDialogs, "job detail footer action should open one dialog")
assertEquals(Constants.JOB_DETAIL_DIALOG_NAME, shownDialogs[4].name, "job detail footer action should use the registered dialog")
assertEquals(screen.cachedJobRows[1].requestId, shownDialogs[4].target.receivedJobDetail.requestId, "job detail dialog should receive the selected request model")

local selectedJobFarmId = shownDialogs[4].target.receivedJobDetail.farmId
stateA.opportunities = {
    Opportunities.normalizeOpportunity({
        farmId = selectedJobFarmId,
        type = "urgent_work",
        causeCode = Constants.PRESSURE_TYPES.NEGATIVE_CASH,
        sourcePeriod = "season_0001",
        expiresPeriod = "season_0002",
        severity = Constants.STRESS_STATES.STRAINED,
    }),
}
screen:refreshModels()
screen:onClickJobs()
screen:onListSelectionChanged(screen.jobTable, 1, 1)
assertTrue(screen.opportunityFooterButton.visible, "Jobs selection should show Opportunities when its property has candidates")
screen:onClickOpportunities()
assertEquals(5, #shownDialogs, "Jobs Opportunities action should open one dialog")
assertEquals(Constants.OPPORTUNITY_DIALOG_NAME, shownDialogs[5].name, "Jobs Opportunities action should use the registered opportunity dialog")
assertEquals(selectedJobFarmId, shownDialogs[5].target.receivedOpportunities.farmId, "Jobs Opportunities action should resolve the selected job property")
stateA.opportunities = {}
screen:refreshModels()
screen:onClickJobs()

screen:onClickJobsByPlot()
assertEquals(PhobosRuralLedger.RuralLedgerScreen.JOB_MODES.PLOT, screen.activeJobMode, "Jobs By Plot toggle should switch the row model mode")
assertTrue(screen.jobsByPlotButton.selected, "Jobs By Plot toggle should become selected")
screen:onClickJobsByNpc()
assertEquals(PhobosRuralLedger.RuralLedgerScreen.JOB_MODES.NPC, screen.activeJobMode, "Jobs By NPC toggle should switch the row model mode")
assertTrue(screen.jobsByNpcButton.selected, "Jobs By NPC toggle should become selected")

screen:onListDoubleClick(screen.jobTable, 1, 2)
assertEquals(6, #shownDialogs, "job table double-click should open a detail dialog")
assertEquals(screen.cachedJobRows[2].requestId, screen.selectedJobRequestId, "job table double-click should select the clicked job")
assertEquals(screen.cachedJobRows[2].requestId, shownDialogs[6].target.receivedJobDetail.requestId, "job double-click dialog should receive the clicked job detail")

local dialogsBeforeFarmDoubleClick = #shownDialogs

local function farmTableElement(index)
    return {
        sectionIndex = 1,
        indexInSection = index,
    }
end

screen:onListDoubleClick(screen.farmTable, 1, 0)
assertEquals(dialogsBeforeFarmDoubleClick, #shownDialogs, "farm table double-click should ignore non-row zero indices")
assertEquals(farmRowsA[2].farmId, screen.selectedFarmId, "ignored double-click should keep the previous valid selection")
screen:onListDoubleClick(screen.farmTable, 1, 3)
assertEquals(dialogsBeforeFarmDoubleClick + 1, #shownDialogs, "farm table double-click should open one dialog per activation")
assertEquals(farmRowsA[3].farmId, screen.selectedFarmId, "farm table double-click should select the clicked farm")
assertEquals(farmRowsA[3].farmId, shownDialogs[dialogsBeforeFarmDoubleClick + 1].target.receivedDetail.farmId, "double-click dialog should receive the clicked farm detail model")

screen.selectedFarmId = farmRowsA[2].farmId
screen.farmTable.onDoubleClickCallback(screen.farmTable, 1, 4, farmTableElement(4), true)
assertEquals(dialogsBeforeFarmDoubleClick + 2, #shownDialogs, "SmoothList double-click callback should open the detail dialog")
assertEquals(farmRowsA[4].farmId, screen.selectedFarmId, "SmoothList double-click callback should select the clicked row")
assertEquals(farmRowsA[4].farmId, shownDialogs[dialogsBeforeFarmDoubleClick + 2].target.receivedDetail.farmId, "SmoothList callback dialog should receive the clicked farm detail")

screen.selectedFarmId = farmRowsA[2].farmId
screen.farmTable.onDoubleClickCallback({callbackTarget = true}, screen.farmTable, 1, 5, farmTableElement(5), true)
assertEquals(dialogsBeforeFarmDoubleClick + 3, #shownDialogs, "target-prefixed SmoothList callback should open the detail dialog")
assertEquals(farmRowsA[5].farmId, screen.selectedFarmId, "target-prefixed SmoothList callback should select the clicked row")
assertEquals(farmRowsA[5].farmId, shownDialogs[dialogsBeforeFarmDoubleClick + 3].target.receivedDetail.farmId, "target-prefixed callback dialog should receive the clicked farm detail")

screen.selectedFarmId = farmRowsA[2].farmId
screen.farmTable.onDoubleClickCallback({callbackTarget = true}, 1, 6, farmTableElement(6), true)
assertEquals(dialogsBeforeFarmDoubleClick + 4, #shownDialogs, "element-backed SmoothList callback should open the detail dialog")
assertEquals(farmRowsA[6].farmId, screen.selectedFarmId, "element-backed SmoothList callback should select the clicked row")
assertEquals(farmRowsA[6].farmId, shownDialogs[dialogsBeforeFarmDoubleClick + 4].target.receivedDetail.farmId, "element-backed callback dialog should receive the clicked farm detail")

screen.farmTable.onDoubleClickCallback(screen.farmTable, 1, 0, {sectionIndex = 1, indexInSection = 0, isHeader = true}, true)
assertEquals(dialogsBeforeFarmDoubleClick + 4, #shownDialogs, "SmoothList double-click should ignore header cells")
assertEquals(farmRowsA[6].farmId, screen.selectedFarmId, "ignored header double-click should keep the previous valid selection")

local dialogsBeforeNewspaper = #shownDialogs
screen:onClickNewspaper()
assertEquals(PhobosRuralLedger.RuralLedgerScreen.SECTIONS.NEWSPAPER, screen.activeSection, "Newspaper tab should become the active top-level section")
assertTrue(not screen.readNewspaperFooterButton.visible, "read paper footer action should stay hidden without an archive selection")
screen:onListSelectionChanged(screen.newspaperTable, 1, 1)
assertEquals(screen.cachedNewspaperRows[1].editionId, screen.selectedNewspaperEditionId, "newspaper selection should store the selected edition id")
assertTrue(screen.readNewspaperFooterButton.visible, "read paper footer action should appear after selecting an edition")
screen:onClickReadNewspaper()
assertEquals(dialogsBeforeNewspaper + 1, #shownDialogs, "read paper footer action should open one newspaper dialog")
assertEquals(Constants.NEWSPAPER_DIALOG_NAME, shownDialogs[dialogsBeforeNewspaper + 1].name, "read paper should use the newspaper dialog")
assertEquals(screen.cachedNewspaperRows[1].editionId, shownDialogs[dialogsBeforeNewspaper + 1].target.receivedEdition.editionId, "newspaper dialog should receive the selected edition")
screen:onListDoubleClick(screen.newspaperTable, 1, 2)
assertEquals(dialogsBeforeNewspaper + 2, #shownDialogs, "newspaper double-click should open one newspaper dialog")
assertEquals(screen.cachedNewspaperRows[2].editionId, shownDialogs[dialogsBeforeNewspaper + 2].target.receivedEdition.editionId, "newspaper double-click should open the clicked edition")
screen:setSection(PhobosRuralLedger.RuralLedgerScreen.SECTIONS.FARMERS)
g_gui = nil

screen.selectedFarmId = farmRowsA[2].farmId
screen:refreshModels()
screen:updateDisplay()
assertEquals(farmRowsA[2].farmId, screen.selectedFarmId, "refresh should preserve a still-valid farm selection")
assertTrue(screen.farmDetailFooterButton.visible, "refresh should keep the detail footer action visible for a valid selection")
assertTrue(not screen.opportunityFooterButton.visible, "refresh should keep the opportunity footer hidden without candidates")
assertTrue(not screen.historyFooterButton.visible, "refresh should keep the history footer hidden without history")
screen.selectedFarmId = "missing_farm"
screen:refreshModels()
screen:updateDisplay()
assertEquals(nil, screen.selectedFarmId, "refresh should clear a missing farm selection")
assertTrue(not screen.farmDetailFooterButton.visible, "refresh should hide the detail footer action when selection disappears")
assertTrue(not screen.opportunityFooterButton.visible, "refresh should hide the opportunity footer action when selection disappears")
assertTrue(not screen.historyFooterButton.visible, "refresh should hide the history footer action when selection disappears")

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

local opportunityDialog = PhobosRuralLedger.OpportunityDialog.new()
opportunityDialog.opportunityTitle = makeElement()
opportunityDialog.opportunitySubtitle = makeElement()
opportunityDialog.opportunityList = makeList()
opportunityDialog:onGuiSetupFinished()
opportunityDialog:setOpportunities(UiModels.buildOpportunities(opportunityState, "opp_farm_01"))
assertTrue(opportunityDialog.opportunityTitle.text ~= "", "opportunity dialog should render a title")
assertTrue(#opportunityDialog.rows > 0, "opportunity dialog should expose read-only rows")
assertEquals(#opportunityDialog.rows, opportunityDialog:getNumberOfItemsInSection(opportunityDialog.opportunityList, 1), "opportunity dialog list count should match rows")
opportunityDialog:onClickBack()
assertTrue(opportunityDialog.closed, "opportunity dialog back action should close the dialog")

local historyDialog = PhobosRuralLedger.HistoryDialog.new()
historyDialog.historyTitle = makeElement()
historyDialog.historySubtitle = makeElement()
historyDialog.historyList = makeList()
historyDialog:onGuiSetupFinished()
historyDialog:setHistory(UiModels.buildHistory(opportunityState, "opp_farm_01"))
assertTrue(historyDialog.historyTitle.text ~= "", "history dialog should render a title")
assertTrue(#historyDialog.rows > 0, "history dialog should expose read-only rows")
assertEquals(#historyDialog.rows, historyDialog:getNumberOfItemsInSection(historyDialog.historyList, 1), "history dialog list count should match rows")
historyDialog:onClickBack()
assertTrue(historyDialog.closed, "history dialog back action should close the dialog")

local jobDetailDialog = PhobosRuralLedger.JobDetailDialog.new()
jobDetailDialog.jobDetailTitle = makeElement()
jobDetailDialog.jobDetailSubtitle = makeElement()
jobDetailDialog.jobDetailList = makeList()
jobDetailDialog:onGuiSetupFinished()
jobDetailDialog:setJobDetail(UiModels.buildJobDetail(stateA, screen.cachedJobRows[1].requestId))
assertTrue(jobDetailDialog.jobDetailTitle.text ~= "", "job detail dialog should render a title")
assertTrue(#jobDetailDialog.rows > 0, "job detail dialog should expose read-only rows")
assertEquals(#jobDetailDialog.rows, jobDetailDialog:getNumberOfItemsInSection(jobDetailDialog.jobDetailList, 1), "job detail dialog list count should match rows")
jobDetailDialog:onClickBack()
assertTrue(jobDetailDialog.closed, "job detail dialog back action should close the dialog")

local newspaperDialog = PhobosRuralLedger.NewspaperDialog.new()
newspaperDialog.newspaperTitle = makeElement()
newspaperDialog.newspaperDateline = makeElement()
newspaperDialog.newspaperMasthead = makeElement()
newspaperDialog.newspaperHeadline = makeElement()
newspaperDialog.newspaperSummary = makeElement()
newspaperDialog.newspaperList = makeList()
newspaperDialog:onGuiSetupFinished()
newspaperDialog:setEdition(UiModels.buildNewspaperEdition(stateA, screen.cachedNewspaperRows[1].editionId))
assertTrue(newspaperDialog.newspaperMasthead.text ~= "", "newspaper dialog should render a masthead")
assertTrue(newspaperDialog.newspaperHeadline.text ~= "", "newspaper dialog should render a headline")
assertTrue(#newspaperDialog.rows > 0, "newspaper dialog should expose article rows")
assertEquals(#newspaperDialog.rows, newspaperDialog:getNumberOfItemsInSection(newspaperDialog.newspaperList, 1), "newspaper dialog list count should match rows")
newspaperDialog:onClickBack()
assertTrue(newspaperDialog.closed, "newspaper dialog back action should close the dialog")

capturedLogs = {}
source("mod/src/PhobosRuralLedger.lua")

assertEquals(
    Constants.DEFAULT_LOG_REPORT_FARM_LINES + 3,
    #capturedLogs,
    "bootstrap logging should include discovery, jobs, one header, and the default farm line count"
)
assertEquals("PhobosRuralLedger", capturedLogs[1].source, "bootstrap log lines should use the Rural Ledger source")
assertTrue(
    string.find(capturedLogs[1].text, "Map discovery") ~= nil,
    "bootstrap log should include the discovery summary"
)
assertTrue(
    string.find(capturedLogs[3].text, "Local economy report") ~= nil,
    "bootstrap log should include the report header"
)
assertEquals("none", PhobosRuralLedger.getState().mapDiscovery.source, "bootstrap should not permanently run real discovery")
assertTrue(
    not PhobosRuralLedger.getState().mapDiscovery.mapReadyAttempted,
    "bootstrap state should remain not map-ready until a later lifecycle pass"
)

local previousSaveOpportunityState = PhobosRuralLedger.saveOpportunityState
local stateBeforeAutoPaper = PhobosRuralLedger.state
local autoPaperDialogs = {}
local autoPaperSaves = 0
PhobosRuralLedger.saveOpportunityState = function()
    autoPaperSaves = autoPaperSaves + 1
    return true
end
PhobosRuralLedger.state = {
    periodId = opportunityState.periodId,
    regionalPreset = Constants.DEFAULT_REGIONAL_PRESET,
    mapDiscovery = opportunityState.mapDiscovery,
    profiles = opportunityState.profiles,
    ledgerSnapshots = opportunityState.ledgerSnapshots,
    opportunities = opportunityState.opportunities,
    eventHistory = opportunityState.eventHistory,
    jobRequests = {},
    jobHistory = {},
    newspaper = Newspaper.createEmptyState(),
}
g_currentMission = {
    environment = {
        currentDay = 21,
        dayTime = 21600000,
    },
    missionInfo = {
        savegameDirectory = "paperSave",
    },
}
g_gui = {
    loadProfiles = function() end,
    loadGui = function()
        return true
    end,
    showDialog = function(_, name)
        autoPaperDialogs[#autoPaperDialogs + 1] = {
            name = name,
            target = {
                edition = nil,
                setEdition = function(self, model)
                    self.edition = model
                end,
            },
        }
        return autoPaperDialogs[#autoPaperDialogs]
    end,
}
PhobosRuralLedger.Gui.modDirectory = "mod/"
PhobosRuralLedger.Gui.screenLoaded = false
PhobosRuralLedger.Gui.profilesLoaded = false
PhobosRuralLedger.Gui.farmDetailDialogLoaded = false
PhobosRuralLedger.Gui.opportunityDialogLoaded = false
PhobosRuralLedger.Gui.historyDialogLoaded = false
PhobosRuralLedger.Gui.jobDetailDialogLoaded = false
PhobosRuralLedger.Gui.newspaperDialogLoaded = false
PhobosRuralLedger.Gui.newspaperUpdateMs = 0
PhobosRuralLedger.Gui.missionStarted = false
PhobosRuralLedger.state.newspaper = Newspaper.createEmptyState({
    lastCheckedDay = 21,
    lastCheckedMinute = Constants.NEWSPAPER_DELIVERY_MINUTE - 1,
})
PhobosRuralLedger.Gui:checkNewspaperDelivery("loadMap", false)
assertEquals(0, #autoPaperDialogs, "loadMap newspaper check should not auto-open a dialog")
assertEquals(0, #PhobosRuralLedger.state.newspaper.editions, "loadMap newspaper check should not deliver an edition")
PhobosRuralLedger.state.newspaper = Newspaper.createEmptyState()
PhobosRuralLedger.Gui:update(Constants.NEWSPAPER_UPDATE_INTERVAL_MS)
assertEquals(0, #autoPaperDialogs, "GUI update should not auto-open a newspaper before mission start")
PhobosRuralLedger.Gui.missionStarted = true
PhobosRuralLedger.Gui:update(Constants.NEWSPAPER_UPDATE_INTERVAL_MS)
assertEquals(0, #autoPaperDialogs, "first mission-ready newspaper update should only establish a clock baseline")
g_currentMission.environment.dayTime = 21600000 + 60000
PhobosRuralLedger.state.newspaper.lastCheckedDay = 21
PhobosRuralLedger.state.newspaper.lastCheckedMinute = Constants.NEWSPAPER_DELIVERY_MINUTE - 1
PhobosRuralLedger.Gui:update(Constants.NEWSPAPER_UPDATE_INTERVAL_MS)
assertEquals(1, #autoPaperDialogs, "GUI update should auto-open one due newspaper dialog")
assertEquals(Constants.NEWSPAPER_DIALOG_NAME, autoPaperDialogs[1].name, "auto-open should use the newspaper dialog")
assertEquals("daily_0021", autoPaperDialogs[1].target.edition.editionId, "auto-open should pass the delivered newspaper edition")
assertEquals(nil, PhobosRuralLedger.state.newspaper.pendingEditionId, "auto-open should clear the pending newspaper once shown")
assertTrue(autoPaperSaves >= 1, "auto-open delivery should persist newspaper state")
PhobosRuralLedger.saveOpportunityState = previousSaveOpportunityState
PhobosRuralLedger.state = stateBeforeAutoPaper
g_gui = nil
g_currentMission = nil

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

local previousRuntimeState = PhobosRuralLedger.state
local previousRuntimeSave = PhobosRuralLedger.saveOpportunityState
local periodSaveCalls = 0
PhobosRuralLedger.state = {
    periodId = "season_0001",
    mapDiscovery = {source = "map"},
    profiles = opportunityState.profiles,
    ledgerSnapshots = opportunityState.ledgerSnapshots,
    opportunities = {},
    eventHistory = {},
    cooldowns = {},
}
Opportunities.reconcile(PhobosRuralLedger.state)
PhobosRuralLedger.saveOpportunityState = function()
    periodSaveCalls = periodSaveCalls + 1
    return true
end
local runtimePeriodSummary = PhobosRuralLedger.advanceLedgerPeriod()
assertEquals("season_0002", runtimePeriodSummary.currentPeriod, "runtime period helper should advance the ledger period")
assertTrue(runtimePeriodSummary.expiredOpportunities > 0, "runtime period helper should expire current read-only opportunities")
assertEquals(1, periodSaveCalls, "runtime period helper should request one save after advancing")
PhobosRuralLedger.saveOpportunityState = previousRuntimeSave
PhobosRuralLedger.state = previousRuntimeState

capturedLogs = {}
local logOptions = {maxLines = 2}
local loggedReport = PhobosRuralLedger.logEconomyReport(logOptions)
assertEquals(3, #loggedReport, "explicit report logging should respect maxLines")
assertEquals(3, #capturedLogs, "explicit report logging should write the bounded number of lines")
assertEquals(2, logOptions.maxLines, "report logging should not mutate caller options")
assertEquals("PhobosRuralLedger", capturedLogs[1].source, "explicit report logging should use the local Rural Ledger logger")

capturedLogs = {}
installFakeMapRuntime()
local refreshedState = PhobosRuralLedger.refreshMapBackedState({trigger = "manualRefresh", mapReadyAttempted = true})
assertEquals("map", refreshedState.mapDiscovery.source, "manual refresh should rebuild map-backed state")
assertEquals("manualRefresh", refreshedState.mapDiscovery.trigger, "manual refresh should record its trigger")
assertEquals(2, #refreshedState.profiles, "manual refresh should create map-sourced profiles")
local sawManualRefreshDiscoveryLog = false
for _, logLine in ipairs(capturedLogs) do
    if string.find(logLine.text, "Map discovery", 1, true) ~= nil then
        sawManualRefreshDiscoveryLog = true
    end
end
assertTrue(sawManualRefreshDiscoveryLog, "manual refresh should log one discovery summary")
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
