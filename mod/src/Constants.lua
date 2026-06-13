PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Constants = PhobosRuralLedger.Constants or {}

local Constants = PhobosRuralLedger.Constants

Constants.MOD_NAME = "FS25_PhobosRuralLedger"
Constants.DISPLAY_NAME = "Phobos' Rural Ledger"
Constants.VERSION = "0.1.5.7"
Constants.SAVE_SCHEMA_VERSION = 1
Constants.DEFAULT_SEED = "phobos-rural-ledger"
Constants.DEFAULT_PROFILE_COUNT = 8
Constants.DEFAULT_PERIOD_ID = "season_0001"
Constants.DEFAULT_REGIONAL_PRESET = "temperate_mixed"
Constants.DEFAULT_LOG_REPORT_FARM_LINES = 4
Constants.SCREEN_NAME = "PhobosRuralLedgerScreen"
Constants.FARM_DETAIL_DIALOG_NAME = "PhobosRuralLedgerFarmDetailDialog"
Constants.ACTION_OPEN_MENU = "PHOBOS_RURAL_LEDGER_MENU"

Constants.STRESS_STATES = {
    STABLE = "stable",
    WATCH = "watch",
    STRAINED = "strained",
    DISTRESSED = "distressed",
    INSOLVENT = "insolvent",
}

Constants.STRESS_THRESHOLDS = {
    WATCH = 20,
    STRAINED = 40,
    DISTRESSED = 60,
    INSOLVENT = 82,
}

Constants.PRESSURE_TYPES = {
    NONE = "none",
    NEGATIVE_CASH = "negative_cash",
    WEAK_MARGIN = "weak_margin",
    DEBT_SERVICE = "debt_service",
    STORAGE_SHORTAGE = "storage_shortage",
    MACHINERY_COST = "machinery_cost",
    LOW_DIVERSITY = "low_diversity",
}

Constants.LEDGER_TUNING = {
    BASE_REVENUE_PER_FIELD = 24000,
    BASE_DIRECT_COST_PER_FIELD = 11800,
    BASE_FIXED_COST = 9500,
    FIXED_COST_PER_FIELD = 5200,
    MACHINERY_COST_STEP = 2600,
    BASE_DEBT_PER_FIELD = 36000,
    BASE_RISK_BUFFER_PER_FIELD = 7200,
    INTEREST_RATE = 0.08,
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
    MAP_DISCOVERY = "mapDiscovery",
    PROFILES = "profiles",
    LEDGER_SNAPSHOTS = "ledgerSnapshots",
    OPPORTUNITIES = "opportunities",
    EVENT_HISTORY = "eventHistory",
    COOLDOWNS = "cooldowns",
}
