PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Reports = PhobosRuralLedger.Reports or {}

local Reports = PhobosRuralLedger.Reports
local Constants = PhobosRuralLedger.Constants
local UiModels = PhobosRuralLedger.UiModels

function Reports.buildProfileSummary(state)
    local lines = {}
    local rows = UiModels.buildFarmList(state)

    for index, row in ipairs(rows) do
        lines[index] = string.format(
            "%s: %s, %d fields, %s stress, %s",
            row.displayName,
            row.profileLabel,
            row.fields,
            row.stressLabel,
            row.primaryPressureLabel
        )
    end

    return lines
end

function Reports.buildEconomyReport(state, options)
    options = options or {}

    local lines = {}
    local overview = UiModels.buildOverview(state, {maxAlerts = options.maxAlerts})
    local rows = UiModels.buildFarmList(state)
    local maxLines = options.maxLines or #rows

    lines[#lines + 1] = string.format(
        "Local economy report: %d farms tracked, %d showing watch or worse.",
        overview.trackedFarms,
        overview.stressedFarms
    )

    for index, row in ipairs(rows) do
        if index > maxLines then
            break
        end

        lines[#lines + 1] = string.format(
            "%s is %s: %s margin, %s cash, %s.",
            row.displayName,
            string.lower(row.stressLabel),
            string.lower(row.marginBand),
            string.lower(row.cashBand),
            string.lower(row.primaryPressureLabel)
        )
    end

    return lines
end
