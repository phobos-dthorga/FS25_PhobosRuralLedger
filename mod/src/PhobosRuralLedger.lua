PhobosRuralLedger = PhobosRuralLedger or {}

local Constants = PhobosRuralLedger.Constants
local Persistence = PhobosRuralLedger.Persistence
local Reports = PhobosRuralLedger.Reports
local Simulation = PhobosRuralLedger.Simulation

PhobosRuralLedger.MOD_NAME = Constants.MOD_NAME
PhobosRuralLedger.DISPLAY_NAME = Constants.DISPLAY_NAME
PhobosRuralLedger.VERSION = Constants.VERSION

local function copyOptionsWithDefaultMaxLines(options)
    local result = {}

    for key, value in pairs(options or {}) do
        result[key] = value
    end

    result.maxLines = result.maxLines or Constants.DEFAULT_LOG_REPORT_FARM_LINES

    return result
end

local function formatMessage(message, ...)
    if select("#", ...) == 0 then
        return tostring(message)
    end

    return string.format(tostring(message), ...)
end

local function logInfo(message, ...)
    if PhobosFS25 ~= nil and PhobosFS25.Logging ~= nil and PhobosFS25.Logging.infoSource ~= nil then
        PhobosFS25.Logging.infoSource("PhobosRuralLedger", message, ...)
    elseif print ~= nil then
        print(string.format("[PhobosRuralLedger][INFO] %s", formatMessage(message, ...)))
    end
end

local function logWarn(message, ...)
    if PhobosFS25 ~= nil and PhobosFS25.Logging ~= nil and PhobosFS25.Logging.warnSource ~= nil then
        PhobosFS25.Logging.warnSource("PhobosRuralLedger", message, ...)
    elseif print ~= nil then
        print(string.format("[PhobosRuralLedger][WARN] %s", formatMessage(message, ...)))
    end
end

local function logError(message, ...)
    if PhobosFS25 ~= nil and PhobosFS25.Logging ~= nil and PhobosFS25.Logging.errorSource ~= nil then
        PhobosFS25.Logging.errorSource("PhobosRuralLedger", message, ...)
    elseif print ~= nil then
        print(string.format("[PhobosRuralLedger][ERROR] %s", formatMessage(message, ...)))
    end
end

local function verifyPhobosLibDependency()
    if PhobosFS25 ~= nil
        and PhobosFS25.Mods ~= nil
        and PhobosFS25.Mods.requireLoaded ~= nil
        and g_modIsLoaded ~= nil
    then
        PhobosFS25.Mods.requireLoaded("FS25_PhobosLib", "PhobosRuralLedger")
    end
end

function PhobosRuralLedger.logInfo(message, ...)
    logInfo(message, ...)
end

function PhobosRuralLedger.logWarn(message, ...)
    logWarn(message, ...)
end

function PhobosRuralLedger.logError(message, ...)
    logError(message, ...)
end

function PhobosRuralLedger.getState()
    return PhobosRuralLedger.state
end

function PhobosRuralLedger.getEconomyReport(options)
    return Reports.buildEconomyReport(PhobosRuralLedger.state, options)
end

function PhobosRuralLedger.getProfileSummary(options)
    return Reports.buildProfileSummary(PhobosRuralLedger.state, options)
end

function PhobosRuralLedger.logEconomyReport(options)
    local reportOptions = copyOptionsWithDefaultMaxLines(options)
    local lines = PhobosRuralLedger.getEconomyReport(reportOptions)

    for _, line in ipairs(lines) do
        logInfo("%s", line)
    end

    return lines
end

function PhobosRuralLedger.bootstrap()
    if PhobosRuralLedger.isBootstrapped then
        return
    end

    PhobosRuralLedger.isBootstrapped = true
    verifyPhobosLibDependency()
    PhobosRuralLedger.state = Persistence.importState(nil)
    Simulation.calculatePeriod(PhobosRuralLedger.state)
    PhobosRuralLedger.reportLines = PhobosRuralLedger.logEconomyReport()
end

PhobosRuralLedger.bootstrap()
