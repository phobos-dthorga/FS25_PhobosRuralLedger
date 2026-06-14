PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Savegame = PhobosRuralLedger.Savegame or {}

local Savegame = PhobosRuralLedger.Savegame
local Constants = PhobosRuralLedger.Constants
local Opportunities = PhobosRuralLedger.Opportunities
local JobRequests = PhobosRuralLedger.JobRequests
local Newspaper = PhobosRuralLedger.Newspaper

Savegame.hookRegistered = Savegame.hookRegistered == true
Savegame.hookStatus = Savegame.hookStatus or "not_attempted"
Savegame.hookTarget = Savegame.hookTarget or nil
Savegame.hookAttempts = Savegame.hookAttempts or 0
Savegame.lastAvailability = Savegame.lastAvailability or nil
Savegame.lastLoadStatus = Savegame.lastLoadStatus or nil
Savegame.lastSaveStatus = Savegame.lastSaveStatus or nil
Savegame._loggedMessages = Savegame._loggedMessages or {}

local function formatMessage(message, ...)
    if select("#", ...) == 0 then
        return tostring(message)
    end

    local ok, formatted = pcall(string.format, tostring(message), ...)
    if ok then
        return formatted
    end

    return tostring(message)
end

local function xmlApi()
    if XMLFile ~= nil then
        return Savegame.DirectXmlFile, "XMLFile"
    end

    return nil, nil
end

local function logInfo(message, ...)
    if PhobosRuralLedger.logInfo ~= nil then
        PhobosRuralLedger.logInfo(message, ...)
    elseif print ~= nil then
        print(string.format("[PhobosRuralLedger][INFO] %s", formatMessage(message, ...)))
    end
end

local function logInfoOnce(key, message, ...)
    key = tostring(key or message or "info")
    if Savegame._loggedMessages[key] == true then
        return false
    end

    Savegame._loggedMessages[key] = true
    logInfo(message, ...)

    return true
end

local function callXmlMethod(xmlFile, methodName, ...)
    if xmlFile == nil or xmlFile[methodName] == nil then
        return false, nil
    end

    local ok, value = pcall(xmlFile[methodName], xmlFile, ...)
    return ok, value
end

local function coerceBool(value, defaultValue)
    if value == nil then
        return defaultValue
    end

    if type(value) == "boolean" then
        return value
    end

    if type(value) == "number" then
        return value ~= 0
    end

    local normalized = string.lower(tostring(value))
    if normalized == "true" or normalized == "1" or normalized == "yes" then
        return true
    end
    if normalized == "false" or normalized == "0" or normalized == "no" then
        return false
    end

    return defaultValue
end

Savegame.DirectXmlFile = Savegame.DirectXmlFile or {}

function Savegame.DirectXmlFile.loadIfExists(label, filename, schema)
    if XMLFile == nil or XMLFile.loadIfExists == nil or filename == nil then
        return nil
    end

    return XMLFile.loadIfExists(label or "PhobosRuralLedgerXmlFile", filename, schema)
end

function Savegame.DirectXmlFile.create(label, filename, rootKey, schema)
    if XMLFile == nil or XMLFile.create == nil or filename == nil or rootKey == nil then
        return nil
    end

    return XMLFile.create(label or "PhobosRuralLedgerXmlFile", filename, rootKey, schema)
end

function Savegame.DirectXmlFile.hasProperty(xmlFile, key)
    local ok, value = callXmlMethod(xmlFile, "hasProperty", key)
    return ok and value == true
end

function Savegame.DirectXmlFile.getString(xmlFile, key, defaultValue)
    if xmlFile ~= nil and xmlFile.hasProperty ~= nil and not Savegame.DirectXmlFile.hasProperty(xmlFile, key) then
        return defaultValue
    end

    local ok, value = callXmlMethod(xmlFile, "getString", key, defaultValue)
    if ok and value ~= nil then
        return value
    end

    ok, value = callXmlMethod(xmlFile, "getValue", key, defaultValue)
    if ok and value ~= nil then
        return tostring(value)
    end

    return defaultValue
end

function Savegame.DirectXmlFile.getInt(xmlFile, key, defaultValue)
    if xmlFile ~= nil and xmlFile.hasProperty ~= nil and not Savegame.DirectXmlFile.hasProperty(xmlFile, key) then
        return defaultValue
    end

    local ok, value = callXmlMethod(xmlFile, "getInt", key, defaultValue)
    if ok and value ~= nil then
        return value
    end

    ok, value = callXmlMethod(xmlFile, "getValue", key, defaultValue)
    value = ok and value or nil
    value = tonumber(value)

    return value ~= nil and math.floor(value) or defaultValue
end

function Savegame.DirectXmlFile.getBool(xmlFile, key, defaultValue)
    if xmlFile ~= nil and xmlFile.hasProperty ~= nil and not Savegame.DirectXmlFile.hasProperty(xmlFile, key) then
        return defaultValue
    end

    local ok, value = callXmlMethod(xmlFile, "getBool", key, defaultValue)
    if ok and value ~= nil then
        return value == true
    end

    ok, value = callXmlMethod(xmlFile, "getValue", key, defaultValue)
    return coerceBool(ok and value or nil, defaultValue)
end

function Savegame.DirectXmlFile.setString(xmlFile, key, value)
    if value == nil then
        return false
    end

    local ok = callXmlMethod(xmlFile, "setString", key, tostring(value))
    if ok then
        return true
    end

    ok = callXmlMethod(xmlFile, "setValue", key, tostring(value))
    return ok
end

function Savegame.DirectXmlFile.setInt(xmlFile, key, value)
    if value == nil then
        return false
    end

    local ok = callXmlMethod(xmlFile, "setInt", key, value)
    if ok then
        return true
    end

    ok = callXmlMethod(xmlFile, "setValue", key, value)
    return ok
end

function Savegame.DirectXmlFile.setBool(xmlFile, key, value)
    if value == nil then
        return false
    end

    local ok = callXmlMethod(xmlFile, "setBool", key, value == true)
    if ok then
        return true
    end

    ok = callXmlMethod(xmlFile, "setValue", key, value == true)
    return ok
end

function Savegame.DirectXmlFile.forEachIndexed(xmlFile, keyPattern, callback, maxIterations)
    if xmlFile == nil or keyPattern == nil or callback == nil then
        return 0
    end

    local count = 0
    local limit = maxIterations or 10000

    for index = 0, limit - 1 do
        local key = string.format(keyPattern, index)
        if not Savegame.DirectXmlFile.hasProperty(xmlFile, key) then
            break
        end

        callback(xmlFile, key, index)
        count = count + 1
    end

    return count
end

function Savegame.DirectXmlFile.saveAndDelete(xmlFile)
    if xmlFile == nil then
        return false
    end

    local ok, saved = callXmlMethod(xmlFile, "save")
    callXmlMethod(xmlFile, "delete")
    return ok and saved ~= false
end

function Savegame.DirectXmlFile.delete(xmlFile)
    local ok = callXmlMethod(xmlFile, "delete")
    return ok
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

local function countMap(map)
    local count = 0

    for _ in pairs(map or {}) do
        count = count + 1
    end

    return count
end

local function normalizeNewspaper(value)
    if Newspaper ~= nil and Newspaper.normalizeState ~= nil then
        return Newspaper.normalizeState(value)
    end

    return {
        lastDeliveredDay = nil,
        lastCheckedDay = nil,
        lastCheckedMinute = nil,
        pendingEditionId = nil,
        diagnostics = {},
        editions = {},
    }
end

function Savegame.describeAvailability(mission)
    local xml, xmlSource = xmlApi()
    local path = fallbackSavegameXmlPath(Constants.SAVEGAME_FILE_NAME, mission)
    local pathSource = path ~= nil and "missionInfo" or nil

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
        xmlAdapterSource = xmlSource or "unavailable",
        hasSavegamesApi = false,
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
        jobHistory = {},
        relationshipOverrides = {},
        newspaper = normalizeNewspaper(nil),
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

    xml.forEachIndexed(file, root .. ".relationships.relationship(%d)", function(_, key)
        local relationshipKey = xml.getString(file, key .. "#key", nil)
        local score = xml.getInt(file, key .. "#score", nil)
        if relationshipKey ~= nil and score ~= nil then
            data.relationshipOverrides[relationshipKey] = math.max(1, math.min(5, score))
        end
    end, Constants.MAX_RELATIONSHIP_RECORDS)

    xml.forEachIndexed(file, root .. ".jobHistory.job(%d)", function(_, key)
        local event = JobRequests ~= nil and JobRequests.normalizeHistory ~= nil and JobRequests.normalizeHistory({
            eventId = xml.getString(file, key .. "#eventId", nil),
            periodId = xml.getString(file, key .. "#periodId", data.periodId),
            requestId = xml.getString(file, key .. "#requestId", nil),
            farmId = xml.getString(file, key .. "#farmId", nil),
            npcKey = xml.getString(file, key .. "#npcKey", nil),
            npcName = xml.getString(file, key .. "#npcName", nil),
            farmlandId = xml.getString(file, key .. "#farmlandId", nil),
            fieldId = xml.getString(file, key .. "#fieldId", nil),
            type = xml.getString(file, key .. "#type", nil),
            status = xml.getString(file, key .. "#status", nil),
            relationshipDelta = xml.getInt(file, key .. "#relationshipDelta", 0),
            message = xml.getString(file, key .. "#message", nil),
            modVersion = xml.getString(file, key .. "#modVersion", Constants.VERSION),
        }) or nil

        if event ~= nil then
            data.jobHistory[#data.jobHistory + 1] = event
        end
    end, Constants.MAX_JOB_HISTORY)

    local newspaperRoot = root .. ".newspaper"
    data.newspaper = normalizeNewspaper({
        lastDeliveredDay = xml.getInt(file, newspaperRoot .. "#lastDeliveredDay", nil),
        lastCheckedDay = xml.getInt(file, newspaperRoot .. "#lastCheckedDay", nil),
        lastCheckedMinute = xml.getInt(file, newspaperRoot .. "#lastCheckedMinute", nil),
        pendingEditionId = xml.getString(file, newspaperRoot .. "#pendingEditionId", nil),
        editions = {},
    })

    xml.forEachIndexed(file, newspaperRoot .. ".edition(%d)", function(_, key)
        local sections = {}
        xml.forEachIndexed(file, key .. ".section(%d)", function(_, sectionKey)
            local section = {
                title = xml.getString(file, sectionKey .. "#title", nil),
                body = xml.getString(file, sectionKey .. "#body", nil),
            }
            sections[#sections + 1] = section
        end, 8)

        local edition = Newspaper ~= nil and Newspaper.normalizeEdition ~= nil and Newspaper.normalizeEdition({
            editionId = xml.getString(file, key .. "#editionId", nil),
            day = xml.getInt(file, key .. "#day", 0),
            deliveryMinute = xml.getInt(file, key .. "#deliveryMinute", Constants.NEWSPAPER_DELIVERY_MINUTE),
            dateline = xml.getString(file, key .. "#dateline", nil),
            masthead = xml.getString(file, key .. "#masthead", nil),
            headline = xml.getString(file, key .. "#headline", nil),
            summary = xml.getString(file, key .. "#summary", nil),
            sections = sections,
        }) or nil

        if edition ~= nil then
            data.newspaper.editions[#data.newspaper.editions + 1] = edition
        end
    end, Constants.MAX_NEWSPAPER_EDITIONS)

    data.newspaper = normalizeNewspaper(data.newspaper)
    if data.modVersion == "0.1.9.0" and data.newspaper.pendingEditionId ~= nil then
        data.newspaper.pendingEditionId = nil
        data.newspaper.diagnostics = data.newspaper.diagnostics or {}
        data.newspaper.diagnostics.migration = "cleared_v0.1.9.0_pending"
    end

    xml.delete(file)
    availability.periodId = data.periodId
    availability.opportunityCount = #data.opportunities
    availability.eventCount = #data.eventHistory
    availability.cooldownCount = countMap(data.cooldowns)
    availability.jobHistoryCount = #data.jobHistory
    availability.relationshipCount = countMap(data.relationshipOverrides)
    availability.newspaperEditionCount = #((data.newspaper or {}).editions or {})
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

    local relationshipIndex = 0
    for relationshipKey, score in sortedPairs(state.relationshipOverrides or {}) do
        local key = string.format("%s.relationships.relationship(%d)", root, relationshipIndex)
        xml.setString(file, key .. "#key", relationshipKey)
        xml.setInt(file, key .. "#score", math.max(1, math.min(5, tonumber(score) or 3)))
        relationshipIndex = relationshipIndex + 1
        if relationshipIndex >= Constants.MAX_RELATIONSHIP_RECORDS then
            break
        end
    end

    for index, event in ipairs(state.jobHistory or {}) do
        if index > Constants.MAX_JOB_HISTORY then
            break
        end

        local key = string.format("%s.jobHistory.job(%d)", root, index - 1)
        local record = JobRequests ~= nil and JobRequests.normalizeHistory ~= nil and JobRequests.normalizeHistory(event) or event
        if record ~= nil then
            xml.setString(file, key .. "#eventId", record.eventId)
            xml.setString(file, key .. "#periodId", record.periodId)
            xml.setString(file, key .. "#requestId", record.requestId)
            xml.setString(file, key .. "#farmId", record.farmId)
            xml.setString(file, key .. "#npcKey", record.npcKey)
            xml.setString(file, key .. "#npcName", record.npcName)
            xml.setString(file, key .. "#farmlandId", record.farmlandId)
            xml.setString(file, key .. "#fieldId", record.fieldId)
            xml.setString(file, key .. "#type", record.type)
            xml.setString(file, key .. "#status", record.status)
            xml.setInt(file, key .. "#relationshipDelta", record.relationshipDelta or 0)
            xml.setString(file, key .. "#message", record.message)
            xml.setString(file, key .. "#modVersion", record.modVersion)
        end
    end

    local newspaper = normalizeNewspaper(state.newspaper)
    local newspaperRoot = root .. ".newspaper"
    if newspaper.lastDeliveredDay ~= nil then
        xml.setInt(file, newspaperRoot .. "#lastDeliveredDay", newspaper.lastDeliveredDay)
    end
    if newspaper.lastCheckedDay ~= nil then
        xml.setInt(file, newspaperRoot .. "#lastCheckedDay", newspaper.lastCheckedDay)
    end
    if newspaper.lastCheckedMinute ~= nil then
        xml.setInt(file, newspaperRoot .. "#lastCheckedMinute", newspaper.lastCheckedMinute)
    end
    if newspaper.pendingEditionId ~= nil then
        xml.setString(file, newspaperRoot .. "#pendingEditionId", newspaper.pendingEditionId)
    end

    for index, edition in ipairs(newspaper.editions or {}) do
        if index > Constants.MAX_NEWSPAPER_EDITIONS then
            break
        end

        local key = string.format("%s.edition(%d)", newspaperRoot, index - 1)
        local record = Newspaper ~= nil and Newspaper.normalizeEdition ~= nil and Newspaper.normalizeEdition(edition) or edition
        if record ~= nil then
            xml.setString(file, key .. "#editionId", record.editionId)
            xml.setInt(file, key .. "#day", record.day or 0)
            xml.setInt(file, key .. "#deliveryMinute", record.deliveryMinute or Constants.NEWSPAPER_DELIVERY_MINUTE)
            xml.setString(file, key .. "#dateline", record.dateline)
            xml.setString(file, key .. "#masthead", record.masthead)
            xml.setString(file, key .. "#headline", record.headline)
            xml.setString(file, key .. "#summary", record.summary)

            for sectionIndex, section in ipairs(record.sections or {}) do
                if sectionIndex > 8 then
                    break
                end

                local sectionKey = string.format("%s.section(%d)", key, sectionIndex - 1)
                xml.setString(file, sectionKey .. "#title", section.title)
                xml.setString(file, sectionKey .. "#body", section.body)
            end
        end
    end

    local saved = xml.saveAndDelete(file)
    local status = saved == true and "saved" or "save_failed"
    availability.periodId = state.periodId or Constants.DEFAULT_PERIOD_ID
    availability.opportunityCount = math.min(#(state.opportunities or {}), Constants.MAX_ACTIVE_OPPORTUNITIES)
    availability.eventCount = math.min(#(state.eventHistory or {}), Constants.MAX_EVENT_HISTORY)
    availability.cooldownCount = math.min(cooldownIndex, Constants.MAX_ACTIVE_OPPORTUNITIES * 4)
    availability.jobHistoryCount = math.min(#(state.jobHistory or {}), Constants.MAX_JOB_HISTORY)
    availability.relationshipCount = math.min(relationshipIndex, Constants.MAX_RELATIONSHIP_RECORDS)
    availability.newspaperEditionCount = math.min(#(newspaper.editions or {}), Constants.MAX_NEWSPAPER_EDITIONS)
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
        logInfoOnce(
            "save-hook-already-registered",
            "Rural Ledger save hook already registered: %s.",
            tostring(Savegame.hookTarget or "unknown")
        )
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
        xmlAdapterSource = availability.xmlAdapterSource or "unavailable",
        lastLoad = statusText(Savegame.lastLoadStatus),
        lastSave = statusText(Savegame.lastSaveStatus),
        lastLoadPeriod = (Savegame.lastLoadStatus or {}).periodId or "unknown",
        lastSavePeriod = (Savegame.lastSaveStatus or {}).periodId or "unknown",
        lastLoadCounts = {
            opportunities = (Savegame.lastLoadStatus or {}).opportunityCount or 0,
            events = (Savegame.lastLoadStatus or {}).eventCount or 0,
            cooldowns = (Savegame.lastLoadStatus or {}).cooldownCount or 0,
            jobHistory = (Savegame.lastLoadStatus or {}).jobHistoryCount or 0,
            relationships = (Savegame.lastLoadStatus or {}).relationshipCount or 0,
            newspaperEditions = (Savegame.lastLoadStatus or {}).newspaperEditionCount or 0,
        },
        lastSaveCounts = {
            opportunities = (Savegame.lastSaveStatus or {}).opportunityCount or 0,
            events = (Savegame.lastSaveStatus or {}).eventCount or 0,
            cooldowns = (Savegame.lastSaveStatus or {}).cooldownCount or 0,
            jobHistory = (Savegame.lastSaveStatus or {}).jobHistoryCount or 0,
            relationships = (Savegame.lastSaveStatus or {}).relationshipCount or 0,
            newspaperEditions = (Savegame.lastSaveStatus or {}).newspaperEditionCount or 0,
        },
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
