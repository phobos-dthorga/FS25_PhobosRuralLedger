PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.MapDiscovery = PhobosRuralLedger.MapDiscovery or {}

local MapDiscovery = PhobosRuralLedger.MapDiscovery

local PRECISION_FARMING_MOD = "FS25_precisionFarming"

local function call(value, methodName, ...)
    if value == nil then
        return nil
    end

    local method = value[methodName]
    if method == nil then
        return nil
    end

    local ok, resultA, resultB, resultC = pcall(method, value, ...)
    if ok then
        return resultA, resultB, resultC
    end

    return nil
end

local function countPairs(values)
    local count = 0

    for _ in pairs(values or {}) do
        count = count + 1
    end

    return count
end

local function managerTable(manager, methodName, fallbackKey)
    if manager == nil then
        return nil
    end

    local fromMethod = call(manager, methodName)
    if fromMethod ~= nil then
        return fromMethod
    end

    return manager[fallbackKey]
end

local function collectDiagnostics(trigger)
    local fields = managerTable(g_fieldManager, "getFields", "fields")
    local farmlands = managerTable(g_farmlandManager, "getFarmlands", "farmlands")
    local missions = managerTable(g_missionManager, "getMissions", "missions")

    return {
        trigger = trigger or "manualRefresh",
        fieldManagerAvailable = g_fieldManager ~= nil,
        farmlandManagerAvailable = g_farmlandManager ~= nil,
        missionManagerAvailable = g_missionManager ~= nil,
        npcManagerAvailable = g_npcManager ~= nil,
        rawFieldCount = countPairs(fields),
        rawFarmlandCount = countPairs(farmlands),
        rawMissionCount = countPairs(missions),
    }, fields, farmlands, missions
end

local function arrayContains(values, candidate)
    for _, value in ipairs(values or {}) do
        if value == candidate then
            return true
        end
    end

    return false
end

local function appendUnique(values, candidate)
    if candidate == nil or candidate == "" then
        return
    end

    if not arrayContains(values, candidate) then
        values[#values + 1] = candidate
    end
end

local function sortedCopy(values)
    local result = {}

    for index, value in ipairs(values or {}) do
        result[index] = value
    end

    table.sort(result, function(left, right)
        return tostring(left) < tostring(right)
    end)

    return result
end

local function displayObjectName(value)
    if value == nil then
        return nil
    end

    if type(value) == "string" or type(value) == "number" then
        local text = tostring(value)
        return text ~= "" and text or nil
    end

    local fromMethod = call(value, "getName")
    if fromMethod ~= nil and fromMethod ~= "" then
        return tostring(fromMethod)
    end

    for _, key in ipairs({"name", "title", "displayName", "farmName"}) do
        if value[key] ~= nil and tostring(value[key]) ~= "" then
            return tostring(value[key])
        end
    end

    return nil
end

local function getFieldId(field)
    return call(field, "getId") or field.id or field.fieldId
end

local function getFieldArea(field)
    return call(field, "getAreaHa") or field.areaHa
end

local function getFieldName(field, fieldId)
    return call(field, "getName") or field.name or string.format("Field %s", tostring(fieldId or "?"))
end

local function getFieldPosition(field)
    local x, z = call(field, "getCenterOfFieldWorldPosition")
    if x ~= nil and z ~= nil then
        return x, z
    end

    local indicatorX, _, indicatorZ = call(field, "getIndicatorPosition")
    return indicatorX, indicatorZ
end

local function getFieldState(field)
    return call(field, "getFieldState") or {}
end

local function getFarmlandById(farmlandId)
    if g_farmlandManager == nil or farmlandId == nil then
        return nil
    end

    local farmland = call(g_farmlandManager, "getFarmlandById", farmlandId)
    if farmland ~= nil then
        return farmland
    end

    local farmlands = managerTable(g_farmlandManager, "getFarmlands", "farmlands")
    return (farmlands or {})[farmlandId]
end

local function getFieldFarmland(field, fieldState, x, z)
    if field ~= nil and field.farmland ~= nil then
        return field.farmland
    end

    if fieldState ~= nil and fieldState.farmlandId ~= nil then
        local farmland = getFarmlandById(fieldState.farmlandId)
        if farmland ~= nil then
            return farmland
        end
    end

    if g_farmlandManager ~= nil and x ~= nil and z ~= nil then
        return call(g_farmlandManager, "getFarmlandAtWorldPosition", x, z)
    end

    return nil
end

local function getFarmlandId(fieldState, farmland, x, z)
    if fieldState ~= nil and tonumber(fieldState.farmlandId) ~= nil and tonumber(fieldState.farmlandId) > 0 then
        return fieldState.farmlandId
    end

    if farmland ~= nil and farmland.id ~= nil then
        return farmland.id
    end

    if g_farmlandManager ~= nil and x ~= nil and z ~= nil then
        local farmlandId = call(g_farmlandManager, "getFarmlandIdAtWorldPosition", x, z)
        if tonumber(farmlandId) ~= nil and tonumber(farmlandId) > 0 then
            return farmlandId
        end
    end

    return nil
end

local function getOwnerFarmId(fieldState, farmlandId)
    if fieldState ~= nil and tonumber(fieldState.ownerFarmId) ~= nil and tonumber(fieldState.ownerFarmId) > 0 then
        return fieldState.ownerFarmId
    end

    if g_farmlandManager ~= nil and farmlandId ~= nil then
        local ownerFarmId = call(g_farmlandManager, "getFarmlandOwner", farmlandId)
        if tonumber(ownerFarmId) ~= nil and tonumber(ownerFarmId) > 0 then
            return ownerFarmId
        end
    end

    return nil
end

local function getFarmName(ownerFarmId)
    if ownerFarmId == nil or g_farmManager == nil then
        return nil
    end

    local farm = call(g_farmManager, "getFarmById", ownerFarmId)
    return displayObjectName(farm)
end

local function getNpcName(farmland, mission)
    local npc = nil

    if mission ~= nil then
        npc = call(mission, "getNPC")
        if npc == nil then
            npc = mission.npc or mission.npcName
        end
    end

    if npc == nil and farmland ~= nil then
        npc = call(farmland, "getNPC")
        if npc == nil then
            npc = farmland.npc
        end
        if npc == nil and farmland.npcIndex ~= nil and g_npcManager ~= nil then
            npc = call(g_npcManager, "getNPCByIndex", farmland.npcIndex)
        end
    end

    return displayObjectName(npc)
end

local function getFruitName(fruitTypeIndex)
    if fruitTypeIndex == nil or fruitTypeIndex == 0 then
        return nil
    end

    if FruitType ~= nil and FruitType.UNKNOWN ~= nil and fruitTypeIndex == FruitType.UNKNOWN then
        return nil
    end

    if g_fruitTypeManager ~= nil then
        local desc = call(g_fruitTypeManager, "getFruitTypeByIndex", fruitTypeIndex)
        if desc ~= nil then
            return displayObjectName(desc) or desc.name or desc.fillTypeName
        end
    end

    return tostring(fruitTypeIndex)
end

local function conditionCodes(fieldState)
    local codes = {}

    if tonumber(fieldState.weedState) ~= nil and tonumber(fieldState.weedState) > 0 then
        codes[#codes + 1] = "weeds"
    end

    if tonumber(fieldState.stoneLevel) ~= nil and tonumber(fieldState.stoneLevel) > 0 then
        codes[#codes + 1] = "stones"
    end

    if tonumber(fieldState.plowLevel) ~= nil and tonumber(fieldState.plowLevel) == 0 then
        codes[#codes + 1] = "ploughing"
    end

    if tonumber(fieldState.rollerLevel) ~= nil and tonumber(fieldState.rollerLevel) == 0 then
        codes[#codes + 1] = "rolling"
    end

    if tonumber(fieldState.waterLevel) ~= nil and tonumber(fieldState.waterLevel) > 0 then
        codes[#codes + 1] = "watered"
    end

    if #codes == 0 then
        codes[1] = "tracked"
    end

    return codes
end

local function summarizeConditionCodes(codes)
    return table.concat(codes or {"tracked"}, ", ")
end

local function createFieldRecord(field, missionByFieldId)
    local fieldId = getFieldId(field)
    local x, z = getFieldPosition(field)
    local fieldState = getFieldState(field)
    local farmland = getFieldFarmland(field, fieldState, x, z)
    local farmlandId = getFarmlandId(fieldState, farmland, x, z)
    local ownerFarmId = getOwnerFarmId(fieldState, farmlandId)
    local mission = missionByFieldId[fieldId]
    local npcName = getNpcName(farmland, mission)
    local cropType = getFruitName(fieldState.fruitTypeIndex)
    local fieldConditionCodes = conditionCodes(fieldState)

    return {
        fieldId = fieldId,
        fieldName = getFieldName(field, fieldId),
        farmlandId = farmlandId,
        ownerFarmId = ownerFarmId,
        ownerName = getFarmName(ownerFarmId),
        npcName = npcName,
        areaHa = getFieldArea(field),
        cropType = cropType,
        growthState = fieldState.growthState,
        conditionCodes = fieldConditionCodes,
        conditionSummary = summarizeConditionCodes(fieldConditionCodes),
        fieldState = {
            isValid = fieldState.isValid == true,
            fruitTypeIndex = fieldState.fruitTypeIndex,
            growthState = fieldState.growthState,
            weedState = fieldState.weedState,
            stoneLevel = fieldState.stoneLevel,
            groundType = fieldState.groundType,
            sprayLevel = fieldState.sprayLevel,
            sprayType = fieldState.sprayType,
            limeLevel = fieldState.limeLevel,
            rollerLevel = fieldState.rollerLevel,
            plowLevel = fieldState.plowLevel,
            stubbleShredLevel = fieldState.stubbleShredLevel,
            waterLevel = fieldState.waterLevel,
        },
        missionRef = mission,
    }
end

local function missionTypeName(mission)
    return call(mission, "getMissionTypeName")
        or (mission.type ~= nil and mission.type.name)
        or mission.typeName
        or mission.name
        or "field_mission"
end

local function getMissionField(mission)
    return call(mission, "getField") or mission.field
end

local function discoverMissions(missionSource)
    local missions = {}
    local missionByFieldId = {}

    if g_missionManager == nil and missionSource == nil then
        return missions, missionByFieldId
    end

    local missionIndex = 0
    for _, mission in pairs(missionSource or {}) do
        missionIndex = missionIndex + 1
        local field = getMissionField(mission)
        local fieldId = getFieldId(field)
        local reward = call(mission, "getReward") or call(mission, "getTotalReward")
        local missionRecord = {
            missionId = call(mission, "getUniqueId") or mission.uniqueId or string.format("mission_%03d", missionIndex),
            fieldId = fieldId,
            type = missionTypeName(mission),
            reward = reward,
            status = mission.status,
            npcName = getNpcName(field ~= nil and field.farmland or nil, mission),
        }

        missions[#missions + 1] = missionRecord
        if fieldId ~= nil then
            missionByFieldId[fieldId] = missionRecord
        end
    end

    return missions, missionByFieldId
end

local function propertyKey(field)
    if field.ownerFarmId ~= nil then
        return "owner:" .. tostring(field.ownerFarmId), "high"
    end

    if field.npcName ~= nil then
        return "npc:" .. tostring(field.npcName), "medium"
    end

    if field.farmlandId ~= nil then
        return "farmland:" .. tostring(field.farmlandId), "medium"
    end

    return "field:" .. tostring(field.fieldId or "?"), "low"
end

local function createProperty(key, confidence, field)
    local displayName = field.ownerName or field.npcName
    if displayName == nil and field.farmlandId ~= nil then
        displayName = string.format("Farmland %s", tostring(field.farmlandId))
    end
    if displayName == nil then
        displayName = string.format("Field %s", tostring(field.fieldId or "?"))
    end

    return {
        propertyId = "map_" .. string.gsub(key, "[^%w_%-]", "_"),
        source = "map",
        discoveryConfidence = confidence,
        ownerFarmId = field.ownerFarmId,
        ownerName = field.ownerName,
        npcName = field.npcName,
        displayName = displayName,
        farmlandIds = {},
        fieldIds = {},
        fields = {},
        cropTypes = {},
        conditionSummaries = {},
        fieldConditionCodes = {},
        contractRefs = {},
    }
end

local function appendFieldToProperty(property, field)
    appendUnique(property.farmlandIds, field.farmlandId)
    appendUnique(property.fieldIds, field.fieldId)
    appendUnique(property.cropTypes, field.cropType)
    appendUnique(property.conditionSummaries, field.conditionSummary)
    for _, code in ipairs(field.conditionCodes or {}) do
        appendUnique(property.fieldConditionCodes, code)
    end

    property.fields[#property.fields + 1] = field

    if field.missionRef ~= nil then
        property.contractRefs[#property.contractRefs + 1] = field.missionRef
    end
end

local function buildSummaries(property, precisionFarmingAvailable)
    local cropTypes = sortedCopy(property.cropTypes)
    local conditionSummaries = sortedCopy(property.conditionSummaries)

    property.farmlandIds = sortedCopy(property.farmlandIds)
    property.fieldIds = sortedCopy(property.fieldIds)
    property.cropSummary = #cropTypes > 0 and table.concat(cropTypes, ", ") or "unknown"
    property.fieldConditionSummary = #conditionSummaries > 0 and table.concat(conditionSummaries, "; ") or "tracked"
    property.fieldConditionCodes = sortedCopy(property.fieldConditionCodes)
    property.precisionFarmingStatus = precisionFarmingAvailable and "available_pending" or "not_available"
    property.precisionFarmingSummary = property.precisionFarmingStatus

    table.sort(property.fields, function(left, right)
        return tostring(left.fieldId or "") < tostring(right.fieldId or "")
    end)
end

local function detectPrecisionFarming()
    if PhobosFS25 ~= nil and PhobosFS25.Integrations ~= nil and PhobosFS25.Integrations.withOptionalMod ~= nil then
        local available = PhobosFS25.Integrations.withOptionalMod(PRECISION_FARMING_MOD)
        return available == true
    end

    if g_modIsLoaded ~= nil then
        return g_modIsLoaded[PRECISION_FARMING_MOD] == true
    end

    return false
end

function MapDiscovery.discover(options)
    options = options or {}

    local trigger = options.trigger or "manualRefresh"
    local mapReadyAttempted = options.mapReadyAttempted ~= false
    local diagnostics, fieldSource, _, missionSource = collectDiagnostics(trigger)
    local precisionFarmingAvailable = detectPrecisionFarming()
    local missions, missionByFieldId = discoverMissions(missionSource)
    local fieldRecords = {}
    local propertyByKey = {}
    local properties = {}
    local farmlandIds = {}

    if fieldSource ~= nil then
        for _, field in pairs(fieldSource or {}) do
            local fieldRecord = createFieldRecord(field, missionByFieldId)
            if fieldRecord.fieldId ~= nil then
                fieldRecords[#fieldRecords + 1] = fieldRecord
                appendUnique(farmlandIds, fieldRecord.farmlandId)

                local key, confidence = propertyKey(fieldRecord)
                local property = propertyByKey[key]
                if property == nil then
                    property = createProperty(key, confidence, fieldRecord)
                    propertyByKey[key] = property
                    properties[#properties + 1] = property
                end

                appendFieldToProperty(property, fieldRecord)
            end
        end
    end

    for _, property in ipairs(properties) do
        buildSummaries(property, precisionFarmingAvailable)
    end

    table.sort(properties, function(left, right)
        return tostring(left.displayName) < tostring(right.displayName)
    end)

    table.sort(fieldRecords, function(left, right)
        return tostring(left.fieldId or "") < tostring(right.fieldId or "")
    end)

    local confidence = "unavailable"
    if #properties > 0 then
        confidence = "medium"
        for _, property in ipairs(properties) do
            if property.discoveryConfidence == "high" then
                confidence = "high"
                break
            end
        end
    end

    return {
        source = #properties > 0 and "map" or "none",
        confidence = confidence,
        mapId = options.mapId or ((g_currentMission or {}).missionInfo or {}).mapId or ((g_currentMission or {}).missionInfo or {}).mapTitle or "unknown",
        precisionFarmingAvailable = precisionFarmingAvailable,
        precisionFarmingExactValues = false,
        trigger = trigger,
        mapReadyAttempted = mapReadyAttempted,
        diagnostics = diagnostics,
        properties = properties,
        fields = fieldRecords,
        missions = missions,
        discoveredPropertyCount = #properties,
        discoveredFieldCount = #fieldRecords,
        discoveredFarmlandCount = #farmlandIds,
        discoveredContractCount = #missions,
    }
end

function MapDiscovery.empty(options)
    options = options or {}

    local trigger = options.trigger or "bootstrap"
    local diagnostics = collectDiagnostics(trigger)
    local precisionFarmingAvailable = detectPrecisionFarming()

    return {
        source = "none",
        confidence = "unavailable",
        mapId = options.mapId or ((g_currentMission or {}).missionInfo or {}).mapId or ((g_currentMission or {}).missionInfo or {}).mapTitle or "unknown",
        precisionFarmingAvailable = precisionFarmingAvailable,
        precisionFarmingExactValues = false,
        trigger = trigger,
        mapReadyAttempted = options.mapReadyAttempted == true,
        diagnostics = diagnostics,
        properties = {},
        fields = {},
        missions = {},
        discoveredPropertyCount = 0,
        discoveredFieldCount = 0,
        discoveredFarmlandCount = 0,
        discoveredContractCount = 0,
    }
end
