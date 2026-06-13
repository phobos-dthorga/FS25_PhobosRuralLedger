PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.MapDiscovery = PhobosRuralLedger.MapDiscovery or {}

local MapDiscovery = PhobosRuralLedger.MapDiscovery

local PRECISION_FARMING_MOD = "FS25_precisionFarming"
local MAX_FIELDS_PER_OWNER_PROPERTY = 24
local MAX_FARMLANDS_PER_OWNER_PROPERTY = 8

local function call(value, methodName, ...)
    if value == nil then
        return nil
    end

    local okMethod, method = pcall(function()
        return value[methodName]
    end)
    if not okMethod then
        return nil
    end

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

    if type(value) ~= "table" then
        return nil
    end

    for _, key in ipairs({"name", "title", "displayName", "farmName"}) do
        if value[key] ~= nil and tostring(value[key]) ~= "" then
            return tostring(value[key])
        end
    end

    return nil
end

local function tableValue(value, key)
    if type(value) ~= "table" then
        return nil
    end

    return value[key]
end

local function positiveNumber(value)
    local number = tonumber(value)
    if number ~= nil and number > 0 then
        return number
    end

    return nil
end

local function parseIdFromText(value)
    local text = tostring(value or "")
    local id = text:match("(%d+)%s*$")
    return positiveNumber(id)
end

local function getFieldId(field)
    local id = positiveNumber(tableValue(field, "fieldId"))
        or positiveNumber(call(field, "getId"))
        or positiveNumber(tableValue(field, "id"))
        or parseIdFromText(call(field, "getName"))
        or parseIdFromText(tableValue(field, "name"))

    return id
end

local function getFieldArea(field)
    return call(field, "getAreaHa")
        or tableValue(field, "areaHa")
        or tableValue(field, "fieldArea")
end

local function getFieldName(field, fieldId)
    return call(field, "getName")
        or tableValue(field, "name")
        or string.format("Field %s", tostring(fieldId or "?"))
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
    local fieldState = call(field, "getFieldState") or tableValue(field, "fieldState")
    if type(fieldState) == "table" then
        return fieldState
    end

    return {}
end

local function getFarmlandById(farmlandId)
    farmlandId = positiveNumber(farmlandId)
    if g_farmlandManager == nil or farmlandId == nil then
        return nil
    end

    local farmland = call(g_farmlandManager, "getFarmlandById", farmlandId)
    if farmland ~= nil then
        return farmland
    end

    local farmlands = managerTable(g_farmlandManager, "getFarmlands", "farmlands")
    local byKey = (farmlands or {})[farmlandId]
    if byKey ~= nil then
        return byKey
    end

    for _, candidate in pairs(farmlands or {}) do
        if positiveNumber(tableValue(candidate, "id")) == farmlandId then
            return candidate
        end
    end

    return nil
end

local function getFarmlandRecord(value)
    if type(value) == "table" then
        return value
    end

    return getFarmlandById(value)
end

local function getFarmlandRecordId(value)
    if type(value) == "table" then
        return positiveNumber(value.id) or positiveNumber(value.farmlandId)
    end

    return positiveNumber(value)
end

local function getFieldFarmland(field, fieldState, x, z)
    local fieldFarmland = getFarmlandRecord(tableValue(field, "farmland"))
    if fieldFarmland ~= nil then
        return fieldFarmland
    end

    local fieldStateFarmlandId = positiveNumber(tableValue(fieldState, "farmlandId"))
    if fieldStateFarmlandId ~= nil then
        local farmland = getFarmlandById(fieldStateFarmlandId)
        if farmland ~= nil then
            return farmland
        end
    end

    if g_farmlandManager ~= nil and x ~= nil and z ~= nil then
        return getFarmlandRecord(call(g_farmlandManager, "getFarmlandAtWorldPosition", x, z))
    end

    return nil
end

local function getFarmlandId(fieldState, farmland, x, z)
    local fieldStateFarmlandId = positiveNumber(tableValue(fieldState, "farmlandId"))
    if fieldStateFarmlandId ~= nil then
        return fieldStateFarmlandId
    end

    local farmlandId = getFarmlandRecordId(farmland)
    if farmlandId ~= nil then
        return farmlandId
    end

    if g_farmlandManager ~= nil and x ~= nil and z ~= nil then
        farmlandId = positiveNumber(call(g_farmlandManager, "getFarmlandIdAtWorldPosition", x, z))
        if farmlandId ~= nil then
            return farmlandId
        end

        farmlandId = getFarmlandRecordId(call(g_farmlandManager, "getFarmlandAtWorldPosition", x, z))
        if farmlandId ~= nil then
            return farmlandId
        end
    end

    return nil
end

local function getOwnerFarmId(fieldState, farmland, farmlandId)
    local fieldStateOwnerFarmId = positiveNumber(tableValue(fieldState, "ownerFarmId"))
    if fieldStateOwnerFarmId ~= nil then
        return fieldStateOwnerFarmId
    end

    local farmlandOwnerFarmId = positiveNumber(tableValue(farmland, "ownerFarmId"))
        or positiveNumber(tableValue(farmland, "farmId"))
    if farmlandOwnerFarmId ~= nil then
        return farmlandOwnerFarmId
    end

    if g_farmlandManager ~= nil and farmlandId ~= nil then
        local ownerFarmId = positiveNumber(call(g_farmlandManager, "getFarmlandOwner", farmlandId))
        if ownerFarmId ~= nil then
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
            npc = tableValue(farmland, "npc")
        end
        if npc == nil and tableValue(farmland, "npcIndex") ~= nil and g_npcManager ~= nil then
            npc = call(g_npcManager, "getNPCByIndex", tableValue(farmland, "npcIndex"))
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
            return displayObjectName(desc) or tableValue(desc, "name") or tableValue(desc, "fillTypeName")
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
    if type(field) ~= "table" then
        return nil, "field entry is not a table"
    end

    local fieldId = getFieldId(field)
    if fieldId == nil then
        return nil, "field has no usable fieldId"
    end

    local x, z = getFieldPosition(field)
    local fieldState = getFieldState(field)
    local farmland = getFieldFarmland(field, fieldState, x, z)
    local farmlandId = getFarmlandId(fieldState, farmland, x, z)
    local ownerFarmId = getOwnerFarmId(fieldState, farmland, farmlandId)
    local mission = (missionByFieldId or {})[fieldId]
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
        or tableValue(tableValue(mission, "type"), "name")
        or tableValue(mission, "typeName")
        or tableValue(mission, "name")
        or "field_mission"
end

local function getMissionField(mission)
    return call(mission, "getField") or tableValue(mission, "field")
end

local function createMissionRecord(mission, missionIndex)
    if type(mission) ~= "table" then
        return nil, "mission entry is not a table"
    end

    local field = getMissionField(mission)
    local fieldId = getFieldId(field)
    local reward = call(mission, "getReward") or call(mission, "getTotalReward")

    return {
        missionId = call(mission, "getUniqueId") or mission.uniqueId or string.format("mission_%03d", missionIndex),
        fieldId = fieldId,
        type = missionTypeName(mission),
        reward = reward,
        status = mission.status,
        npcName = getNpcName(type(field) == "table" and field.farmland or nil, mission),
    }
end

local function discoverMissions(missionSource)
    local missions = {}
    local missionByFieldId = {}
    local diagnostics = {
        skippedMissionCount = 0,
        missionErrorCount = 0,
        firstSkippedMissionReason = nil,
    }

    if g_missionManager == nil and missionSource == nil then
        return missions, missionByFieldId, diagnostics
    end

    local missionIndex = 0
    for _, mission in pairs(missionSource or {}) do
        missionIndex = missionIndex + 1
        local ok, missionRecord, reason = pcall(createMissionRecord, mission, missionIndex)

        if ok and missionRecord ~= nil then
            missions[#missions + 1] = missionRecord
            if missionRecord.fieldId ~= nil then
                missionByFieldId[missionRecord.fieldId] = missionRecord
            end
        else
            diagnostics.skippedMissionCount = diagnostics.skippedMissionCount + 1
            if not ok then
                diagnostics.missionErrorCount = diagnostics.missionErrorCount + 1
                reason = missionRecord
            end
            diagnostics.firstSkippedMissionReason = diagnostics.firstSkippedMissionReason or tostring(reason or "unknown mission skip")
        end
    end

    return missions, missionByFieldId, diagnostics
end

local function ownerBucketKey(field)
    if field.ownerFarmId ~= nil then
        return "owner:" .. tostring(field.ownerFarmId), "high"
    end

    if field.npcName ~= nil then
        return "npc:" .. tostring(field.npcName), "medium"
    end

    return nil, nil
end

local function buildOwnerBuckets(fieldRecords)
    local buckets = {}

    for _, field in ipairs(fieldRecords or {}) do
        local key, confidence = ownerBucketKey(field)
        if key ~= nil then
            local bucket = buckets[key]
            if bucket == nil then
                bucket = {
                    confidence = confidence,
                    fieldCount = 0,
                    farmlandIds = {},
                    farmlandSet = {},
                }
                buckets[key] = bucket
            end

            bucket.fieldCount = bucket.fieldCount + 1
            if field.farmlandId ~= nil and bucket.farmlandSet[field.farmlandId] == nil then
                bucket.farmlandSet[field.farmlandId] = true
                bucket.farmlandIds[#bucket.farmlandIds + 1] = field.farmlandId
            end
        end
    end

    return buckets
end

local function ownerBucketShouldSplit(bucket)
    if bucket == nil then
        return false
    end

    return (bucket.fieldCount or 0) > MAX_FIELDS_PER_OWNER_PROPERTY
        or #(bucket.farmlandIds or {}) > MAX_FARMLANDS_PER_OWNER_PROPERTY
end

local function propertyKey(field, ownerBuckets)
    local ownerKey, ownerConfidence = ownerBucketKey(field)
    local ownerBucket = ownerKey ~= nil and ownerBuckets[ownerKey] or nil

    if ownerBucketShouldSplit(ownerBucket) and field.farmlandId ~= nil then
        return ownerKey .. ":farmland:" .. tostring(field.farmlandId), ownerConfidence or "medium", "ownerSplitByFarmland", ownerKey
    end

    if ownerKey ~= nil then
        return ownerKey, ownerConfidence, "owner", ownerKey
    end

    if field.farmlandId ~= nil then
        return "farmland:" .. tostring(field.farmlandId), "medium", "farmland", nil
    end

    return "field:" .. tostring(field.fieldId or "?"), "low", "field", nil
end

local function createProperty(key, confidence, field, groupingMode, sourceOwnerKey)
    local displayName = field.ownerName or field.npcName
    if groupingMode == "ownerSplitByFarmland" and field.farmlandId ~= nil then
        local ownerName = field.ownerName or field.npcName
        if ownerName ~= nil then
            displayName = string.format("%s - Farmland %s", ownerName, tostring(field.farmlandId))
        else
            displayName = string.format("Farmland %s", tostring(field.farmlandId))
        end
    end
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
        groupingMode = groupingMode or "field",
        sourceOwnerKey = sourceOwnerKey,
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
    local missions, missionByFieldId, missionDiagnostics = discoverMissions(missionSource)
    local fieldRecords = {}
    local propertyByKey = {}
    local properties = {}
    local farmlandIds = {}
    local skippedFieldCount = 0
    local fieldErrorCount = 0
    local firstSkippedFieldReason = nil

    if fieldSource ~= nil then
        for _, field in pairs(fieldSource or {}) do
            local ok, fieldRecord, reason = pcall(createFieldRecord, field, missionByFieldId)
            if ok and fieldRecord ~= nil and fieldRecord.fieldId ~= nil then
                fieldRecords[#fieldRecords + 1] = fieldRecord
                appendUnique(farmlandIds, fieldRecord.farmlandId)
            else
                skippedFieldCount = skippedFieldCount + 1
                if not ok then
                    fieldErrorCount = fieldErrorCount + 1
                    reason = fieldRecord
                end
                firstSkippedFieldReason = firstSkippedFieldReason or tostring(reason or "field has no usable record")
            end
        end
    end

    local ownerBuckets = buildOwnerBuckets(fieldRecords)
    local ownerBucketCount = 0
    local splitOwnerBucketCount = 0
    local largestOwnerFieldCount = 0
    local largestOwnerFarmlandCount = 0
    local anyOwnerProperty = false
    local anyFarmlandProperty = false
    local anySplitProperty = false

    for _, bucket in pairs(ownerBuckets) do
        ownerBucketCount = ownerBucketCount + 1
        largestOwnerFieldCount = math.max(largestOwnerFieldCount, bucket.fieldCount or 0)
        largestOwnerFarmlandCount = math.max(largestOwnerFarmlandCount, #(bucket.farmlandIds or {}))
        if ownerBucketShouldSplit(bucket) then
            splitOwnerBucketCount = splitOwnerBucketCount + 1
        end
    end

    for _, fieldRecord in ipairs(fieldRecords) do
        local key, confidence, groupingMode, sourceOwnerKey = propertyKey(fieldRecord, ownerBuckets)
        local property = propertyByKey[key]
        if property == nil then
            property = createProperty(key, confidence, fieldRecord, groupingMode, sourceOwnerKey)
            propertyByKey[key] = property
            properties[#properties + 1] = property
        end

        appendFieldToProperty(property, fieldRecord)

        anyOwnerProperty = anyOwnerProperty or groupingMode == "owner"
        anyFarmlandProperty = anyFarmlandProperty or groupingMode == "farmland"
        anySplitProperty = anySplitProperty or groupingMode == "ownerSplitByFarmland"
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

    diagnostics.usableFieldCount = #fieldRecords
    diagnostics.skippedFieldCount = skippedFieldCount
    diagnostics.fieldErrorCount = fieldErrorCount
    diagnostics.firstSkippedFieldReason = firstSkippedFieldReason
    diagnostics.skippedMissionCount = missionDiagnostics.skippedMissionCount
    diagnostics.missionErrorCount = missionDiagnostics.missionErrorCount
    diagnostics.firstSkippedMissionReason = missionDiagnostics.firstSkippedMissionReason
    diagnostics.ownerBucketCount = ownerBucketCount
    diagnostics.splitOwnerBucketCount = splitOwnerBucketCount
    diagnostics.largestOwnerFieldCount = largestOwnerFieldCount
    diagnostics.largestOwnerFarmlandCount = largestOwnerFarmlandCount
    diagnostics.propertyGroupingMode = anySplitProperty and "ownerSplitByFarmland"
        or anyOwnerProperty and "owner"
        or anyFarmlandProperty and "farmland"
        or (#properties > 0 and "field" or "none")

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
    diagnostics.usableFieldCount = 0
    diagnostics.skippedFieldCount = 0
    diagnostics.fieldErrorCount = 0
    diagnostics.skippedMissionCount = 0
    diagnostics.missionErrorCount = 0

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
