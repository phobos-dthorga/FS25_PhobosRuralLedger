PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Ledgers = PhobosRuralLedger.Ledgers or {}

local Ledgers = PhobosRuralLedger.Ledgers
local Constants = PhobosRuralLedger.Constants
local Tuning = Constants.LEDGER_TUNING

local ENTERPRISE_FACTORS = {
    grain = {revenue = 1.00, directCost = 1.00},
    oilseed = {revenue = 1.14, directCost = 1.10},
    livestock = {revenue = 1.08, directCost = 1.18},
    dairy = {revenue = 1.28, directCost = 1.30},
    forage = {revenue = 0.82, directCost = 0.72},
    contracts = {revenue = 0.92, directCost = 0.62},
    land_rent = {revenue = 0.68, directCost = 0.28},
    conservation = {revenue = 0.74, directCost = 0.54},
}

local DEBT_FACTORS = {
    low_debt = {debt = 0.45, interest = 0.80},
    cautious = {debt = 0.75, interest = 0.90},
    moderate = {debt = 1.00, interest = 1.00},
    equipment_debt = {debt = 1.30, interest = 1.12},
    high_operating_debt = {debt = 1.55, interest = 1.25},
}

local RISK_FACTORS = {
    balanced = {yield = 1.00, cost = 1.00, buffer = 1.00},
    practical = {yield = 1.02, cost = 0.95, buffer = 0.92},
    steady = {yield = 1.03, cost = 1.02, buffer = 1.05},
    market_exposed = {yield = 1.10, cost = 1.08, buffer = 0.74},
    vulnerable = {yield = 0.88, cost = 1.12, buffer = 0.55},
    expansionist = {yield = 1.08, cost = 1.14, buffer = 0.70},
    feed_sensitive = {yield = 1.00, cost = 1.13, buffer = 0.76},
    soil_first = {yield = 0.95, cost = 0.90, buffer = 1.15},
}

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

local function countFields(profile)
    local owned = #(profile.ownedFields or {})
    local leased = #(profile.leasedFields or {})

    return math.max(1, owned + (leased * 0.5))
end

local function averageEnterpriseFactors(enterpriseMix)
    local revenue = 0
    local directCost = 0
    local count = 0

    for _, enterprise in ipairs(enterpriseMix or {}) do
        local factors = ENTERPRISE_FACTORS[enterprise] or {revenue = 1.00, directCost = 1.00}
        revenue = revenue + factors.revenue
        directCost = directCost + factors.directCost
        count = count + 1
    end

    if count == 0 then
        return 1.00, 1.00
    end

    return revenue / count, directCost / count
end

local function addPressure(pressures, pressureType, score)
    if score <= 0 then
        return
    end

    pressures[#pressures + 1] = {
        pressureType = pressureType,
        score = score,
    }
end

local function primaryPressure(pressures)
    local selected = {
        pressureType = Constants.PRESSURE_TYPES.NONE,
        score = 0,
    }

    for _, pressure in ipairs(pressures) do
        if pressure.score > selected.score then
            selected = pressure
        end
    end

    return selected.pressureType
end

local function stressState(score)
    if score >= Constants.STRESS_THRESHOLDS.INSOLVENT then
        return Constants.STRESS_STATES.INSOLVENT
    end

    if score >= Constants.STRESS_THRESHOLDS.DISTRESSED then
        return Constants.STRESS_STATES.DISTRESSED
    end

    if score >= Constants.STRESS_THRESHOLDS.STRAINED then
        return Constants.STRESS_STATES.STRAINED
    end

    if score >= Constants.STRESS_THRESHOLDS.WATCH then
        return Constants.STRESS_STATES.WATCH
    end

    return Constants.STRESS_STATES.STABLE
end

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
        primaryPressure = Constants.PRESSURE_TYPES.NONE,
        lastUpdatedPeriod = periodId or Constants.DEFAULT_PERIOD_ID,
    }
end

function Ledgers.createInitialSnapshots(profiles, periodId)
    local snapshots = {}

    for index, profile in ipairs(profiles or {}) do
        snapshots[index] = Ledgers.calculateSnapshot(profile, periodId)
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

function Ledgers.calculateSnapshot(profile, periodId, options)
    options = options or {}
    profile = profile or {}

    local snapshot = Ledgers.createEmptySnapshot(profile, periodId)
    local fieldCount = countFields(profile)
    local enterpriseRevenueFactor, enterpriseCostFactor = averageEnterpriseFactors(profile.enterpriseMix)
    local debtFactors = DEBT_FACTORS[profile.debtAttitude] or DEBT_FACTORS.moderate
    local riskFactors = RISK_FACTORS[profile.riskAttitude] or RISK_FACTORS.balanced
    local storageRating = clamp(profile.storageRating or 3, 1, 5)
    local machineryRating = clamp(profile.machineryRating or 3, 1, 5)
    local relationshipScore = clamp(profile.relationshipScore or 3, 1, 5)
    local regionalCostIndex = options.regionalCostIndex or 1.00
    local regionalRevenueIndex = options.regionalRevenueIndex or 1.00
    local storageEffect = (storageRating - 3) * 0.04
    local machineryEfficiency = (machineryRating - 3) * 0.025
    local revenueMultiplier = math.max(0.45, riskFactors.yield + storageEffect + machineryEfficiency)
    local costMultiplier = math.max(0.45, riskFactors.cost * regionalCostIndex)

    snapshot.grossRevenue = round(
        fieldCount
            * Tuning.BASE_REVENUE_PER_FIELD
            * enterpriseRevenueFactor
            * revenueMultiplier
            * regionalRevenueIndex
    )
    snapshot.directCosts = round(
        fieldCount
            * Tuning.BASE_DIRECT_COST_PER_FIELD
            * enterpriseCostFactor
            * costMultiplier
    )
    snapshot.fixedCosts = round(
        Tuning.BASE_FIXED_COST
            + (fieldCount * Tuning.FIXED_COST_PER_FIELD)
            + (machineryRating * Tuning.MACHINERY_COST_STEP)
    )
    snapshot.totalDebt = round(
        fieldCount
            * Tuning.BASE_DEBT_PER_FIELD
            * debtFactors.debt
    )
    snapshot.interestDue = round(
        snapshot.totalDebt
            * Tuning.INTEREST_RATE
            * debtFactors.interest
    )
    snapshot.riskBuffer = round(math.max(
        0,
        (fieldCount * Tuning.BASE_RISK_BUFFER_PER_FIELD * riskFactors.buffer)
            + (storageRating * 4200)
            + (relationshipScore * 1500)
            - (snapshot.totalDebt * 0.025)
    ))
    snapshot.seasonProfit = snapshot.grossRevenue - snapshot.directCosts - snapshot.fixedCosts - snapshot.interestDue
    snapshot.operatingCash = round(snapshot.seasonProfit + snapshot.riskBuffer - (snapshot.totalDebt * 0.02))

    local revenueBase = math.max(1, snapshot.grossRevenue)
    local pressures = {}

    if snapshot.operatingCash < 0 then
        addPressure(
            pressures,
            Constants.PRESSURE_TYPES.NEGATIVE_CASH,
            clamp(18 + ((math.abs(snapshot.operatingCash) / revenueBase) * 70), 0, 34)
        )
    end

    if snapshot.seasonProfit < 0 then
        addPressure(
            pressures,
            Constants.PRESSURE_TYPES.WEAK_MARGIN,
            clamp(14 + ((math.abs(snapshot.seasonProfit) / revenueBase) * 60), 0, 28)
        )
    end

    addPressure(
        pressures,
        Constants.PRESSURE_TYPES.DEBT_SERVICE,
        clamp((snapshot.interestDue / revenueBase) * 130, 0, 28)
    )
    addPressure(
        pressures,
        Constants.PRESSURE_TYPES.STORAGE_SHORTAGE,
        (5 - storageRating) * 4
    )
    addPressure(
        pressures,
        Constants.PRESSURE_TYPES.MACHINERY_COST,
        (5 - machineryRating) * 3
    )

    local enterpriseCount = #(profile.enterpriseMix or {})
    if enterpriseCount <= 1 then
        addPressure(pressures, Constants.PRESSURE_TYPES.LOW_DIVERSITY, 10)
    elseif enterpriseCount == 2 then
        addPressure(pressures, Constants.PRESSURE_TYPES.LOW_DIVERSITY, 5)
    end

    local totalPressure = 0
    for _, pressure in ipairs(pressures) do
        totalPressure = totalPressure + pressure.score
    end

    local bufferRelief = clamp((snapshot.riskBuffer / revenueBase) * 28, 0, 18)
    snapshot.stressScore = round(clamp(totalPressure - bufferRelief, 0, 100))
    snapshot.stressState = stressState(snapshot.stressScore)
    if snapshot.stressState == Constants.STRESS_STATES.STABLE then
        snapshot.primaryPressure = Constants.PRESSURE_TYPES.NONE
    else
        snapshot.primaryPressure = primaryPressure(pressures)
    end
    snapshot.lastUpdatedPeriod = snapshot.periodId

    return snapshot
end

function Ledgers.calculateSnapshots(profiles, periodId, options)
    local snapshots = {}

    for index, profile in ipairs(profiles or {}) do
        snapshots[index] = Ledgers.calculateSnapshot(profile, periodId, options)
    end

    return snapshots
end
