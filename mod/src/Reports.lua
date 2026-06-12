PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Reports = PhobosRuralLedger.Reports or {}

local Reports = PhobosRuralLedger.Reports
local Constants = PhobosRuralLedger.Constants
local Ledgers = PhobosRuralLedger.Ledgers

local PRESSURE_LABELS = {
    none = "no dominant pressure",
    negative_cash = "cash is tight",
    weak_margin = "season margin is weak",
    debt_service = "debt service is heavy",
    storage_shortage = "storage limits selling options",
    machinery_cost = "machinery costs are high",
    low_diversity = "income is not very diversified",
}

local function money(value)
    value = value or 0

    if value < 0 then
        return string.format("-$%d", math.abs(value))
    end

    return string.format("$%d", value)
end

function Reports.buildProfileSummary(state)
    local lines = {}
    local profiles = {}
    local snapshotsByFarmId = {}

    if state ~= nil and state.profiles ~= nil then
        profiles = state.profiles
    end

    if state ~= nil and state.ledgerSnapshots ~= nil then
        snapshotsByFarmId = Ledgers.indexSnapshotsByFarmId(state.ledgerSnapshots)
    end

    for index, profile in ipairs(profiles) do
        local snapshot = snapshotsByFarmId[profile.farmId] or {}

        lines[index] = string.format(
            "%s: %s, %d owned fields, %s risk, %s stress",
            profile.displayName or profile.farmId or "Unknown Farm",
            profile.label or profile.profileType or "Unknown Profile",
            #(profile.ownedFields or {}),
            profile.riskAttitude or "unknown",
            snapshot.stressState or "unknown"
        )
    end

    return lines
end

function Reports.buildEconomyReport(state, options)
    options = options or {}

    local lines = {}
    local profiles = (state or {}).profiles or {}
    local snapshots = (state or {}).ledgerSnapshots or {}
    local snapshotsByFarmId = Ledgers.indexSnapshotsByFarmId(snapshots)
    local maxLines = options.maxLines or #profiles
    local stressedCount = 0

    for _, snapshot in ipairs(snapshots) do
        if snapshot.stressState ~= Constants.STRESS_STATES.STABLE then
            stressedCount = stressedCount + 1
        end
    end

    lines[#lines + 1] = string.format(
        "Local economy report: %d farms tracked, %d showing watch or worse.",
        #profiles,
        stressedCount
    )

    for index, profile in ipairs(profiles) do
        if index > maxLines then
            break
        end

        local snapshot = snapshotsByFarmId[profile.farmId] or {}
        local pressureLabel = PRESSURE_LABELS[snapshot.primaryPressure or "none"] or "mixed pressure"

        lines[#lines + 1] = string.format(
            "%s is %s: %s profit, %s cash, %s.",
            profile.displayName or profile.farmId or "Unknown Farm",
            snapshot.stressState or "unknown",
            money(snapshot.seasonProfit),
            money(snapshot.operatingCash),
            pressureLabel
        )
    end

    return lines
end
