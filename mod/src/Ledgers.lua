PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Ledgers = PhobosRuralLedger.Ledgers or {}

local Ledgers = PhobosRuralLedger.Ledgers
local Constants = PhobosRuralLedger.Constants

function Ledgers.createEmptySnapshot(profile, periodId)
    local farmId = "unknown"

    if profile ~= nil and profile.farmId ~= nil then
        farmId = profile.farmId
    end

    return {
        farmId = farmId,
        periodId = periodId or Constants.DEFAULT_PERIOD_ID,
        operatingCash = 0,
        totalDebt = 0,
        interestDue = 0,
        grossRevenue = 0,
        directCosts = 0,
        fixedCosts = 0,
        riskBuffer = 0,
        seasonProfit = 0,
        stressScore = 0,
        stressState = Constants.STRESS_STATES.STABLE,
        primaryPressure = "none",
        lastUpdatedPeriod = periodId or Constants.DEFAULT_PERIOD_ID,
    }
end

function Ledgers.createInitialSnapshots(profiles, periodId)
    local snapshots = {}

    for index, profile in ipairs(profiles or {}) do
        snapshots[index] = Ledgers.createEmptySnapshot(profile, periodId)
    end

    return snapshots
end

function Ledgers.indexSnapshotsByFarmId(snapshots)
    local result = {}

    for _, snapshot in ipairs(snapshots or {}) do
        result[snapshot.farmId] = snapshot
    end

    return result
end

function Ledgers.normalizeSnapshot(snapshot, profile, periodId)
    local normalized = Ledgers.createEmptySnapshot(profile, periodId)

    for key, value in pairs(snapshot or {}) do
        normalized[key] = value
    end

    if normalized.periodId == nil then
        normalized.periodId = periodId or Constants.DEFAULT_PERIOD_ID
    end

    if normalized.lastUpdatedPeriod == nil then
        normalized.lastUpdatedPeriod = normalized.periodId
    end

    if normalized.stressState == nil then
        normalized.stressState = Constants.STRESS_STATES.STABLE
    end

    return normalized
end
