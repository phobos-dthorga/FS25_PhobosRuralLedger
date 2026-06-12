PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.UiModels = PhobosRuralLedger.UiModels or {}

local UiModels = PhobosRuralLedger.UiModels
local Constants = PhobosRuralLedger.Constants
local I18n = PhobosRuralLedger.I18n
local Ledgers = PhobosRuralLedger.Ledgers

local PRESSURE_LABELS = {
    none = {"rl_pressure_none", "No dominant pressure"},
    negative_cash = {"rl_pressure_negative_cash", "Cash is tight"},
    weak_margin = {"rl_pressure_weak_margin", "Season margin is weak"},
    debt_service = {"rl_pressure_debt_service", "Debt service is heavy"},
    storage_shortage = {"rl_pressure_storage_shortage", "Storage limits selling options"},
    machinery_cost = {"rl_pressure_machinery_cost", "Machinery costs are high"},
    low_diversity = {"rl_pressure_low_diversity", "Income is not diversified"},
}

local STRESS_LABELS = {
    stable = {"rl_stress_stable", "Stable"},
    watch = {"rl_stress_watch", "Watch"},
    strained = {"rl_stress_strained", "Strained"},
    distressed = {"rl_stress_distressed", "Distressed"},
    insolvent = {"rl_stress_insolvent", "Insolvent"},
}

local STRESS_RANK = {
    stable = 1,
    watch = 2,
    strained = 3,
    distressed = 4,
    insolvent = 5,
}

local RELATIONSHIP_LABELS = {
    [1] = {"rl_relationship_unknown", "Unknown"},
    [2] = {"rl_relationship_distant", "Distant"},
    [3] = {"rl_relationship_neutral", "Neutral"},
    [4] = {"rl_relationship_helpful", "Helpful"},
    [5] = {"rl_relationship_trusted", "Trusted"},
}

local PROFILE_LABELS = {
    family_farm = {"rl_profile_family_farm", "Small Family Farm"},
    contractor = {"rl_profile_contractor", "Contractor"},
    dairy_operator = {"rl_profile_dairy_operator", "Dairy Operator"},
    grain_grower = {"rl_profile_grain_grower", "Grain Grower"},
    struggling_beginner = {"rl_profile_struggling_beginner", "Struggling Beginner"},
    wealthy_landholder = {"rl_profile_wealthy_landholder", "Wealthy Landholder"},
    livestock_specialist = {"rl_profile_livestock_specialist", "Livestock Specialist"},
    regenerative_farmer = {"rl_profile_regenerative_farmer", "Regenerative Farmer"},
}

local function text(key, fallback, ...)
    if I18n ~= nil and I18n.get ~= nil then
        return I18n.get(key, fallback, ...)
    end

    if select("#", ...) > 0 then
        local ok, value = pcall(string.format, fallback or key, ...)
        if ok then
            return value
        end
    end

    return fallback or key
end

local function labelFrom(entry, unknownKey, unknownFallback)
    if entry ~= nil then
        return text(entry[1], entry[2])
    end

    return text(unknownKey, unknownFallback)
end

local function round(value)
    value = tonumber(value) or 0

    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

local function money(value)
    value = round(value)

    if value < 0 then
        return string.format("-$%d", math.abs(value))
    end

    return string.format("$%d", value)
end

local function percentage(part, whole)
    if whole == nil or whole == 0 then
        return 0
    end

    return (part or 0) / whole
end

local function pressureLabel(pressureType)
    return labelFrom(
        PRESSURE_LABELS[pressureType or Constants.PRESSURE_TYPES.NONE],
        "rl_pressure_mixed",
        "Mixed pressure"
    )
end

local function stressLabel(stressState)
    return labelFrom(
        STRESS_LABELS[stressState or Constants.STRESS_STATES.STABLE],
        "rl_stress_unknown",
        "Unknown"
    )
end

local function stressRank(stressState)
    return STRESS_RANK[stressState or Constants.STRESS_STATES.STABLE] or 0
end

local function relationshipBand(score)
    score = math.max(1, math.min(5, round(score or 3)))
    return labelFrom(RELATIONSHIP_LABELS[score], "rl_relationship_neutral", "Neutral")
end

local function countFields(profile)
    return #(profile.ownedFields or {}) + #(profile.leasedFields or {})
end

local function profileLabel(profile)
    return labelFrom(PROFILE_LABELS[(profile or {}).profileType], "rl_profile_unknown", profile.label or "Unknown Profile")
end

local function cashBand(snapshot)
    local ratio = percentage(snapshot.operatingCash, math.max(1, snapshot.grossRevenue or 1))

    if snapshot.operatingCash == nil then
        return text("rl_band_unknown", "Unknown")
    elseif snapshot.operatingCash < 0 then
        return text("rl_cash_negative", "Negative")
    elseif ratio < 0.08 then
        return text("rl_cash_tight", "Tight")
    elseif ratio < 0.18 then
        return text("rl_cash_adequate", "Adequate")
    end

    return text("rl_cash_strong", "Strong")
end

local function debtBand(snapshot)
    local ratio = percentage(snapshot.totalDebt, math.max(1, snapshot.grossRevenue or 1))

    if snapshot.totalDebt == nil then
        return text("rl_band_unknown", "Unknown")
    elseif ratio > 2.6 then
        return text("rl_debt_very_heavy", "Very heavy")
    elseif ratio > 1.8 then
        return text("rl_debt_heavy", "Heavy")
    elseif ratio > 0.9 then
        return text("rl_debt_moderate", "Moderate")
    end

    return text("rl_debt_light", "Light")
end

local function marginBand(snapshot)
    local ratio = percentage(snapshot.seasonProfit, math.max(1, snapshot.grossRevenue or 1))

    if snapshot.seasonProfit == nil then
        return text("rl_band_unknown", "Unknown")
    elseif ratio < -0.08 then
        return text("rl_margin_losing", "Losing money")
    elseif ratio < 0.04 then
        return text("rl_margin_thin", "Thin")
    elseif ratio < 0.16 then
        return text("rl_margin_workable", "Workable")
    end

    return text("rl_margin_healthy", "Healthy")
end

local function riskBufferBand(snapshot)
    local ratio = percentage(snapshot.riskBuffer, math.max(1, snapshot.grossRevenue or 1))

    if snapshot.riskBuffer == nil then
        return text("rl_band_unknown", "Unknown")
    elseif ratio < 0.08 then
        return text("rl_risk_low", "Low")
    elseif ratio < 0.18 then
        return text("rl_risk_moderate", "Moderate")
    end

    return text("rl_risk_good", "Good")
end

local function storageBand(profile)
    local rating = profile.storageRating or 3

    if rating <= 1 then
        return text("rl_storage_severe", "Severe limits")
    elseif rating <= 2 then
        return text("rl_storage_limited", "Limited")
    elseif rating == 3 then
        return text("rl_storage_adequate", "Adequate")
    end

    return text("rl_storage_flexible", "Flexible")
end

local function machineryBand(profile)
    local rating = profile.machineryRating or 3

    if rating <= 1 then
        return text("rl_machinery_fragile", "Fragile")
    elseif rating <= 2 then
        return text("rl_machinery_stretched", "Stretched")
    elseif rating == 3 then
        return text("rl_machinery_adequate", "Adequate")
    end

    return text("rl_machinery_strong", "Strong")
end

local function stateParts(state)
    local profiles = (state or {}).profiles or {}
    local snapshots = (state or {}).ledgerSnapshots or {}
    return profiles, snapshots, Ledgers.indexSnapshotsByFarmId(snapshots)
end

local function dominantPressure(snapshots)
    local counts = {}
    local bestType = Constants.PRESSURE_TYPES.NONE
    local bestCount = 0

    for _, snapshot in ipairs(snapshots or {}) do
        local pressureType = snapshot.primaryPressure or Constants.PRESSURE_TYPES.NONE
        if pressureType ~= Constants.PRESSURE_TYPES.NONE then
            counts[pressureType] = (counts[pressureType] or 0) + 1
            if counts[pressureType] > bestCount then
                bestType = pressureType
                bestCount = counts[pressureType]
            end
        end
    end

    return pressureLabel(bestType), bestCount
end

local function localMood(stressedCount, strainedCount, totalFarms)
    if totalFarms == 0 then
        return text("rl_mood_no_farms", "No tracked farms")
    end

    local strainedRatio = strainedCount / totalFarms
    local stressedRatio = stressedCount / totalFarms

    if strainedRatio >= 0.35 then
        return text("rl_mood_under_pressure", "Under pressure")
    elseif stressedRatio >= 0.5 then
        return text("rl_mood_cautious", "Cautious")
    elseif stressedCount > 0 then
        return text("rl_mood_mixed_watchful", "Mixed but watchful")
    end

    return text("rl_mood_steady", "Steady")
end

function UiModels.buildFarmList(state, options)
    options = options or {}

    local profiles, _, snapshotsByFarmId = stateParts(state)
    local rows = {}

    for _, profile in ipairs(profiles) do
        local snapshot = snapshotsByFarmId[profile.farmId] or {}
        local row = {
            farmId = profile.farmId,
            displayName = profile.displayName or profile.farmId or "Unknown Farm",
            profileLabel = profileLabel(profile),
            fields = countFields(profile),
            stressState = snapshot.stressState or Constants.STRESS_STATES.STABLE,
            stressLabel = stressLabel(snapshot.stressState),
            stressRank = stressRank(snapshot.stressState),
            primaryPressure = snapshot.primaryPressure or Constants.PRESSURE_TYPES.NONE,
            primaryPressureLabel = pressureLabel(snapshot.primaryPressure),
            cashBand = cashBand(snapshot),
            debtBand = debtBand(snapshot),
            marginBand = marginBand(snapshot),
            riskBufferBand = riskBufferBand(snapshot),
            relationshipBand = relationshipBand(profile.relationshipScore),
            activeOpportunityCount = 0,
            nextOpportunityHint = text("rl_no_public_request", "No public request"),
            lastNote = text("rl_farm_last_note", "%s / %s", marginBand(snapshot), pressureLabel(snapshot.primaryPressure)),
        }

        if options.includeDebug == true then
            row.debug = {
                operatingCash = snapshot.operatingCash or 0,
                totalDebt = snapshot.totalDebt or 0,
                seasonProfit = snapshot.seasonProfit or 0,
                stressScore = snapshot.stressScore or 0,
            }
        end

        rows[#rows + 1] = row
    end

    table.sort(rows, function(left, right)
        if left.stressRank ~= right.stressRank then
            return left.stressRank > right.stressRank
        end

        return left.displayName < right.displayName
    end)

    return rows
end

function UiModels.buildOverview(state, options)
    options = options or {}

    local profiles, snapshots = stateParts(state)
    local stressedCount = 0
    local strainedOrWorseCount = 0
    local stableCount = 0

    for _, snapshot in ipairs(snapshots) do
        local rank = stressRank(snapshot.stressState)
        if rank > STRESS_RANK.stable then
            stressedCount = stressedCount + 1
        else
            stableCount = stableCount + 1
        end

        if rank >= STRESS_RANK.strained then
            strainedOrWorseCount = strainedOrWorseCount + 1
        end
    end

    local dominantPressureLabel, dominantPressureCount = dominantPressure(snapshots)
    local farmRows = UiModels.buildFarmList(state, {includeDebug = options.includeDebug})
    local alerts = {}

    for _, row in ipairs(farmRows) do
        if #alerts >= (options.maxAlerts or 4) then
            break
        end

        if row.stressRank >= STRESS_RANK.watch then
            alerts[#alerts + 1] = string.format(
                "rl_overview_alert_row",
                "%s: %s, %s",
                row.displayName,
                row.stressLabel,
                row.primaryPressureLabel
            )
        end
    end

    if #alerts == 0 then
        alerts[1] = text("rl_overview_empty_alert", "No public pressure alerts this period.")
    end

    return {
        title = text("rl_ui_title", Constants.DISPLAY_NAME),
        period = (state or {}).periodId or Constants.DEFAULT_PERIOD_ID,
        regionalPreset = (state or {}).regionalPreset or Constants.DEFAULT_REGIONAL_PRESET,
        trackedFarms = #profiles,
        stableFarms = stableCount,
        stressedFarms = stressedCount,
        strainedOrWorseFarms = strainedOrWorseCount,
        activeOpportunities = #((state or {}).opportunities or {}),
        localMarketMood = localMood(stressedCount, strainedOrWorseCount, #profiles),
        dominantPressure = dominantPressureLabel,
        dominantPressureCount = dominantPressureCount,
        cards = {
            {label = text("rl_card_local_mood", "Local mood"), value = localMood(stressedCount, strainedOrWorseCount, #profiles)},
            {label = text("rl_card_tracked_farms", "Tracked farms"), value = tostring(#profiles)},
            {label = text("rl_card_farms_watching", "Farms watching"), value = tostring(stressedCount)},
            {label = text("rl_card_strained_or_worse", "Strained or worse"), value = tostring(strainedOrWorseCount)},
            {label = text("rl_card_main_pressure", "Main pressure"), value = dominantPressureLabel},
            {label = text("rl_card_active_requests", "Active requests"), value = tostring(#((state or {}).opportunities or {}))},
        },
        alerts = alerts,
        topFarms = farmRows,
    }
end

function UiModels.buildFarmDetail(state, farmId, options)
    options = options or {}

    local profiles, _, snapshotsByFarmId = stateParts(state)
    local selectedProfile = nil

    for _, profile in ipairs(profiles) do
        if selectedProfile == nil or profile.farmId == farmId then
            selectedProfile = profile
        end
    end

    if selectedProfile == nil then
        return {
            farmId = nil,
            displayName = text("rl_detail_no_farm_title", "No farm selected"),
            profileLabel = text("rl_stress_unknown", "Unknown"),
            status = {
                stressState = "unknown",
                stressLabel = text("rl_stress_unknown", "Unknown"),
                headline = text("rl_detail_no_farm_headline", "No farm selected."),
            },
            explanation = {
                mainCause = text("rl_detail_no_farm_cause", "No tracked farm is available."),
                supportingCauses = {},
                playerMeaning = text("rl_detail_no_farm_meaning", "No public action is available."),
            },
            ledgerEstimate = {},
            lines = {},
            opportunities = {},
            history = {},
        }
    end

    local snapshot = snapshotsByFarmId[selectedProfile.farmId] or {}
    local visibleLines = {
        text("rl_detail_line_profile", "Profile: %s", profileLabel(selectedProfile)),
        text("rl_detail_line_fields", "Fields controlled: %d", countFields(selectedProfile)),
        text("rl_detail_line_cash", "Cash position: %s", cashBand(snapshot)),
        text("rl_detail_line_debt", "Debt pressure: %s", debtBand(snapshot)),
        text("rl_detail_line_margin", "Margin trend: %s", marginBand(snapshot)),
        text("rl_detail_line_risk", "Risk buffer: %s", riskBufferBand(snapshot)),
        text("rl_detail_line_storage", "Storage pressure: %s", storageBand(selectedProfile)),
        text("rl_detail_line_machinery", "Machinery position: %s", machineryBand(selectedProfile)),
        text("rl_detail_line_relationship", "Relationship: %s", relationshipBand(selectedProfile.relationshipScore)),
    }

    if options.includeDebug == true then
        visibleLines[#visibleLines + 1] = text("rl_detail_line_debug_cash", "Debug cash: %s", money(snapshot.operatingCash))
        visibleLines[#visibleLines + 1] = text("rl_detail_line_debug_debt", "Debug debt: %s", money(snapshot.totalDebt))
        visibleLines[#visibleLines + 1] = text("rl_detail_line_debug_stress", "Debug stress score: %d", snapshot.stressScore or 0)
    end

    return {
        farmId = selectedProfile.farmId,
        displayName = selectedProfile.displayName or selectedProfile.farmId or "Unknown Farm",
        profileLabel = profileLabel(selectedProfile),
        status = {
            stressState = snapshot.stressState or Constants.STRESS_STATES.STABLE,
            stressLabel = stressLabel(snapshot.stressState),
            headline = text(
                "rl_detail_headline",
                "%s is %s.",
                selectedProfile.displayName or selectedProfile.farmId or "Unknown Farm",
                string.lower(stressLabel(snapshot.stressState))
            ),
        },
        explanation = {
            mainCause = pressureLabel(snapshot.primaryPressure),
            supportingCauses = {
                text("rl_detail_support_debt", "Debt pressure is %s", string.lower(debtBand(snapshot))),
                text("rl_detail_support_risk", "Risk buffer is %s", string.lower(riskBufferBand(snapshot))),
            },
            playerMeaning = text("rl_detail_player_meaning", "Public opportunities are not active in this slice."),
        },
        ledgerEstimate = {
            cash = cashBand(snapshot),
            revenue = marginBand(snapshot),
            costs = snapshot.directCosts ~= nil and text("rl_tracked", "Tracked") or text("rl_band_unknown", "Unknown"),
            debt = debtBand(snapshot),
            riskBuffer = riskBufferBand(snapshot),
        },
        lines = visibleLines,
        opportunities = {},
        history = {},
    }
end

function UiModels.buildDebugSummary(state, options)
    options = options or {}

    local profiles, snapshots = stateParts(state)
    local lines = {
        text("rl_debug_version", "Mod version: %s", Constants.VERSION),
        text("rl_debug_schema", "Schema version: %s", tostring((state or {}).schemaVersion or Constants.SAVE_SCHEMA_VERSION)),
        text("rl_debug_seed", "Seed: %s", tostring((state or {}).seed or Constants.DEFAULT_SEED)),
        text("rl_debug_period", "Period: %s", tostring((state or {}).periodId or Constants.DEFAULT_PERIOD_ID)),
        text("rl_debug_regional", "Regional preset: %s", tostring((state or {}).regionalPreset or Constants.DEFAULT_REGIONAL_PRESET)),
        text("rl_debug_profiles", "Profiles: %d", #profiles),
        text("rl_debug_snapshots", "Ledger snapshots: %d", #snapshots),
        text("rl_debug_opportunities", "Opportunities: %d", #((state or {}).opportunities or {})),
        text("rl_debug_events", "Events: %d", #((state or {}).eventHistory or {})),
        text("rl_debug_save_hooks", "Save/load hooks: not wired in this slice"),
    }

    if options.includeExactFarmValues == true and snapshots[1] ~= nil then
        lines[#lines + 1] = text("rl_debug_first_cash", "First farm cash: %s", money(snapshots[1].operatingCash))
        lines[#lines + 1] = text("rl_debug_first_debt", "First farm debt: %s", money(snapshots[1].totalDebt))
        lines[#lines + 1] = text("rl_debug_first_stress", "First farm stress score: %d", snapshots[1].stressScore or 0)
    end

    return {
        title = text("rl_tab_settings_debug", "Settings / Debug"),
        debugVisible = options.includeExactFarmValues == true,
        lines = lines,
    }
end

function UiModels.getPressureLabel(pressureType)
    return pressureLabel(pressureType)
end

function UiModels.getStressLabel(stressState)
    return stressLabel(stressState)
end
