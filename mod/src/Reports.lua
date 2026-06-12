PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Reports = PhobosRuralLedger.Reports or {}

local Reports = PhobosRuralLedger.Reports
local Constants = PhobosRuralLedger.Constants
local I18n = PhobosRuralLedger.I18n
local UiModels = PhobosRuralLedger.UiModels

local function text(key, fallback, ...)
    if I18n ~= nil and I18n.get ~= nil then
        return I18n.get(key, fallback, ...)
    end

    if select("#", ...) > 0 then
        local ok, value = pcall(string.format, fallback or key, ...)
        if ok then
            return value
        end
    end

    return fallback or key
end

function Reports.buildProfileSummary(state)
    local lines = {}
    local rows = UiModels.buildFarmList(state)

    for index, row in ipairs(rows) do
        lines[index] = text(
            "rl_report_profile_summary",
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

    lines[#lines + 1] = text(
        "rl_report_header",
        "Local economy report: %d farms tracked, %d showing watch or worse.",
        overview.trackedFarms,
        overview.stressedFarms
    )

    for index, row in ipairs(rows) do
        if index > maxLines then
            break
        end

        lines[#lines + 1] = text(
            "rl_report_row",
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
