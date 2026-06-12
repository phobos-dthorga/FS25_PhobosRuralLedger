PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Profiles = PhobosRuralLedger.Profiles or {}

local Profiles = PhobosRuralLedger.Profiles
local Constants = PhobosRuralLedger.Constants

local ARCHETYPES = {
    {
        profileType = Constants.PROFILE_TYPES.FAMILY_FARM,
        label = "Small Family Farm",
        enterpriseMix = {"grain", "livestock", "contracts"},
        debtAttitude = "cautious",
        riskAttitude = "balanced",
        storageRange = {2, 4},
        machineryRange = {2, 4},
        fieldRange = {2, 4},
        relationshipBase = 4,
        successionStage = "active_family",
    },
    {
        profileType = Constants.PROFILE_TYPES.CONTRACTOR,
        label = "Contractor",
        enterpriseMix = {"contracts", "grain"},
        debtAttitude = "equipment_debt",
        riskAttitude = "practical",
        storageRange = {1, 3},
        machineryRange = {4, 5},
        fieldRange = {1, 3},
        relationshipBase = 3,
        successionStage = "active_business",
    },
    {
        profileType = Constants.PROFILE_TYPES.DAIRY_OPERATOR,
        label = "Dairy Operator",
        enterpriseMix = {"dairy", "forage", "livestock"},
        debtAttitude = "moderate",
        riskAttitude = "steady",
        storageRange = {3, 5},
        machineryRange = {3, 4},
        fieldRange = {3, 5},
        relationshipBase = 3,
        successionStage = "active_family",
    },
    {
        profileType = Constants.PROFILE_TYPES.GRAIN_GROWER,
        label = "Grain Grower",
        enterpriseMix = {"grain", "oilseed"},
        debtAttitude = "moderate",
        riskAttitude = "market_exposed",
        storageRange = {3, 5},
        machineryRange = {3, 5},
        fieldRange = {4, 7},
        relationshipBase = 2,
        successionStage = "active_business",
    },
    {
        profileType = Constants.PROFILE_TYPES.STRUGGLING_BEGINNER,
        label = "Struggling Beginner",
        enterpriseMix = {"grain", "contracts"},
        debtAttitude = "high_operating_debt",
        riskAttitude = "vulnerable",
        storageRange = {1, 2},
        machineryRange = {1, 3},
        fieldRange = {1, 3},
        relationshipBase = 4,
        successionStage = "new_entrant",
    },
    {
        profileType = Constants.PROFILE_TYPES.WEALTHY_LANDHOLDER,
        label = "Wealthy Landholder",
        enterpriseMix = {"land_rent", "grain"},
        debtAttitude = "low_debt",
        riskAttitude = "expansionist",
        storageRange = {3, 5},
        machineryRange = {3, 5},
        fieldRange = {5, 9},
        relationshipBase = 1,
        successionStage = "consolidating",
    },
    {
        profileType = Constants.PROFILE_TYPES.LIVESTOCK_SPECIALIST,
        label = "Livestock Specialist",
        enterpriseMix = {"livestock", "forage", "contracts"},
        debtAttitude = "moderate",
        riskAttitude = "feed_sensitive",
        storageRange = {2, 4},
        machineryRange = {2, 4},
        fieldRange = {2, 5},
        relationshipBase = 3,
        successionStage = "active_family",
    },
    {
        profileType = Constants.PROFILE_TYPES.REGENERATIVE_FARMER,
        label = "Regenerative Farmer",
        enterpriseMix = {"grain", "conservation", "livestock"},
        debtAttitude = "low_debt",
        riskAttitude = "soil_first",
        storageRange = {2, 4},
        machineryRange = {2, 4},
        fieldRange = {2, 4},
        relationshipBase = 4,
        successionStage = "active_family",
    },
}

local NAME_STEMS = {
    "Ashfield",
    "Briar",
    "Cedar",
    "Dunwell",
    "Elmford",
    "Hansen",
    "Miller",
    "Northbank",
    "Redgate",
    "Sallow",
    "Turner",
    "Wicker",
}

local NAME_SUFFIXES = {
    "Farm",
    "Holdings",
    "Pastures",
    "Fields",
    "Ridge",
    "Acres",
    "Croft",
    "Vale",
}

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function hash(seed, index, salt)
    local text = tostring(seed) .. ":" .. tostring(index) .. ":" .. tostring(salt)
    local value = 5381

    for i = 1, string.len(text) do
        value = ((value * 33) + string.byte(text, i)) % 2147483647
    end

    return value
end

local function pick(list, seed, index, salt)
    local listIndex = (hash(seed, index, salt) % #list) + 1
    return list[listIndex]
end

local function pickRange(range, seed, index, salt)
    local minimum = range[1]
    local maximum = range[2]
    local span = maximum - minimum + 1

    return minimum + (hash(seed, index, salt) % span)
end

local function copyList(list)
    local result = {}

    for index, value in ipairs(list) do
        result[index] = value
    end

    return result
end

local function createSyntheticFields(profileIndex, count)
    local fields = {}

    for index = 1, count do
        fields[index] = string.format("field_%02d_%02d", profileIndex, index)
    end

    return fields
end

local function mapProfileId(property, index)
    if property ~= nil and property.propertyId ~= nil then
        return tostring(property.propertyId)
    end

    return string.format("map_property_%03d", index)
end

local function profileId(index)
    return string.format("npc_farm_%02d", index)
end

local function createDisplayName(seed, index)
    local stem = pick(NAME_STEMS, seed, index, "nameStem")
    local suffix = pick(NAME_SUFFIXES, seed, index, "nameSuffix")

    return string.format("%s %s", stem, suffix)
end

function Profiles.getArchetypes()
    return ARCHETYPES
end

function Profiles.createProfile(index, options)
    options = options or {}

    local seed = options.seed or Constants.DEFAULT_SEED
    local archetype = pick(ARCHETYPES, seed, index, "archetype")
    local fieldCount = pickRange(archetype.fieldRange, seed, index, "fieldCount")
    local fieldsByProfile = options.fieldsByProfile or {}
    local ownedFields = fieldsByProfile[index] or createSyntheticFields(index, fieldCount)
    local storageRating = pickRange(archetype.storageRange, seed, index, "storageRating")
    local machineryRating = pickRange(archetype.machineryRange, seed, index, "machineryRating")
    local relationshipVariance = (hash(seed, index, "relationship") % 3) - 1

    return {
        farmId = profileId(index),
        displayName = createDisplayName(seed, index),
        source = "fallback",
        discoveryConfidence = "fallback",
        propertyId = nil,
        ownerFarmId = nil,
        farmlandIds = {},
        fieldIds = copyList(ownedFields),
        cropSummary = "unknown",
        fieldConditionCodes = {"tracked"},
        fieldConditionSummary = "fallback",
        precisionFarmingStatus = "not_available",
        precisionFarmingSummary = "not available",
        profileType = archetype.profileType,
        label = archetype.label,
        ownedFields = copyList(ownedFields),
        leasedFields = {},
        enterpriseMix = copyList(archetype.enterpriseMix),
        storageRating = storageRating,
        machineryRating = machineryRating,
        debtAttitude = archetype.debtAttitude,
        riskAttitude = archetype.riskAttitude,
        relationshipScore = clamp(archetype.relationshipBase + relationshipVariance, 1, 5),
        coOpStatus = "unknown",
        successionStage = archetype.successionStage,
    }
end

local ENTERPRISE_BY_CROP = {
    barley = "grain",
    corn = "grain",
    oat = "grain",
    rice = "grain",
    sorghum = "grain",
    wheat = "grain",
    canola = "oilseed",
    soybeans = "oilseed",
    sunflowers = "oilseed",
    grass = "forage",
    meadow = "forage",
}

local function addUnique(values, candidate)
    if candidate == nil then
        return
    end

    for _, value in ipairs(values) do
        if value == candidate then
            return
        end
    end

    values[#values + 1] = candidate
end

local function enterpriseMixFromProperty(property, fallbackMix)
    local result = {}

    for _, cropType in ipairs((property or {}).cropTypes or {}) do
        local key = string.lower(tostring(cropType))
        addUnique(result, ENTERPRISE_BY_CROP[key])
    end

    if #result == 0 then
        return copyList(fallbackMix)
    end

    return result
end

function Profiles.createProfileFromProperty(property, index, options)
    options = options or {}

    local seed = options.seed or Constants.DEFAULT_SEED
    local profileKey = mapProfileId(property, index)
    local archetype = pick(ARCHETYPES, seed, profileKey, "archetype")
    local storageRating = pickRange(archetype.storageRange, seed, profileKey, "storageRating")
    local machineryRating = pickRange(archetype.machineryRange, seed, profileKey, "machineryRating")
    local relationshipVariance = (hash(seed, profileKey, "relationship") % 3) - 1
    local fieldIds = copyList((property or {}).fieldIds or {})

    return {
        farmId = profileKey,
        displayName = (property or {}).displayName or profileKey,
        source = (property or {}).source or "map",
        discoveryConfidence = (property or {}).discoveryConfidence or "medium",
        propertyId = (property or {}).propertyId,
        ownerFarmId = (property or {}).ownerFarmId,
        ownerName = (property or {}).ownerName,
        npcName = (property or {}).npcName,
        farmlandIds = copyList((property or {}).farmlandIds or {}),
        fieldIds = copyList(fieldIds),
        cropSummary = (property or {}).cropSummary or "unknown",
        fieldConditionCodes = copyList((property or {}).fieldConditionCodes or {"tracked"}),
        fieldConditionSummary = (property or {}).fieldConditionSummary or "tracked",
        precisionFarmingStatus = (property or {}).precisionFarmingStatus or "not_available",
        precisionFarmingSummary = (property or {}).precisionFarmingSummary or "not available",
        contractRefs = copyList((property or {}).contractRefs or {}),
        mapFields = copyList((property or {}).fields or {}),
        profileType = archetype.profileType,
        label = archetype.label,
        ownedFields = fieldIds,
        leasedFields = {},
        enterpriseMix = enterpriseMixFromProperty(property, archetype.enterpriseMix),
        storageRating = storageRating,
        machineryRating = machineryRating,
        debtAttitude = archetype.debtAttitude,
        riskAttitude = archetype.riskAttitude,
        relationshipScore = clamp(archetype.relationshipBase + relationshipVariance, 1, 5),
        coOpStatus = "unknown",
        successionStage = archetype.successionStage,
    }
end

function Profiles.generateProfiles(options)
    options = options or {}

    local discovery = options.mapDiscovery or {}
    local properties = discovery.properties or {}
    if #properties > 0 then
        local profiles = {}

        for index, property in ipairs(properties) do
            profiles[index] = Profiles.createProfileFromProperty(property, index, options)
        end

        return profiles
    end

    local count = options.count or Constants.DEFAULT_PROFILE_COUNT
    local profiles = {}

    for index = 1, count do
        profiles[index] = Profiles.createProfile(index, options)
    end

    return profiles
end

function Profiles.indexByFarmId(profiles)
    local result = {}

    for index, profile in ipairs(profiles or {}) do
        result[profile.farmId] = profile
    end

    return result
end

function Profiles.normalizeProfile(profile, fallbackIndex)
    local index = fallbackIndex or 1
    local defaults = Profiles.createProfile(index)
    local normalized = {}

    for key, value in pairs(defaults) do
        normalized[key] = value
    end

    for key, value in pairs(profile or {}) do
        normalized[key] = value
    end

    normalized.ownedFields = normalized.ownedFields or {}
    normalized.leasedFields = normalized.leasedFields or {}
    normalized.enterpriseMix = normalized.enterpriseMix or {}
    normalized.source = normalized.source or "fallback"
    normalized.discoveryConfidence = normalized.discoveryConfidence or "fallback"
    normalized.farmlandIds = normalized.farmlandIds or {}
    normalized.fieldIds = normalized.fieldIds or normalized.ownedFields or {}
    normalized.cropSummary = normalized.cropSummary or "unknown"
    normalized.fieldConditionCodes = normalized.fieldConditionCodes or {"tracked"}
    normalized.fieldConditionSummary = normalized.fieldConditionSummary or "fallback"
    normalized.precisionFarmingStatus = normalized.precisionFarmingStatus or "not_available"
    normalized.precisionFarmingSummary = normalized.precisionFarmingSummary or "not available"
    normalized.contractRefs = normalized.contractRefs or {}
    normalized.mapFields = normalized.mapFields or {}

    return normalized
end
