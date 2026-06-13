PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Savegame = PhobosRuralLedger.Savegame or {}

local Savegame = PhobosRuralLedger.Savegame
local Constants = PhobosRuralLedger.Constants
local Opportunities = PhobosRuralLedger.Opportunities

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

local function logWarn(message, ...)
    if PhobosRuralLedger.logWarn ~= nil then
        PhobosRuralLedger.logWarn(message, ...)
    end
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

function Savegame.getPath(mission)
    local savegames = savegamesApi()
    if savegames == nil or savegames.buildSavegameXmlPath == nil then
        return nil
    end

    return savegames.buildSavegameXmlPath(Constants.SAVEGAME_FILE_NAME, mission)
end

function Savegame.canUse(mission)
    return Savegame.getPath(mission) ~= nil and xmlApi() ~= nil
end

function Savegame.read(mission)
    local xml = xmlApi()
    local filename = Savegame.getPath(mission)
    if xml == nil or filename == nil then
        return nil, "unavailable"
    end

    local file = xml.loadIfExists("PhobosRuralLedgerSavegame", filename)
    if file == nil then
        return nil, "missing"
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
    return data, "loaded"
end

function Savegame.write(state, mission)
    local xml = xmlApi()
    local filename = Savegame.getPath(mission)
    if xml == nil or filename == nil then
        return false, "unavailable"
    end

    local root = Constants.SAVE_KEYS.ROOT
    local file = xml.create("PhobosRuralLedgerSavegame", filename, root)
    if file == nil then
        return false, "create_failed"
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
    return saved == true, saved == true and "saved" or "save_failed"
end

function Savegame.onSaveSavegame(mission)
    if PhobosRuralLedger.saveOpportunityState ~= nil then
        PhobosRuralLedger.saveOpportunityState(mission)
    end
end

local function onSaveSavegame(mission)
    Savegame.onSaveSavegame(mission)
end

if FSBaseMission ~= nil
    and FSBaseMission.saveSavegame ~= nil
    and Utils ~= nil
    and Utils.appendedFunction ~= nil
then
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, onSaveSavegame)
end
