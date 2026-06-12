PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Constants = PhobosRuralLedger.Constants or {}

local Constants = PhobosRuralLedger.Constants

Constants.MOD_NAME = "FS25_PhobosRuralLedger"
Constants.DISPLAY_NAME = "Phobos' Rural Ledger"
Constants.VERSION = "0.1.0.0"
Constants.SAVE_SCHEMA_VERSION = 1
Constants.DEFAULT_SEED = "phobos-rural-ledger"
Constants.DEFAULT_PROFILE_COUNT = 8
Constants.DEFAULT_PERIOD_ID = "season_0001"
Constants.DEFAULT_REGIONAL_PRESET = "temperate_mixed"

Constants.STRESS_STATES = {
    STABLE = "stable",
    WATCH = "watch",
    STRAINED = "strained",
    DISTRESSED = "distressed",
    INSOLVENT = "insolvent",
}

Constants.PROFILE_TYPES = {
    FAMILY_FARM = "family_farm",
    CONTRACTOR = "contractor",
    DAIRY_OPERATOR = "dairy_operator",
    GRAIN_GROWER = "grain_grower",
    STRUGGLING_BEGINNER = "struggling_beginner",
    WEALTHY_LANDHOLDER = "wealthy_landholder",
    LIVESTOCK_SPECIALIST = "livestock_specialist",
    REGENERATIVE_FARMER = "regenerative_farmer",
}

Constants.SAVE_KEYS = {
    ROOT = "phobosRuralLedger",
    SCHEMA_VERSION = "schemaVersion",
    MOD_VERSION = "modVersion",
    SEED = "seed",
    PERIOD_ID = "periodId",
    REGIONAL_PRESET = "regionalPreset",
    PROFILES = "profiles",
    LEDGER_SNAPSHOTS = "ledgerSnapshots",
    OPPORTUNITIES = "opportunities",
    EVENT_HISTORY = "eventHistory",
    COOLDOWNS = "cooldowns",
}
