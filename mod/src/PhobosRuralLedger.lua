PhobosRuralLedger = PhobosRuralLedger or {}

local Constants = PhobosRuralLedger.Constants
local Persistence = PhobosRuralLedger.Persistence
local Reports = PhobosRuralLedger.Reports
local Simulation = PhobosRuralLedger.Simulation
local MapDiscovery = PhobosRuralLedger.MapDiscovery

PhobosRuralLedger.MOD_NAME = Constants.MOD_NAME
PhobosRuralLedger.DISPLAY_NAME = Constants.DISPLAY_NAME
PhobosRuralLedger.VERSION = Constants.VERSION
PhobosRuralLedger.mapLoadDiscoveryAttempted = PhobosRuralLedger.mapLoadDiscoveryAttempted == true
PhobosRuralLedger.missionStartDiscoveryAttempted = PhobosRuralLedger.missionStartDiscoveryAttempted == true
PhobosRuralLedger.screenOpenDiscoveryAttempted = PhobosRuralLedger.screenOpenDiscoveryAttempted == true

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

local function logMapDiscoverySummary(discovery)
    discovery = discovery or {}
    local diagnostics = discovery.diagnostics or {}

    logInfo(
        "Map discovery (%s): %d properties, %d fields, %d farmlands, %d contracts, confidence=%s, grouping=%s, ownerBuckets=%d/%d, managers=%s/%s/%s/%s, raw=%d/%d/%d, usable=%d, skipped=%d/%d, errors=%d/%d, precisionFarming=%s%s%s.",
        tostring(discovery.trigger or diagnostics.trigger or "unknown"),
        discovery.discoveredPropertyCount or 0,
        discovery.discoveredFieldCount or 0,
        discovery.discoveredFarmlandCount or 0,
        discovery.discoveredContractCount or 0,
        tostring(discovery.confidence or "unavailable"),
        tostring(diagnostics.propertyGroupingMode or "none"),
        diagnostics.ownerBucketCount or 0,
        diagnostics.splitOwnerBucketCount or 0,
        diagnostics.fieldManagerAvailable == true and "field" or "no-field",
        diagnostics.farmlandManagerAvailable == true and "farmland" or "no-farmland",
        diagnostics.missionManagerAvailable == true and "mission" or "no-mission",
        diagnostics.npcManagerAvailable == true and "npc" or "no-npc",
        diagnostics.rawFieldCount or 0,
        diagnostics.rawFarmlandCount or 0,
        diagnostics.rawMissionCount or 0,
        diagnostics.usableFieldCount or discovery.discoveredFieldCount or 0,
        diagnostics.skippedFieldCount or 0,
        diagnostics.skippedMissionCount or 0,
        diagnostics.fieldErrorCount or 0,
        diagnostics.missionErrorCount or 0,
        discovery.precisionFarmingAvailable == true and "available" or "not available",
        diagnostics.firstSkippedFieldReason ~= nil and ", firstFieldSkip=" or "",
        diagnostics.firstSkippedFieldReason ~= nil and tostring(diagnostics.firstSkippedFieldReason) or ""
    )
end

local function mapDiscoveryIsUsable(discovery)
    discovery = discovery or {}

    return discovery.source ~= nil
        and discovery.source ~= "none"
        and (discovery.discoveredFieldCount or 0) > 0
end

local function copyDiscoveryOptions(options, trigger)
    local result = {}

    for key, value in pairs((options or {}).discoveryOptions or {}) do
        result[key] = value
    end

    result.trigger = trigger or result.trigger or (options or {}).trigger or "manualRefresh"
    if result.mapReadyAttempted == nil then
        result.mapReadyAttempted = (options or {}).mapReadyAttempted ~= false
    end

    return result
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

function PhobosRuralLedger.hasUsableMapDiscovery()
    return mapDiscoveryIsUsable((PhobosRuralLedger.state or {}).mapDiscovery)
end

function PhobosRuralLedger.refreshMapBackedState(options)
    options = options or {}

    local previous = PhobosRuralLedger.state or {}
    local trigger = options.trigger or "manualRefresh"
    local discovery = nil
    if MapDiscovery ~= nil and MapDiscovery.discover ~= nil then
        local ok, result = pcall(MapDiscovery.discover, copyDiscoveryOptions(options, trigger))
        if ok then
            discovery = result
        elseif MapDiscovery.empty ~= nil then
            discovery = MapDiscovery.empty({
                trigger = trigger,
                mapReadyAttempted = true,
            })
            discovery.diagnostics.discoveryError = tostring(result)
            discovery.diagnostics.fieldErrorCount = (discovery.diagnostics.fieldErrorCount or 0) + 1
            discovery.diagnostics.firstSkippedFieldReason = discovery.diagnostics.firstSkippedFieldReason or tostring(result)
        end
    end

    PhobosRuralLedger.state = Persistence.createInitialState({
        seed = previous.seed or Constants.DEFAULT_SEED,
        periodId = previous.periodId or Constants.DEFAULT_PERIOD_ID,
        regionalPreset = previous.regionalPreset or Constants.DEFAULT_REGIONAL_PRESET,
        mapDiscovery = discovery,
    })
    PhobosRuralLedger.state.opportunities = previous.opportunities or PhobosRuralLedger.state.opportunities
    PhobosRuralLedger.state.eventHistory = previous.eventHistory or PhobosRuralLedger.state.eventHistory
    PhobosRuralLedger.state.cooldowns = previous.cooldowns or PhobosRuralLedger.state.cooldowns
    Simulation.calculatePeriod(PhobosRuralLedger.state)
    logMapDiscoverySummary(PhobosRuralLedger.state.mapDiscovery)

    return PhobosRuralLedger.state
end

function PhobosRuralLedger.tryMapReadyDiscovery(trigger)
    trigger = trigger or "manualRefresh"

    if trigger == "mapLoad" then
        if PhobosRuralLedger.mapLoadDiscoveryAttempted then
            return PhobosRuralLedger.state, false
        end

        PhobosRuralLedger.mapLoadDiscoveryAttempted = true
    elseif trigger == "missionStart" then
        if PhobosRuralLedger.missionStartDiscoveryAttempted or PhobosRuralLedger.hasUsableMapDiscovery() then
            return PhobosRuralLedger.state, false
        end

        PhobosRuralLedger.missionStartDiscoveryAttempted = true
    elseif trigger == "screenOpenRetry" then
        if PhobosRuralLedger.screenOpenDiscoveryAttempted or PhobosRuralLedger.hasUsableMapDiscovery() then
            return PhobosRuralLedger.state, false
        end

        PhobosRuralLedger.screenOpenDiscoveryAttempted = true
    end

    return PhobosRuralLedger.refreshMapBackedState({
        trigger = trigger,
        mapReadyAttempted = true,
    }), true
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
    PhobosRuralLedger.state = Persistence.importState(nil, {
        skipMapDiscovery = true,
        discoveryTrigger = "bootstrap",
        mapReadyAttempted = false,
    })
    logMapDiscoverySummary(PhobosRuralLedger.state.mapDiscovery)
    Simulation.calculatePeriod(PhobosRuralLedger.state)
    PhobosRuralLedger.reportLines = PhobosRuralLedger.logEconomyReport()
end

PhobosRuralLedger.bootstrap()
