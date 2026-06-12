PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.UiModels = PhobosRuralLedger.UiModels or {}

local UiModels = PhobosRuralLedger.UiModels
local Constants = PhobosRuralLedger.Constants
local Ledgers = PhobosRuralLedger.Ledgers

local PRESSURE_LABELS = {
    none = "No dominant pressure",
    negative_cash = "Cash is tight",
    weak_margin = "Season margin is weak",
    debt_service = "Debt service is heavy",
    storage_shortage = "Storage limits selling options",
    machinery_cost = "Machinery costs are high",
    low_diversity = "Income is not diversified",
}

local STRESS_LABELS = {
    stable = "Stable",
    watch = "Watch",
    strained = "Strained",
    distressed = "Distressed",
    insolvent = "Insolvent",
}

local STRESS_RANK = {
    stable = 1,
    watch = 2,
    strained = 3,
    distressed = 4,
    insolvent = 5,
}

local RELATIONSHIP_LABELS = {
    [1] = "Unknown",
    [2] = "Distant",
    [3] = "Neutral",
    [4] = "Helpful",
    [5] = "Trusted",
}

local function round(value)
    value = tonumber(value) or 0

    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

local function money(value)
    value = round(value)

    if value < 0 then
        return string.format("-$%d", math.abs(value))
    end

    return string.format("$%d", value)
end

local function percentage(part, whole)
    if whole == nil or whole == 0 then
        return 0
    end

    return (part or 0) / whole
end

local function pressureLabel(pressureType)
    return PRESSURE_LABELS[pressureType or Constants.PRESSURE_TYPES.NONE] or "Mixed pressure"
end

local function stressLabel(stressState)
    return STRESS_LABELS[stressState or Constants.STRESS_STATES.STABLE] or "Unknown"
end

local function stressRank(stressState)
    return STRESS_RANK[stressState or Constants.STRESS_STATES.STABLE] or 0
end

local function relationshipBand(score)
    score = math.max(1, math.min(5, round(score or 3)))
    return RELATIONSHIP_LABELS[score] or "Neutral"
end

local function countFields(profile)
    return #(profile.ownedFields or {}) + #(profile.leasedFields or {})
end

local function profileLabel(profile)
    return profile.label or profile.profileType or "Unknown Profile"
end

local function cashBand(snapshot)
    local ratio = percentage(snapshot.operatingCash, math.max(1, snapshot.grossRevenue or 1))

    if snapshot.operatingCash == nil then
        return "Unknown"
    elseif snapshot.operatingCash < 0 then
        return "Negative"
    elseif ratio < 0.08 then
        return "Tight"
    elseif ratio < 0.18 then
        return "Adequate"
    end

    return "Strong"
end

local function debtBand(snapshot)
    local ratio = percentage(snapshot.totalDebt, math.max(1, snapshot.grossRevenue or 1))

    if snapshot.totalDebt == nil then
        return "Unknown"
    elseif ratio > 2.6 then
        return "Very heavy"
    elseif ratio > 1.8 then
        return "Heavy"
    elseif ratio > 0.9 then
        return "Moderate"
    end

    return "Light"
end

local function marginBand(snapshot)
    local ratio = percentage(snapshot.seasonProfit, math.max(1, snapshot.grossRevenue or 1))

    if snapshot.seasonProfit == nil then
        return "Unknown"
    elseif ratio < -0.08 then
        return "Losing money"
    elseif ratio < 0.04 then
        return "Thin"
    elseif ratio < 0.16 then
        return "Workable"
    end

    return "Healthy"
end

local function riskBufferBand(snapshot)
    local ratio = percentage(snapshot.riskBuffer, math.max(1, snapshot.grossRevenue or 1))

    if snapshot.riskBuffer == nil then
        return "Unknown"
    elseif ratio < 0.08 then
        return "Low"
    elseif ratio < 0.18 then
        return "Moderate"
    end

    return "Good"
end

local function storageBand(profile)
    local rating = profile.storageRating or 3

    if rating <= 1 then
        return "Severe limits"
    elseif rating <= 2 then
        return "Limited"
    elseif rating == 3 then
        return "Adequate"
    end

    return "Flexible"
end

local function machineryBand(profile)
    local rating = profile.machineryRating or 3

    if rating <= 1 then
        return "Fragile"
    elseif rating <= 2 then
        return "Stretched"
    elseif rating == 3 then
        return "Adequate"
    end

    return "Strong"
end

local function stateParts(state)
    local profiles = (state or {}).profiles or {}
    local snapshots = (state or {}).ledgerSnapshots or {}
    return profiles, snapshots, Ledgers.indexSnapshotsByFarmId(snapshots)
end

local function dominantPressure(snapshots)
    local counts = {}
    local bestType = Constants.PRESSURE_TYPES.NONE
    local bestCount = 0

    for _, snapshot in ipairs(snapshots or {}) do
        local pressureType = snapshot.primaryPressure or Constants.PRESSURE_TYPES.NONE
        if pressureType ~= Constants.PRESSURE_TYPES.NONE then
            counts[pressureType] = (counts[pressureType] or 0) + 1
            if counts[pressureType] > bestCount then
                bestType = pressureType
                bestCount = counts[pressureType]
            end
        end
    end

    return pressureLabel(bestType), bestCount
end

local function localMood(stressedCount, strainedCount, totalFarms)
    if totalFarms == 0 then
        return "No tracked farms"
    end

    local strainedRatio = strainedCount / totalFarms
    local stressedRatio = stressedCount / totalFarms

    if strainedRatio >= 0.35 then
        return "Under pressure"
    elseif stressedRatio >= 0.5 then
        return "Cautious"
    elseif stressedCount > 0 then
        return "Mixed but watchful"
    end

    return "Steady"
end

function UiModels.buildFarmList(state, options)
    options = options or {}

    local profiles, _, snapshotsByFarmId = stateParts(state)
    local rows = {}

    for _, profile in ipairs(profiles) do
        local snapshot = snapshotsByFarmId[profile.farmId] or {}
        local row = {
            farmId = profile.farmId,
            displayName = profile.displayName or profile.farmId or "Unknown Farm",
            profileLabel = profileLabel(profile),
            fields = countFields(profile),
            stressState = snapshot.stressState or Constants.STRESS_STATES.STABLE,
            stressLabel = stressLabel(snapshot.stressState),
            stressRank = stressRank(snapshot.stressState),
            primaryPressure = snapshot.primaryPressure or Constants.PRESSURE_TYPES.NONE,
            primaryPressureLabel = pressureLabel(snapshot.primaryPressure),
            cashBand = cashBand(snapshot),
            debtBand = debtBand(snapshot),
            marginBand = marginBand(snapshot),
            riskBufferBand = riskBufferBand(snapshot),
            relationshipBand = relationshipBand(profile.relationshipScore),
            activeOpportunityCount = 0,
            nextOpportunityHint = "No public request",
            lastNote = string.format("%s / %s", marginBand(snapshot), pressureLabel(snapshot.primaryPressure)),
        }

        if options.includeDebug == true then
            row.debug = {
                operatingCash = snapshot.operatingCash or 0,
                totalDebt = snapshot.totalDebt or 0,
                seasonProfit = snapshot.seasonProfit or 0,
                stressScore = snapshot.stressScore or 0,
            }
        end

        rows[#rows + 1] = row
    end

    table.sort(rows, function(left, right)
        if left.stressRank ~= right.stressRank then
            return left.stressRank > right.stressRank
        end

        return left.displayName < right.displayName
    end)

    return rows
end

function UiModels.buildOverview(state, options)
    options = options or {}

    local profiles, snapshots = stateParts(state)
    local stressedCount = 0
    local strainedOrWorseCount = 0
    local stableCount = 0

    for _, snapshot in ipairs(snapshots) do
        local rank = stressRank(snapshot.stressState)
        if rank > STRESS_RANK.stable then
            stressedCount = stressedCount + 1
        else
            stableCount = stableCount + 1
        end

        if rank >= STRESS_RANK.strained then
            strainedOrWorseCount = strainedOrWorseCount + 1
        end
    end

    local dominantPressureLabel, dominantPressureCount = dominantPressure(snapshots)
    local farmRows = UiModels.buildFarmList(state, {includeDebug = options.includeDebug})
    local alerts = {}

    for _, row in ipairs(farmRows) do
        if #alerts >= (options.maxAlerts or 4) then
            break
        end

        if row.stressRank >= STRESS_RANK.watch then
            alerts[#alerts + 1] = string.format(
                "%s: %s, %s",
                row.displayName,
                row.stressLabel,
                row.primaryPressureLabel
            )
        end
    end

    if #alerts == 0 then
        alerts[1] = "No public pressure alerts this period."
    end

    return {
        title = Constants.DISPLAY_NAME,
        period = (state or {}).periodId or Constants.DEFAULT_PERIOD_ID,
        regionalPreset = (state or {}).regionalPreset or Constants.DEFAULT_REGIONAL_PRESET,
        trackedFarms = #profiles,
        stableFarms = stableCount,
        stressedFarms = stressedCount,
        strainedOrWorseFarms = strainedOrWorseCount,
        activeOpportunities = #((state or {}).opportunities or {}),
        localMarketMood = localMood(stressedCount, strainedOrWorseCount, #profiles),
        dominantPressure = dominantPressureLabel,
        dominantPressureCount = dominantPressureCount,
        cards = {
            {label = "Local mood", value = localMood(stressedCount, strainedOrWorseCount, #profiles)},
            {label = "Tracked farms", value = tostring(#profiles)},
            {label = "Farms watching", value = tostring(stressedCount)},
            {label = "Strained or worse", value = tostring(strainedOrWorseCount)},
            {label = "Main pressure", value = dominantPressureLabel},
            {label = "Active requests", value = tostring(#((state or {}).opportunities or {}))},
        },
        alerts = alerts,
        topFarms = farmRows,
    }
end

function UiModels.buildFarmDetail(state, farmId, options)
    options = options or {}

    local profiles, _, snapshotsByFarmId = stateParts(state)
    local selectedProfile = nil

    for _, profile in ipairs(profiles) do
        if selectedProfile == nil or profile.farmId == farmId then
            selectedProfile = profile
        end
    end

    if selectedProfile == nil then
        return {
            farmId = nil,
            displayName = "No farm selected",
            profileLabel = "Unknown",
            status = {
                stressState = "unknown",
                stressLabel = "Unknown",
                headline = "No farm selected.",
            },
            explanation = {
                mainCause = "No tracked farm is available.",
                supportingCauses = {},
                playerMeaning = "No public action is available.",
            },
            ledgerEstimate = {},
            lines = {},
            opportunities = {},
            history = {},
        }
    end

    local snapshot = snapshotsByFarmId[selectedProfile.farmId] or {}
    local visibleLines = {
        string.format("Profile: %s", profileLabel(selectedProfile)),
        string.format("Fields controlled: %d", countFields(selectedProfile)),
        string.format("Cash position: %s", cashBand(snapshot)),
        string.format("Debt pressure: %s", debtBand(snapshot)),
        string.format("Margin trend: %s", marginBand(snapshot)),
        string.format("Risk buffer: %s", riskBufferBand(snapshot)),
        string.format("Storage pressure: %s", storageBand(selectedProfile)),
        string.format("Machinery position: %s", machineryBand(selectedProfile)),
        string.format("Relationship: %s", relationshipBand(selectedProfile.relationshipScore)),
    }

    if options.includeDebug == true then
        visibleLines[#visibleLines + 1] = string.format("Debug cash: %s", money(snapshot.operatingCash))
        visibleLines[#visibleLines + 1] = string.format("Debug debt: %s", money(snapshot.totalDebt))
        visibleLines[#visibleLines + 1] = string.format("Debug stress score: %d", snapshot.stressScore or 0)
    end

    return {
        farmId = selectedProfile.farmId,
        displayName = selectedProfile.displayName or selectedProfile.farmId or "Unknown Farm",
        profileLabel = profileLabel(selectedProfile),
        status = {
            stressState = snapshot.stressState or Constants.STRESS_STATES.STABLE,
            stressLabel = stressLabel(snapshot.stressState),
            headline = string.format(
                "%s is %s.",
                selectedProfile.displayName or selectedProfile.farmId or "Unknown Farm",
                string.lower(stressLabel(snapshot.stressState))
            ),
        },
        explanation = {
            mainCause = pressureLabel(snapshot.primaryPressure),
            supportingCauses = {
                string.format("Debt pressure is %s", string.lower(debtBand(snapshot))),
                string.format("Risk buffer is %s", string.lower(riskBufferBand(snapshot))),
            },
            playerMeaning = "Public opportunities are not active in this slice.",
        },
        ledgerEstimate = {
            cash = cashBand(snapshot),
            revenue = marginBand(snapshot),
            costs = snapshot.directCosts ~= nil and "Tracked" or "Unknown",
            debt = debtBand(snapshot),
            riskBuffer = riskBufferBand(snapshot),
        },
        lines = visibleLines,
        opportunities = {},
        history = {},
    }
end

function UiModels.buildDebugSummary(state, options)
    options = options or {}

    local profiles, snapshots = stateParts(state)
    local lines = {
        string.format("Mod version: %s", Constants.VERSION),
        string.format("Schema version: %s", tostring((state or {}).schemaVersion or Constants.SAVE_SCHEMA_VERSION)),
        string.format("Seed: %s", tostring((state or {}).seed or Constants.DEFAULT_SEED)),
        string.format("Period: %s", tostring((state or {}).periodId or Constants.DEFAULT_PERIOD_ID)),
        string.format("Regional preset: %s", tostring((state or {}).regionalPreset or Constants.DEFAULT_REGIONAL_PRESET)),
        string.format("Profiles: %d", #profiles),
        string.format("Ledger snapshots: %d", #snapshots),
        string.format("Opportunities: %d", #((state or {}).opportunities or {})),
        string.format("Events: %d", #((state or {}).eventHistory or {})),
        "Save/load hooks: not wired in this slice",
    }

    if options.includeExactFarmValues == true and snapshots[1] ~= nil then
        lines[#lines + 1] = string.format("First farm cash: %s", money(snapshots[1].operatingCash))
        lines[#lines + 1] = string.format("First farm debt: %s", money(snapshots[1].totalDebt))
        lines[#lines + 1] = string.format("First farm stress score: %d", snapshots[1].stressScore or 0)
    end

    return {
        title = "Settings / Debug",
        debugVisible = options.includeExactFarmValues == true,
        lines = lines,
    }
end

function UiModels.getPressureLabel(pressureType)
    return pressureLabel(pressureType)
end

function UiModels.getStressLabel(stressState)
    return stressLabel(stressState)
end
