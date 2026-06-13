PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Savegame = PhobosRuralLedger.Savegame or {}

local Savegame = PhobosRuralLedger.Savegame
local Constants = PhobosRuralLedger.Constants
local Opportunities = PhobosRuralLedger.Opportunities

Savegame.hookRegistered = Savegame.hookRegistered == true
Savegame.hookStatus = Savegame.hookStatus or "not_attempted"
Savegame.hookTarget = Savegame.hookTarget or nil
Savegame.hookAttempts = Savegame.hookAttempts or 0
Savegame.lastAvailability = Savegame.lastAvailability or nil
Savegame.lastLoadStatus = Savegame.lastLoadStatus or nil
Savegame.lastSaveStatus = Savegame.lastSaveStatus or nil
Savegame._loggedMessages = Savegame._loggedMessages or {}

local function xmlApi()
    return PhobosFS25 ~= nil and PhobosFS25.XmlFile or nil
end

local function savegamesApi()
    return PhobosFS25 ~= nil and PhobosFS25.Savegames or nil
end

local function logInfo(message, ...)
    if PhobosRuralLedger.logInfo ~= nil then
        PhobosRuralLedger.logInfo(message, ...)
    end
end

local function logInfoOnce(key, message, ...)
    key = tostring(key or message or "info")
    if Savegame._loggedMessages[key] == true then
        return false
    end

    Savegame._loggedMessages[key] = true

    if PhobosFS25 ~= nil
        and PhobosFS25.Logging ~= nil
        and PhobosFS25.Logging.infoOnceSource ~= nil
    then
        PhobosFS25.Logging.infoOnceSource("PhobosRuralLedger", message, ...)
    else
        logInfo(message, ...)
    end

    return true
end

local function ensureTrailingSlash(path)
    if path == nil or path == "" then
        return nil
    end

    local last = string.sub(path, -1)
    if last == "/" or last == "\\" then
        return path
    end

    return path .. "/"
end

local function normalizeXmlFileName(fileName)
    if fileName == nil or fileName == "" then
        return nil
    end

    local normalized = tostring(fileName)
    if string.sub(normalized, -4) ~= ".xml" then
        normalized = normalized .. ".xml"
    end

    return normalized
end

local function fallbackSavegameXmlPath(fileName, mission)
    local activeMission = mission or g_currentMission
    if activeMission == nil or activeMission.missionInfo == nil then
        return nil
    end

    local missionInfo = activeMission.missionInfo
    local directory = ensureTrailingSlash(missionInfo.savegameDirectory)
    if directory == nil
        and missionInfo.savegameIndex ~= nil
        and type(getUserProfileAppPath) == "function"
    then
        directory = ensureTrailingSlash(string.format("%ssavegame%d", getUserProfileAppPath(), missionInfo.savegameIndex))
    end

    local normalized = normalizeXmlFileName(fileName)
    if directory == nil or normalized == nil then
        return nil
    end

    return directory .. normalized
end

local function copyStatus(status, details)
    local result = {
        status = status,
    }

    for key, value in pairs(details or {}) do
        result[key] = value
    end

    return result
end

local function recordStatus(kind, status, details)
    local value = copyStatus(status, details)

    if kind == "load" then
        Savegame.lastLoadStatus = value
    elseif kind == "save" then
        Savegame.lastSaveStatus = value
    end

    return value
end

local function sortedPairs(map)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)

    local index = 0
    return function()
        index = index + 1
        local key = keys[index]
        if key == nil then
            return nil
        end

        return key, map[key]
    end
end

function Savegame.describeAvailability(mission)
    local xml = xmlApi()
    local savegames = savegamesApi()
    local path = nil
    local pathSource = nil

    if savegames ~= nil and savegames.buildSavegameXmlPath ~= nil then
        path = savegames.buildSavegameXmlPath(Constants.SAVEGAME_FILE_NAME, mission)
        if path ~= nil then
            pathSource = "PhobosFS25.Savegames"
        end
    end

    if path == nil then
        path = fallbackSavegameXmlPath(Constants.SAVEGAME_FILE_NAME, mission)
        if path ~= nil then
            pathSource = "missionInfo"
        end
    end

    local reason = nil
    if xml == nil then
        reason = "xml_api_unavailable"
    elseif path == nil then
        reason = "savegame_path_unavailable"
    end

    local availability = {
        available = xml ~= nil and path ~= nil,
        path = path,
        pathSource = pathSource,
        reason = reason,
        hasXmlFileApi = xml ~= nil,
        hasSavegamesApi = savegames ~= nil,
        hasMission = (mission or g_currentMission) ~= nil,
    }

    Savegame.lastAvailability = availability
    return availability
end

function Savegame.getPath(mission)
    return Savegame.describeAvailability(mission).path
end

function Savegame.canUse(mission)
    return Savegame.describeAvailability(mission).available == true
end

function Savegame.read(mission)
    local xml = xmlApi()
    local availability = Savegame.describeAvailability(mission)
    local filename = availability.path
    if xml == nil or filename == nil then
        recordStatus("load", "unavailable", availability)
        return nil, "unavailable", availability
    end

    local file = xml.loadIfExists("PhobosRuralLedgerSavegame", filename)
    if file == nil then
        recordStatus("load", "missing", availability)
        return nil, "missing", availability
    end

    local root = Constants.SAVE_KEYS.ROOT
    local data = {
        schemaVersion = xml.getInt(file, root .. "#schemaVersion", Constants.SAVE_SCHEMA_VERSION),
        modVersion = xml.getString(file, root .. "#modVersion", Constants.VERSION),
        periodId = xml.getString(file, root .. ".state#periodId", Constants.DEFAULT_PERIOD_ID),
        opportunities = {},
        eventHistory = {},
        cooldowns = {},
    }

    xml.forEachIndexed(file, root .. ".opportunities.opportunity(%d)", function(_, key)
        local opportunity = Opportunities.normalizeOpportunity({
            opportunityId = xml.getString(file, key .. "#opportunityId", nil),
            farmId = xml.getString(file, key .. "#farmId", nil),
            type = xml.getString(file, key .. "#type", nil),
            reason = xml.getString(file, key .. "#reason", nil),
            causeCode = xml.getString(file, key .. "#causeCode", nil),
            sourcePeriod = xml.getString(file, key .. "#sourcePeriod", data.periodId),
            expiresPeriod = xml.getString(file, key .. "#expiresPeriod", nil),
            severity = xml.getString(file, key .. "#severity", nil),
            cooldownKey = xml.getString(file, key .. "#cooldownKey", nil),
            playerVisible = xml.getBool(file, key .. "#playerVisible", true),
        })

        if opportunity ~= nil then
            data.opportunities[#data.opportunities + 1] = opportunity
        end
    end, Constants.MAX_ACTIVE_OPPORTUNITIES)

    xml.forEachIndexed(file, root .. ".cooldowns.cooldown(%d)", function(_, key)
        local cooldownKey = xml.getString(file, key .. "#key", nil)
        local expiresPeriod = xml.getString(file, key .. "#expiresPeriod", nil)
        if cooldownKey ~= nil and expiresPeriod ~= nil then
            data.cooldowns[cooldownKey] = expiresPeriod
        end
    end, Constants.MAX_ACTIVE_OPPORTUNITIES * 4)

    xml.forEachIndexed(file, root .. ".eventHistory.event(%d)", function(_, key)
        local event = Opportunities.normalizeHistory({
            eventId = xml.getString(file, key .. "#eventId", nil),
            periodId = xml.getString(file, key .. "#periodId", data.periodId),
            farmId = xml.getString(file, key .. "#farmId", nil),
            type = xml.getString(file, key .. "#type", nil),
            causeCode = xml.getString(file, key .. "#causeCode", nil),
            message = xml.getString(file, key .. "#message", nil),
            modVersion = xml.getString(file, key .. "#modVersion", Constants.VERSION),
        })

        if event ~= nil then
            data.eventHistory[#data.eventHistory + 1] = event
        end
    end, Constants.MAX_EVENT_HISTORY)

    xml.delete(file)
    recordStatus("load", "loaded", availability)
    return data, "loaded", availability
end

function Savegame.write(state, mission)
    local xml = xmlApi()
    local availability = Savegame.describeAvailability(mission)
    local filename = availability.path
    if xml == nil or filename == nil then
        recordStatus("save", "unavailable", availability)
        return false, "unavailable", availability
    end

    local root = Constants.SAVE_KEYS.ROOT
    local file = xml.create("PhobosRuralLedgerSavegame", filename, root)
    if file == nil then
        recordStatus("save", "create_failed", availability)
        return false, "create_failed", availability
    end

    state = state or {}
    xml.setInt(file, root .. "#schemaVersion", Constants.SAVE_SCHEMA_VERSION)
    xml.setString(file, root .. "#modVersion", Constants.VERSION)
    xml.setString(file, root .. ".state#periodId", state.periodId or Constants.DEFAULT_PERIOD_ID)

    for index, opportunity in ipairs(state.opportunities or {}) do
        if index > Constants.MAX_ACTIVE_OPPORTUNITIES then
            break
        end

        local key = string.format("%s.opportunities.opportunity(%d)", root, index - 1)
        local record = Opportunities.normalizeOpportunity(opportunity)
        if record ~= nil then
            xml.setString(file, key .. "#opportunityId", record.opportunityId)
            xml.setString(file, key .. "#farmId", record.farmId)
            xml.setString(file, key .. "#type", record.type)
            xml.setString(file, key .. "#reason", record.reason)
            xml.setString(file, key .. "#causeCode", record.causeCode)
            xml.setString(file, key .. "#sourcePeriod", record.sourcePeriod)
            xml.setString(file, key .. "#expiresPeriod", record.expiresPeriod)
            xml.setString(file, key .. "#severity", record.severity)
            xml.setString(file, key .. "#cooldownKey", record.cooldownKey)
            xml.setBool(file, key .. "#playerVisible", record.playerVisible)
        end
    end

    local cooldownIndex = 0
    for cooldownKey, expiresPeriod in sortedPairs(state.cooldowns or {}) do
        local key = string.format("%s.cooldowns.cooldown(%d)", root, cooldownIndex)
        xml.setString(file, key .. "#key", cooldownKey)
        xml.setString(file, key .. "#expiresPeriod", expiresPeriod)
        cooldownIndex = cooldownIndex + 1
        if cooldownIndex >= Constants.MAX_ACTIVE_OPPORTUNITIES * 4 then
            break
        end
    end

    for index, event in ipairs(state.eventHistory or {}) do
        if index > Constants.MAX_EVENT_HISTORY then
            break
        end

        local key = string.format("%s.eventHistory.event(%d)", root, index - 1)
        local record = Opportunities.normalizeHistory(event)
        if record ~= nil then
            xml.setString(file, key .. "#eventId", record.eventId)
            xml.setString(file, key .. "#periodId", record.periodId)
            xml.setString(file, key .. "#farmId", record.farmId)
            xml.setString(file, key .. "#type", record.type)
            xml.setString(file, key .. "#causeCode", record.causeCode)
            xml.setString(file, key .. "#message", record.message)
            xml.setString(file, key .. "#modVersion", record.modVersion)
        end
    end

    local saved = xml.saveAndDelete(file)
    local status = saved == true and "saved" or "save_failed"
    recordStatus("save", status, availability)
    return saved == true, status, availability
end

function Savegame.onSaveSavegame(mission)
    if PhobosRuralLedger.saveOpportunityState ~= nil then
        PhobosRuralLedger.saveOpportunityState(mission)
    end
end

local function onSaveSavegame(mission)
    Savegame.onSaveSavegame(mission)
end

local function findSaveHookTarget()
    if FSBaseMission ~= nil and FSBaseMission.saveSavegame ~= nil then
        return FSBaseMission, "FSBaseMission.saveSavegame"
    end

    if Mission00 ~= nil and Mission00.saveSavegame ~= nil then
        return Mission00, "Mission00.saveSavegame"
    end

    return nil, nil
end

function Savegame.ensureHookRegistered()
    if Savegame.hookRegistered == true then
        Savegame.hookStatus = "already_registered"
        return true, Savegame.hookStatus
    end

    Savegame.hookAttempts = (Savegame.hookAttempts or 0) + 1

    if Utils == nil or Utils.appendedFunction == nil then
        Savegame.hookStatus = "utils_unavailable"
        logInfoOnce(
            "save-hook-utils-unavailable",
            "Rural Ledger save hook is not available yet: Utils.appendedFunction is missing."
        )
        return false, Savegame.hookStatus
    end

    local target, targetName = findSaveHookTarget()
    if target == nil then
        Savegame.hookStatus = "target_unavailable"
        logInfoOnce(
            "save-hook-target-unavailable",
            "Rural Ledger save hook is not available yet: saveSavegame target is missing."
        )
        return false, Savegame.hookStatus
    end

    target.saveSavegame = Utils.appendedFunction(target.saveSavegame, onSaveSavegame)
    Savegame.hookRegistered = true
    Savegame.hookStatus = "registered"
    Savegame.hookTarget = targetName
    logInfoOnce("save-hook-registered", "Rural Ledger save hook registered: %s.", targetName)

    return true, Savegame.hookStatus
end

local function statusText(status)
    if status == nil then
        return "not attempted"
    end

    local text = tostring(status.status or "unknown")
    if status.path ~= nil then
        text = string.format("%s (%s)", text, tostring(status.path))
    elseif status.reason ~= nil then
        text = string.format("%s (%s)", text, tostring(status.reason))
    end

    return text
end

function Savegame.getDiagnostics(mission)
    local availability = Savegame.lastAvailability or Savegame.describeAvailability(mission)

    return {
        hookRegistered = Savegame.hookRegistered == true,
        hookStatus = Savegame.hookStatus or "not_attempted",
        hookTarget = Savegame.hookTarget or "none",
        hookAttempts = Savegame.hookAttempts or 0,
        path = availability.path or "unavailable",
        pathSource = availability.pathSource or "none",
        availability = availability.available == true and "available" or tostring(availability.reason or "unavailable"),
        lastLoad = statusText(Savegame.lastLoadStatus),
        lastSave = statusText(Savegame.lastSaveStatus),
    }
end

function Savegame._resetDiagnosticsForTests()
    Savegame.hookRegistered = false
    Savegame.hookStatus = "not_attempted"
    Savegame.hookTarget = nil
    Savegame.hookAttempts = 0
    Savegame.lastAvailability = nil
    Savegame.lastLoadStatus = nil
    Savegame.lastSaveStatus = nil
    Savegame._loggedMessages = {}
end

Savegame.ensureHookRegistered()
