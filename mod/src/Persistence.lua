PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Persistence = PhobosRuralLedger.Persistence or {}

local Persistence = PhobosRuralLedger.Persistence
local Constants = PhobosRuralLedger.Constants
local Profiles = PhobosRuralLedger.Profiles
local Ledgers = PhobosRuralLedger.Ledgers
local MapDiscovery = PhobosRuralLedger.MapDiscovery

local function copyArray(values)
    local result = {}

    for index, value in ipairs(values or {}) do
        result[index] = value
    end

    return result
end

function Persistence.createInitialState(options)
    options = options or {}

    local seed = options.seed or Constants.DEFAULT_SEED
    local periodId = options.periodId or Constants.DEFAULT_PERIOD_ID
    local mapDiscovery = options.mapDiscovery
    if mapDiscovery == nil and MapDiscovery ~= nil and MapDiscovery.discover ~= nil then
        mapDiscovery = MapDiscovery.discover(options.discoveryOptions)
    end

    local profiles = Profiles.generateProfiles({
        count = options.profileCount or Constants.DEFAULT_PROFILE_COUNT,
        seed = seed,
        fieldsByProfile = options.fieldsByProfile,
        mapDiscovery = mapDiscovery,
    })

    return {
        schemaVersion = Constants.SAVE_SCHEMA_VERSION,
        modVersion = Constants.VERSION,
        seed = seed,
        periodId = periodId,
        regionalPreset = options.regionalPreset or Constants.DEFAULT_REGIONAL_PRESET,
        mapDiscovery = mapDiscovery,
        profiles = profiles,
        ledgerSnapshots = Ledgers.createInitialSnapshots(profiles, periodId),
        opportunities = {},
        eventHistory = {},
        cooldowns = {},
    }
end

function Persistence.exportState(state)
    local source = state or Persistence.createInitialState()

    return {
        schemaVersion = source.schemaVersion or Constants.SAVE_SCHEMA_VERSION,
        modVersion = source.modVersion or Constants.VERSION,
        seed = source.seed or Constants.DEFAULT_SEED,
        periodId = source.periodId or Constants.DEFAULT_PERIOD_ID,
        regionalPreset = source.regionalPreset or Constants.DEFAULT_REGIONAL_PRESET,
        mapDiscovery = source.mapDiscovery,
        profiles = copyArray(source.profiles),
        ledgerSnapshots = copyArray(source.ledgerSnapshots),
        opportunities = copyArray(source.opportunities),
        eventHistory = copyArray(source.eventHistory),
        cooldowns = source.cooldowns or {},
    }
end

function Persistence.migrateState(data)
    local migrated = data or {}
    local version = migrated.schemaVersion or 0

    if version <= 0 then
        migrated.schemaVersion = Constants.SAVE_SCHEMA_VERSION
        migrated.modVersion = migrated.modVersion or Constants.VERSION
        migrated.seed = migrated.seed or Constants.DEFAULT_SEED
        migrated.periodId = migrated.periodId or Constants.DEFAULT_PERIOD_ID
        migrated.regionalPreset = migrated.regionalPreset or Constants.DEFAULT_REGIONAL_PRESET
        migrated.mapDiscovery = migrated.mapDiscovery or nil
        migrated.profiles = migrated.profiles or {}
        migrated.ledgerSnapshots = migrated.ledgerSnapshots or {}
        migrated.opportunities = migrated.opportunities or {}
        migrated.eventHistory = migrated.eventHistory or {}
        migrated.cooldowns = migrated.cooldowns or {}
    end

    return migrated
end

function Persistence.importState(data, options)
    options = options or {}

    if data == nil then
        return Persistence.createInitialState(options)
    end

    local migrated = Persistence.migrateState(data)
    local mapDiscovery = options.mapDiscovery or migrated.mapDiscovery
    if mapDiscovery == nil and MapDiscovery ~= nil and MapDiscovery.discover ~= nil then
        mapDiscovery = MapDiscovery.discover(options.discoveryOptions)
    end

    local profiles = {}

    if migrated.profiles == nil or #migrated.profiles == 0 then
        profiles = Profiles.generateProfiles({
            count = options.profileCount or Constants.DEFAULT_PROFILE_COUNT,
            seed = migrated.seed or Constants.DEFAULT_SEED,
            fieldsByProfile = options.fieldsByProfile,
            mapDiscovery = mapDiscovery,
        })
    else
        for index, profile in ipairs(migrated.profiles) do
            profiles[index] = Profiles.normalizeProfile(profile, index)
        end
    end

    local snapshots = {}
    local snapshotByFarmId = Ledgers.indexSnapshotsByFarmId(migrated.ledgerSnapshots)

    for index, profile in ipairs(profiles) do
        snapshots[index] = Ledgers.normalizeSnapshot(
            snapshotByFarmId[profile.farmId],
            profile,
            migrated.periodId or Constants.DEFAULT_PERIOD_ID
        )
    end

    return {
        schemaVersion = Constants.SAVE_SCHEMA_VERSION,
        modVersion = migrated.modVersion or Constants.VERSION,
        seed = migrated.seed or Constants.DEFAULT_SEED,
        periodId = migrated.periodId or Constants.DEFAULT_PERIOD_ID,
        regionalPreset = migrated.regionalPreset or Constants.DEFAULT_REGIONAL_PRESET,
        mapDiscovery = mapDiscovery,
        profiles = profiles,
        ledgerSnapshots = snapshots,
        opportunities = migrated.opportunities or {},
        eventHistory = migrated.eventHistory or {},
        cooldowns = migrated.cooldowns or {},
    }
end

function Persistence.getSaveRootKey()
    return Constants.SAVE_KEYS.ROOT
end
