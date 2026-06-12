local repoRoot = arg[1] or "."

local function source(path)
    dofile(repoRoot .. "/" .. path)
end

source("mod/src/Constants.lua")
source("mod/src/Profiles.lua")
source("mod/src/Ledgers.lua")
source("mod/src/Simulation.lua")
source("mod/src/UiModels.lua")
source("mod/src/Reports.lua")
source("mod/src/Persistence.lua")

local Constants = PhobosRuralLedger.Constants
local Ledgers = PhobosRuralLedger.Ledgers
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
assertEquals(6, #overviewA.cards, "overview should expose six V1 cards")
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

source("mod/src/PhobosRuralLedger.lua")

assertEquals(
    Constants.DEFAULT_LOG_REPORT_FARM_LINES + 1,
    #capturedLogs,
    "bootstrap report logging should include one header plus the default farm line count"
)
assertEquals("PhobosRuralLedger", capturedLogs[1].source, "bootstrap log lines should use the Rural Ledger source")
assertTrue(
    string.find(capturedLogs[1].text, "Local economy report") ~= nil,
    "bootstrap log should include the report header"
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
