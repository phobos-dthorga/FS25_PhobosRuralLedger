PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.UiModels = PhobosRuralLedger.UiModels or {}

local UiModels = PhobosRuralLedger.UiModels
local Constants = PhobosRuralLedger.Constants
local I18n = PhobosRuralLedger.I18n
local Ledgers = PhobosRuralLedger.Ledgers
local Opportunities = PhobosRuralLedger.Opportunities

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

local OPPORTUNITY_LABELS = {
    urgent_work = {
        title = {"rl_opportunity_title_urgent_work", "Urgent field work"},
        reason = {"rl_opportunity_reason_urgent_work", "%s has visible cash pressure."},
        action = {"rl_opportunity_action_read_only", "Read-only candidate; no player action is available yet."},
    },
    margin_support = {
        title = {"rl_opportunity_title_margin_support", "Margin support"},
        reason = {"rl_opportunity_reason_margin_support", "%s has a weak season margin."},
        action = {"rl_opportunity_action_read_only", "Read-only candidate; no player action is available yet."},
    },
    debt_relief = {
        title = {"rl_opportunity_title_debt_relief", "Debt service support"},
        reason = {"rl_opportunity_reason_debt_relief", "%s is carrying heavy debt service."},
        action = {"rl_opportunity_action_read_only", "Read-only candidate; no player action is available yet."},
    },
    transport_storage = {
        title = {"rl_opportunity_title_transport_storage", "Transport and storage help"},
        reason = {"rl_opportunity_reason_transport_storage", "%s has limited storage flexibility."},
        action = {"rl_opportunity_action_read_only", "Read-only candidate; no player action is available yet."},
    },
    machine_support = {
        title = {"rl_opportunity_title_machine_support", "Machine support"},
        reason = {"rl_opportunity_reason_machine_support", "%s has machinery pressure."},
        action = {"rl_opportunity_action_read_only", "Read-only candidate; no player action is available yet."},
    },
    rotation_advice = {
        title = {"rl_opportunity_title_rotation_advice", "Crop rotation advice"},
        reason = {"rl_opportunity_reason_rotation_advice", "%s has limited income diversity."},
        action = {"rl_opportunity_action_read_only", "Read-only candidate; no player action is available yet."},
    },
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

local SOURCE_LABELS = {
    map = {"rl_source_map", "Map"},
    fallback = {"rl_source_fallback", "Fallback"},
    none = {"rl_source_none", "No map source"},
}

local CONFIDENCE_LABELS = {
    high = {"rl_confidence_high", "High"},
    medium = {"rl_confidence_medium", "Medium"},
    low = {"rl_confidence_low", "Low"},
    fallback = {"rl_confidence_fallback", "Fallback"},
    unavailable = {"rl_confidence_unavailable", "Unavailable"},
}

local CONDITION_LABELS = {
    tracked = {"rl_condition_tracked", "Tracked"},
    weeds = {"rl_condition_weeds", "Weeds"},
    stones = {"rl_condition_stones", "Stones"},
    ploughing = {"rl_condition_ploughing", "Ploughing"},
    rolling = {"rl_condition_rolling", "Rolling"},
    watered = {"rl_condition_watered", "Watered"},
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

local function sourceLabel(source)
    return labelFrom(SOURCE_LABELS[source or "fallback"], "rl_source_fallback", "Fallback")
end

local function confidenceLabel(confidence)
    return labelFrom(CONFIDENCE_LABELS[confidence or "fallback"], "rl_confidence_fallback", "Fallback")
end

local function sourceConfidenceLabel(profile)
    return text(
        "rl_source_confidence_pair",
        "%s / %s",
        sourceLabel((profile or {}).source),
        confidenceLabel((profile or {}).discoveryConfidence)
    )
end

local function boolText(value)
    return value == true and text("rl_yes", "Yes") or text("rl_no", "No")
end

local function noDataNotice(state)
    local discovery = (state or {}).mapDiscovery or {}
    local visible = discovery.mapReadyAttempted == true
        and (
            discovery.source == nil
            or discovery.source == "none"
            or (discovery.discoveredFieldCount or 0) == 0
        )

    return {
        visible = visible,
        text = visible and text(
            "rl_no_map_data_notice",
            "No map data available yet. Save/load the game or press Refresh after the map finishes loading."
        ) or "",
    }
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

local function opportunitiesByFarm(state)
    local result = {}

    for _, record in ipairs((state or {}).opportunities or {}) do
        local opportunity = Opportunities ~= nil
            and Opportunities.normalizeOpportunity ~= nil
            and Opportunities.normalizeOpportunity(record)
            or record
        if opportunity ~= nil and opportunity.farmId ~= nil then
            local farmId = opportunity.farmId
            result[farmId] = result[farmId] or {}
            result[farmId][#result[farmId] + 1] = opportunity
        end
    end

    return result
end

local function opportunityTextEntry(opportunity)
    return OPPORTUNITY_LABELS[(opportunity or {}).type] or OPPORTUNITY_LABELS.urgent_work
end

local function buildOpportunityView(opportunity, profile)
    local entry = opportunityTextEntry(opportunity)
    local displayName = (profile or {}).displayName or (opportunity or {}).farmId or text("rl_detail_no_farm_title", "No farm selected")
    local severity = (opportunity or {}).severity or Constants.STRESS_STATES.STRAINED

    return {
        opportunityId = opportunity.opportunityId,
        farmId = opportunity.farmId,
        type = opportunity.type,
        causeCode = opportunity.causeCode,
        title = text(entry.title[1], entry.title[2]),
        reason = text(entry.reason[1], entry.reason[2], displayName),
        actionText = text(entry.action[1], entry.action[2]),
        expiresText = text("rl_opportunity_expires", "Visible until %s", tostring(opportunity.expiresPeriod or "-")),
        relationshipText = text("rl_opportunity_relationship_none", "No relationship effect in this read-only slice."),
        severity = severity,
        severityLabel = stressLabel(severity),
    }
end

local function opportunityViewsForFarm(state, farmId, profile)
    local records = {}

    if Opportunities ~= nil and Opportunities.getForFarm ~= nil then
        records = Opportunities.getForFarm(state, farmId)
    else
        for _, record in ipairs((state or {}).opportunities or {}) do
            if tostring(record.farmId) == tostring(farmId) then
                records[#records + 1] = record
            end
        end
    end

    local views = {}
    for _, opportunity in ipairs(records) do
        views[#views + 1] = buildOpportunityView(opportunity, profile)
    end

    return views
end

local function joinList(values, emptyText, maxItems)
    if values == nil or #values == 0 then
        return emptyText or text("rl_band_unknown", "Unknown")
    end

    local parts = {}
    local limit = math.min(#values, maxItems or #values)
    for index = 1, limit do
        local value = values[index]
        parts[index] = tostring(value)
    end

    local joined = table.concat(parts, ", ")
    if maxItems ~= nil and #values > maxItems then
        joined = joined .. text("rl_list_more", ", ... (+%d more)", #values - maxItems)
    end

    return joined
end

local function fieldConditionSummary(profile)
    local codes = (profile or {}).fieldConditionCodes or {}
    if #codes == 0 then
        return (profile or {}).fieldConditionSummary or text("rl_condition_tracked", "Tracked")
    end

    local parts = {}
    for _, code in ipairs(codes) do
        parts[#parts + 1] = labelFrom(CONDITION_LABELS[code], "rl_condition_tracked", tostring(code))
    end

    return table.concat(parts, ", ")
end

local function precisionFarmingSummary(profile)
    local status = (profile or {}).precisionFarmingStatus
    if status == "available_pending" then
        return text("rl_precision_available", "Available; exact values pending")
    end

    return text("rl_precision_not_available", "Not available")
end

local function discoverySummary(state)
    local discovery = (state or {}).mapDiscovery or {}
    local diagnostics = discovery.diagnostics or {}

    return {
        source = sourceLabel(discovery.source),
        confidence = confidenceLabel(discovery.confidence),
        sourceConfidence = text(
            "rl_source_confidence_pair",
            "%s / %s",
            sourceLabel(discovery.source),
            confidenceLabel(discovery.confidence)
        ),
        groupingMode = diagnostics.propertyGroupingMode or "none",
        discoveredProperties = discovery.discoveredPropertyCount or 0,
        discoveredFields = discovery.discoveredFieldCount or 0,
        discoveredFarmlands = discovery.discoveredFarmlandCount or 0,
        discoveredContracts = discovery.discoveredContractCount or 0,
        precisionFarming = discovery.precisionFarmingAvailable == true
            and text("rl_precision_available", "Available; exact values pending")
            or text("rl_precision_not_available", "Not available"),
    }
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
    local opportunities = opportunitiesByFarm(state)
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
            source = profile.source or "fallback",
            sourceLabel = sourceLabel(profile.source),
            discoveryConfidence = profile.discoveryConfidence or "fallback",
            discoveryConfidenceLabel = confidenceLabel(profile.discoveryConfidence),
            sourceConfidenceLabel = sourceConfidenceLabel(profile),
            fieldIdsText = joinList(profile.fieldIds or profile.ownedFields, text("rl_band_unknown", "Unknown"), 8),
            farmlandIdsText = joinList(profile.farmlandIds, text("rl_band_unknown", "Unknown"), 8),
            cropSummary = profile.cropSummary or text("rl_band_unknown", "Unknown"),
            fieldConditionSummary = fieldConditionSummary(profile),
            precisionFarmingSummary = precisionFarmingSummary(profile),
            activeOpportunityCount = #((opportunities[profile.farmId] or {})),
            nextOpportunityHint = opportunities[profile.farmId] ~= nil
                and text("rl_public_requests_available", "%d public request(s)", #(opportunities[profile.farmId] or {}))
                or text("rl_no_public_request", "No public request"),
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
    local discovery = discoverySummary(state)
    local notice = noDataNotice(state)
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
        discovery = discovery,
        noDataNotice = notice,
        cards = {
            {label = text("rl_card_local_mood", "Local mood"), value = localMood(stressedCount, strainedOrWorseCount, #profiles)},
            {label = text("rl_card_discovery_source", "Discovery source"), value = discovery.sourceConfidence},
            {label = text("rl_card_tracked_farms", "Tracked farms"), value = tostring(#profiles)},
            {label = text("rl_card_discovered_fields", "Discovered fields"), value = tostring(discovery.discoveredFields)},
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

    if farmId ~= nil then
        for _, profile in ipairs(profiles) do
            if profile.farmId == farmId then
                selectedProfile = profile
                break
            end
        end
    end

    if selectedProfile == nil and farmId ~= nil then
        for _, profile in ipairs(profiles) do
            if tostring(profile.farmId or "") == tostring(farmId or "") then
                selectedProfile = profile
                break
            end
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
    local opportunityViews = opportunityViewsForFarm(state, selectedProfile.farmId, selectedProfile)
    local visibleLines = {
        text("rl_detail_line_profile", "Profile: %s", profileLabel(selectedProfile)),
        text("rl_detail_line_source", "Source: %s", sourceConfidenceLabel(selectedProfile)),
        text("rl_detail_line_farmlands", "Farmlands: %s", joinList(selectedProfile.farmlandIds, text("rl_band_unknown", "Unknown"), 12)),
        text("rl_detail_line_field_ids", "Field IDs: %s", joinList(selectedProfile.fieldIds or selectedProfile.ownedFields, text("rl_band_unknown", "Unknown"), 12)),
        text("rl_detail_line_crop_mix", "Crop mix: %s", selectedProfile.cropSummary or text("rl_band_unknown", "Unknown")),
        text("rl_detail_line_field_condition", "Field condition: %s", fieldConditionSummary(selectedProfile)),
        text("rl_detail_line_precision", "Precision Farming: %s", precisionFarmingSummary(selectedProfile)),
        text("rl_detail_line_active_opportunities", "Active opportunities: %d", #opportunityViews),
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
                text("rl_detail_support_field_condition", "Field condition: %s", fieldConditionSummary(selectedProfile)),
            },
            playerMeaning = #opportunityViews > 0
                and text("rl_detail_player_meaning_opportunities", "%d read-only public opportunity candidate(s) are visible.", #opportunityViews)
                or text("rl_detail_player_meaning_none", "No public opportunities are active for this property."),
        },
        property = {
            source = selectedProfile.source or "fallback",
            discoveryConfidence = selectedProfile.discoveryConfidence or "fallback",
            farmlands = selectedProfile.farmlandIds or {},
            fields = selectedProfile.fieldIds or selectedProfile.ownedFields or {},
            cropSummary = selectedProfile.cropSummary or text("rl_band_unknown", "Unknown"),
            fieldCondition = fieldConditionSummary(selectedProfile),
            precisionFarming = precisionFarmingSummary(selectedProfile),
        },
        ledgerEstimate = {
            cash = cashBand(snapshot),
            revenue = marginBand(snapshot),
            costs = snapshot.directCosts ~= nil and text("rl_tracked", "Tracked") or text("rl_band_unknown", "Unknown"),
            debt = debtBand(snapshot),
            riskBuffer = riskBufferBand(snapshot),
        },
        lines = visibleLines,
        opportunities = opportunityViews,
        history = {},
    }
end

function UiModels.buildOpportunities(state, farmId, options)
    options = options or {}

    local profiles = (state or {}).profiles or {}
    local selectedProfile = nil
    for _, profile in ipairs(profiles) do
        if tostring(profile.farmId) == tostring(farmId) then
            selectedProfile = profile
            break
        end
    end

    if selectedProfile == nil then
        return {
            farmId = nil,
            title = text("rl_opportunity_dialog_title", "Public Opportunities"),
            subtitle = text("rl_detail_no_farm_title", "No farm selected"),
            rows = {
                text("rl_opportunity_no_selection", "Select a farm with public opportunities first."),
            },
            opportunities = {},
        }
    end

    local views = opportunityViewsForFarm(state, selectedProfile.farmId, selectedProfile)
    local rows = {}

    if #views == 0 then
        rows[1] = text("rl_opportunity_none_for_farm", "No public opportunities are active for this property.")
    else
        for _, view in ipairs(views) do
            rows[#rows + 1] = text(
                "rl_opportunity_row",
                "%s: %s %s",
                view.title,
                view.reason,
                view.expiresText
            )
            rows[#rows + 1] = view.actionText
            rows[#rows + 1] = view.relationshipText
        end
    end

    return {
        farmId = selectedProfile.farmId,
        displayName = selectedProfile.displayName or selectedProfile.farmId,
        title = text("rl_opportunity_dialog_title", "Public Opportunities"),
        subtitle = text(
            "rl_opportunity_dialog_subtitle",
            "%s: %d candidate(s)",
            selectedProfile.displayName or selectedProfile.farmId,
            #views
        ),
        rows = rows,
        opportunities = views,
    }
end

function UiModels.buildDebugSummary(state, options)
    options = options or {}

    local profiles, snapshots = stateParts(state)
    local discovery = (state or {}).mapDiscovery or {}
    local diagnostics = discovery.diagnostics or {}
    local saveDiagnostics = {}
    if PhobosRuralLedger.Savegame ~= nil and PhobosRuralLedger.Savegame.getDiagnostics ~= nil then
        saveDiagnostics = PhobosRuralLedger.Savegame.getDiagnostics(g_currentMission)
    end

    local notice = noDataNotice(state)
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
        text("rl_debug_discovery_source", "Discovery source: %s", sourceLabel(discovery.source)),
        text("rl_debug_discovery_confidence", "Discovery confidence: %s", confidenceLabel(discovery.confidence)),
        text("rl_debug_discovery_trigger", "Discovery trigger: %s", tostring(discovery.trigger or diagnostics.trigger or "unknown")),
        text("rl_debug_property_grouping", "Property grouping: %s", tostring(diagnostics.propertyGroupingMode or "none")),
        text("rl_debug_map_ready_attempted", "Map-ready discovery attempted: %s", boolText(discovery.mapReadyAttempted)),
        text("rl_debug_discovery_properties", "Discovered properties: %d", discovery.discoveredPropertyCount or 0),
        text("rl_debug_discovery_fields", "Discovered fields: %d", discovery.discoveredFieldCount or 0),
        text("rl_debug_discovery_farmlands", "Discovered farmlands: %d", discovery.discoveredFarmlandCount or 0),
        text("rl_debug_discovery_contracts", "Discovered contracts: %d", discovery.discoveredContractCount or 0),
        text("rl_debug_manager_fields", "Field manager: %s, raw fields: %d", boolText(diagnostics.fieldManagerAvailable), diagnostics.rawFieldCount or 0),
        text("rl_debug_manager_farmlands", "Farmland manager: %s, raw farmlands: %d", boolText(diagnostics.farmlandManagerAvailable), diagnostics.rawFarmlandCount or 0),
        text("rl_debug_manager_missions", "Mission manager: %s, raw missions: %d", boolText(diagnostics.missionManagerAvailable), diagnostics.rawMissionCount or 0),
        text("rl_debug_owner_buckets", "Owner buckets: %d, split buckets: %d", diagnostics.ownerBucketCount or 0, diagnostics.splitOwnerBucketCount or 0),
        text("rl_debug_largest_owner_bucket", "Largest owner bucket: %d fields, %d farmlands", diagnostics.largestOwnerFieldCount or 0, diagnostics.largestOwnerFarmlandCount or 0),
        text("rl_debug_usable_fields", "Usable fields: %d", diagnostics.usableFieldCount or discovery.discoveredFieldCount or 0),
        text("rl_debug_skipped_fields", "Skipped fields: %d", diagnostics.skippedFieldCount or 0),
        text("rl_debug_skipped_missions", "Skipped missions: %d", diagnostics.skippedMissionCount or 0),
        text("rl_debug_discovery_errors", "Discovery read errors: fields %d, missions %d", diagnostics.fieldErrorCount or 0, diagnostics.missionErrorCount or 0),
        text("rl_debug_first_skip_reason", "First skip reason: %s", tostring(diagnostics.firstSkippedFieldReason or diagnostics.firstSkippedMissionReason or diagnostics.discoveryError or "none")),
        text(
            "rl_debug_precision_farming",
            "Precision Farming: %s",
            discovery.precisionFarmingAvailable == true
                and text("rl_precision_available", "Available; exact values pending")
                or text("rl_precision_not_available", "Not available")
        ),
        text("rl_debug_save_hooks", "Save/load hooks: opportunity persistence wired"),
        text("rl_debug_save_hook_status", "Save hook: %s on %s, attempts %d", tostring(saveDiagnostics.hookStatus or "not attempted"), tostring(saveDiagnostics.hookTarget or "none"), saveDiagnostics.hookAttempts or 0),
        text("rl_debug_save_xml_adapter", "Save XML adapter: %s", tostring(saveDiagnostics.xmlAdapterSource or "unavailable")),
        text("rl_debug_save_availability", "Save availability: %s via %s", tostring(saveDiagnostics.availability or "unknown"), tostring(saveDiagnostics.pathSource or "none")),
        text("rl_debug_save_path", "Save path: %s", tostring(saveDiagnostics.path or "unavailable")),
        text("rl_debug_save_last_load", "Last opportunity load: %s", tostring(saveDiagnostics.lastLoad or "not attempted")),
        text("rl_debug_save_last_save", "Last opportunity save: %s", tostring(saveDiagnostics.lastSave or "not attempted")),
    }

    if options.includeExactFarmValues == true and snapshots[1] ~= nil then
        lines[#lines + 1] = text("rl_debug_first_cash", "First farm cash: %s", money(snapshots[1].operatingCash))
        lines[#lines + 1] = text("rl_debug_first_debt", "First farm debt: %s", money(snapshots[1].totalDebt))
        lines[#lines + 1] = text("rl_debug_first_stress", "First farm stress score: %d", snapshots[1].stressScore or 0)
    end

    return {
        title = text("rl_tab_settings_debug", "Settings / Debug"),
        debugVisible = options.includeExactFarmValues == true,
        noDataNotice = notice,
        lines = lines,
    }
end

function UiModels.getPressureLabel(pressureType)
    return pressureLabel(pressureType)
end

function UiModels.getStressLabel(stressState)
    return stressLabel(stressState)
end
