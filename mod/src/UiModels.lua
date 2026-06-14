PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.UiModels = PhobosRuralLedger.UiModels or {}

local UiModels = PhobosRuralLedger.UiModels
local Constants = PhobosRuralLedger.Constants
local I18n = PhobosRuralLedger.I18n
local Ledgers = PhobosRuralLedger.Ledgers
local Opportunities = PhobosRuralLedger.Opportunities
local JobRequests = PhobosRuralLedger.JobRequests

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

local JOB_SOURCE_LABELS = {
    betterContracts = {"rl_job_source_better_contracts", "BetterContracts"},
    vanilla = {"rl_job_source_vanilla", "Vanilla contracts"},
    ruralLedger = {"rl_job_source_rural_ledger", "Rural Ledger"},
}

local JOB_STATUS_LABELS = {
    CREATED = {"rl_job_status_created", "Available"},
    RUNNING = {"rl_job_status_running", "Running"},
    FINISHED = {"rl_job_status_finished", "Finished"},
    NO_ACTIVE_JOB = {"rl_job_status_no_active_job", "No active job"},
}

local JOB_TYPE_LABELS = {
    harvest_support = {"rl_job_type_harvest_support", "Harvest support"},
    fieldwork_support = {"rl_job_type_fieldwork_support", "Fieldwork support"},
    transport_support = {"rl_job_type_transport_support", "Transport support"},
    cultivation_support = {"rl_job_type_cultivation_support", "Cultivation support"},
}

local JOB_BLOCKED_LABELS = {
    no_selection = {"rl_job_blocked_no_selection", "Select a launchable live contract first."},
    generated_only = {"rl_job_blocked_generated_only", "This is a Rural Ledger request, not a launchable live contract."},
    mission_not_created = {"rl_job_blocked_mission_not_created", "The linked contract is no longer available to start."},
    not_launchable = {"rl_job_blocked_not_launchable", "This job cannot be started from Rural Ledger."},
    monthly_job_limit = {"rl_job_blocked_monthly_limit", "BetterContracts monthly job limit has been reached."},
    mission_start_event_unavailable = {"rl_job_blocked_event_unavailable", "The FS25 contract start event is unavailable."},
    client_connection_unavailable = {"rl_job_blocked_connection_unavailable", "The server connection is unavailable."},
    server_connection_unavailable = {"rl_job_blocked_connection_unavailable", "The server connection is unavailable."},
    jobs_unavailable = {"rl_job_blocked_jobs_unavailable", "Job requests are not available yet."},
}

local REGIONAL_PRESET_LABELS = {
    temperate_mixed = {"rl_regional_temperate_mixed", "Temperate mixed"},
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

local function labelFromMap(map, key, unknownKey, unknownFallback)
    return labelFrom(map[key], unknownKey, unknownFallback or tostring(key or "Unknown"))
end

local function titleizeCode(value)
    local result = tostring(value or "")
    result = string.gsub(result, "_", " ")
    result = string.gsub(result, "(%l)(%u)", "%1 %2")
    result = string.gsub(result, "^%l", string.upper)
    return result
end

local function jobSourceLabel(source)
    return labelFromMap(JOB_SOURCE_LABELS, source or "ruralLedger", "rl_job_source_unknown", "Unknown source")
end

local function jobStatusLabel(status)
    return labelFromMap(JOB_STATUS_LABELS, status or "NO_ACTIVE_JOB", "rl_job_status_unknown", tostring(status or "Unknown"))
end

local function jobTypeLabel(contractType)
    local key = contractType or "fieldwork_support"
    local entry = JOB_TYPE_LABELS[key]
    if entry ~= nil then
        return text(entry[1], entry[2])
    end

    return titleizeCode(key)
end

local function jobTitleLabel(request)
    if (request or {}).generated == true then
        return text("rl_job_generated_title", "%s request", jobTypeLabel((request or {}).contractType))
    end

    return (request or {}).title or jobTypeLabel((request or {}).contractType)
end

local function jobBlockedReasonLabel(reason)
    return labelFromMap(JOB_BLOCKED_LABELS, reason or "not_launchable", "rl_job_blocked_not_launchable", "This job cannot be started from Rural Ledger.")
end

local function regionalPresetLabel(preset)
    local key = preset or Constants.DEFAULT_REGIONAL_PRESET
    local entry = REGIONAL_PRESET_LABELS[key]
    if entry ~= nil then
        return text(entry[1], entry[2])
    end

    return titleizeCode(key)
end

local function periodLabel(periodId)
    local number = string.match(tostring(periodId or ""), "^season_0*(%d+)$")
    if number ~= nil then
        return text("rl_period_season", "Season %d", tonumber(number) or 0)
    end

    return tostring(periodId or Constants.DEFAULT_PERIOD_ID)
end

local function relationshipEffectText(request)
    local success = (((request or {}).relationshipEffect or {}).success) or 1
    local failure = (((request or {}).relationshipEffect or {}).failure) or -1

    return text("rl_job_relationship_effect", "Success %+d, failure %+d", success, failure)
end

local function boolText(value)
    return value == true and text("rl_yes", "Yes") or text("rl_no", "No")
end

local function detailValue(value)
    if value == nil or value == "" then
        return nil
    end

    if type(value) == "boolean" then
        return boolText(value)
    end

    return tostring(value)
end

local function detailMoney(value)
    if value == nil or value == "" then
        return nil
    end

    local numeric = tonumber(value)
    if numeric ~= nil then
        return money(numeric)
    end

    return tostring(value)
end

local function detailArea(value)
    local numeric = tonumber(value)
    if numeric == nil then
        return detailValue(value)
    end

    return text("rl_job_area_ha", "%.2f ha", numeric)
end

local function detailDuration(value)
    if value == nil or value == "" then
        return nil
    end

    local numeric = tonumber(value)
    if numeric == nil then
        return tostring(value)
    end

    local minutes = numeric
    if numeric > 300 then
        minutes = numeric / 60
    end

    if minutes >= 60 then
        return text(
            "rl_job_time_hours_minutes",
            "%dh %02dm",
            math.floor(minutes / 60),
            math.floor(minutes % 60 + 0.5)
        )
    end

    return text("rl_job_time_minutes", "%d min", round(minutes))
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

local function opportunityTitle(opportunityType)
    local entry = OPPORTUNITY_LABELS[opportunityType] or OPPORTUNITY_LABELS.urgent_work
    return text(entry.title[1], entry.title[2])
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

local function historyViewsForFarm(state, farmId, profile)
    local views = {}

    if farmId == nil then
        return views
    end

    for _, record in ipairs((state or {}).eventHistory or {}) do
        if tostring(record.farmId or "") == tostring(farmId or "") then
            local periodId = record.periodId or Constants.DEFAULT_PERIOD_ID
            local actionText = nil
            if record.type == "expired" then
                actionText = text(
                    "rl_history_expired",
                    "Expired %s",
                    opportunityTitle(record.causeCode)
                )
            else
                actionText = text(
                    "rl_history_generated",
                    "Generated %s",
                    opportunityTitle(record.type)
                )
            end

            local cause = record.type == "expired"
                and text("rl_history_cooldown_applied", "Cooldown remains in effect where applicable.")
                or pressureLabel(record.causeCode)

            views[#views + 1] = {
                eventId = record.eventId,
                periodId = periodId,
                farmId = record.farmId,
                type = record.type,
                causeCode = record.causeCode,
                actionText = actionText,
                causeText = cause,
                rowText = text(
                    "rl_history_row",
                    "%s: %s - %s",
                    periodId,
                    actionText,
                    cause
                ),
            }
        end
    end

    table.sort(views, function(left, right)
        if tostring(left.periodId) ~= tostring(right.periodId) then
            return tostring(left.periodId) > tostring(right.periodId)
        end

        return tostring(left.eventId or "") > tostring(right.eventId or "")
    end)

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
    local activeJobCount = ((state or {}).jobDiagnostics or {}).launchableRequests or 0
    local activeRequestCount = #((state or {}).opportunities or {}) + activeJobCount

    for _, row in ipairs(farmRows) do
        if #alerts >= (options.maxAlerts or 4) then
            break
        end

        if row.stressRank >= STRESS_RANK.watch then
            alerts[#alerts + 1] = text(
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
        periodLabel = periodLabel((state or {}).periodId or Constants.DEFAULT_PERIOD_ID),
        regionalPresetLabel = regionalPresetLabel((state or {}).regionalPreset or Constants.DEFAULT_REGIONAL_PRESET),
        trackedFarms = #profiles,
        stableFarms = stableCount,
        stressedFarms = stressedCount,
        strainedOrWorseFarms = strainedOrWorseCount,
        activeOpportunities = #((state or {}).opportunities or {}),
        activeJobs = activeJobCount,
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
            {label = text("rl_card_active_requests", "Active requests"), value = tostring(activeRequestCount)},
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
    local historyViews = historyViewsForFarm(state, selectedProfile.farmId, selectedProfile)
    local jobViews = JobRequests ~= nil and JobRequests.getForFarm ~= nil
        and JobRequests.getForFarm(state, selectedProfile.farmId)
        or {}
    local visibleLines = {
        text("rl_detail_line_profile", "Profile: %s", profileLabel(selectedProfile)),
        text("rl_detail_line_source", "Source: %s", sourceConfidenceLabel(selectedProfile)),
        text("rl_detail_line_farmlands", "Farmlands: %s", joinList(selectedProfile.farmlandIds, text("rl_band_unknown", "Unknown"), 12)),
        text("rl_detail_line_field_ids", "Field IDs: %s", joinList(selectedProfile.fieldIds or selectedProfile.ownedFields, text("rl_band_unknown", "Unknown"), 12)),
        text("rl_detail_line_crop_mix", "Crop mix: %s", selectedProfile.cropSummary or text("rl_band_unknown", "Unknown")),
        text("rl_detail_line_field_condition", "Field condition: %s", fieldConditionSummary(selectedProfile)),
        text("rl_detail_line_precision", "Precision Farming: %s", precisionFarmingSummary(selectedProfile)),
        text("rl_detail_line_active_opportunities", "Active opportunities: %d", #opportunityViews),
        text("rl_detail_line_active_jobs", "Linked jobs: %d", #jobViews),
        text("rl_detail_line_history_events", "History events: %d", #historyViews),
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
            playerMeaning = #jobViews > 0
                and text("rl_detail_player_meaning_jobs", "%d job request(s) are visible in the Jobs tab.", #jobViews)
                or (#opportunityViews > 0
                    and text("rl_detail_player_meaning_opportunities", "%d read-only public opportunity candidate(s) are visible.", #opportunityViews)
                    or text("rl_detail_player_meaning_none", "No public opportunities are active for this property.")),
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
        jobs = jobViews,
        history = historyViews,
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

function UiModels.buildHistory(state, farmId, options)
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
            title = text("rl_history_dialog_title", "Property History"),
            subtitle = text("rl_detail_no_farm_title", "No farm selected"),
            rows = {
                text("rl_history_no_selection", "Select a farm with saved history first."),
            },
            history = {},
        }
    end

    local views = historyViewsForFarm(state, selectedProfile.farmId, selectedProfile)
    local rows = {}

    if #views == 0 then
        rows[1] = text("rl_history_none_for_farm", "No saved Rural Ledger events are recorded for this property.")
    else
        for _, view in ipairs(views) do
            rows[#rows + 1] = view.rowText
        end
    end

    return {
        farmId = selectedProfile.farmId,
        displayName = selectedProfile.displayName or selectedProfile.farmId,
        title = text("rl_history_dialog_title", "Property History"),
        subtitle = text(
            "rl_history_dialog_subtitle",
            "%s: %d event(s)",
            selectedProfile.displayName or selectedProfile.farmId,
            #views
        ),
        rows = rows,
        history = views,
    }
end

local function findProfileByFarmId(state, farmId)
    for _, profile in ipairs((state or {}).profiles or {}) do
        if tostring(profile.farmId or "") == tostring(farmId or "") then
            return profile
        end
    end

    return nil
end

local function plotLabel(request)
    local fieldId = (request or {}).fieldId
    local farmlandId = (request or {}).farmlandId

    if fieldId ~= nil and farmlandId ~= nil then
        return text("rl_job_plot_field_farmland", "Field %s / Farmland %s", tostring(fieldId), tostring(farmlandId))
    elseif fieldId ~= nil then
        return text("rl_job_plot_field", "Field %s", tostring(fieldId))
    elseif farmlandId ~= nil then
        return text("rl_job_plot_farmland", "Farmland %s", tostring(farmlandId))
    end

    return text("rl_job_plot_unknown", "Unknown plot")
end

local function requestRows(state)
    local rows = {}
    for _, request in ipairs((state or {}).jobRequests or {}) do
        local profile = findProfileByFarmId(state, request.farmId)
        rows[#rows + 1] = {
            requestId = request.requestId,
            farmId = request.farmId,
            npcName = request.npcName or (profile or {}).npcName or (profile or {}).ownerName or "-",
            farmName = request.farmName or (profile or {}).displayName or request.farmId or "-",
            plotLabel = plotLabel(request),
            jobTitle = jobTitleLabel(request),
            rewardText = request.rewardText or "-",
            status = request.status,
            statusLabel = jobStatusLabel(request.status),
            source = request.source,
            sourceLabel = jobSourceLabel(request.source),
            relationshipLabel = relationshipBand((profile or {}).relationshipScore),
            launchable = request.launchable == true,
            blockedReason = request.blockedReason,
            blockedReasonLabel = jobBlockedReasonLabel(request.blockedReason),
        }
    end

    return rows
end

function UiModels.buildJobList(state, options)
    options = options or {}
    local mode = options.mode or "npc"
    local rows = requestRows(state)

    table.sort(rows, function(left, right)
        if mode == "plot" then
            if tostring(left.plotLabel) ~= tostring(right.plotLabel) then
                return tostring(left.plotLabel) < tostring(right.plotLabel)
            end
        elseif tostring(left.npcName) ~= tostring(right.npcName) then
            return tostring(left.npcName) < tostring(right.npcName)
        end

        if (left.launchable == true) ~= (right.launchable == true) then
            return left.launchable == true
        end

        return tostring(left.requestId) < tostring(right.requestId)
    end)

    return rows
end

function UiModels.buildJobDetail(state, requestId, options)
    options = options or {}

    local request = nil
    if JobRequests ~= nil and JobRequests.getById ~= nil then
        request = JobRequests.getById(state, requestId)
    else
        for _, record in ipairs((state or {}).jobRequests or {}) do
            if tostring(record.requestId or "") == tostring(requestId or "") then
                request = record
                break
            end
        end
    end

    if request == nil then
        return {
            requestId = nil,
            farmId = nil,
            title = text("rl_job_detail_dialog_title", "Job Detail"),
            subtitle = text("rl_job_no_selection", "Select a job first."),
            rows = {
                text("rl_job_no_selection", "Select a job first."),
            },
            launchable = false,
            blockedReason = "no_selection",
            blockedReasonLabel = jobBlockedReasonLabel("no_selection"),
        }
    end

    local profile = findProfileByFarmId(state, request.farmId) or {}
    local canStart = false
    local blockedReason = request.blockedReason or "not_launchable"
    if JobRequests ~= nil and JobRequests.canStartContract ~= nil then
        canStart, blockedReason = JobRequests.canStartContract(state, request.requestId)
    else
        canStart = request.launchable == true
        blockedReason = canStart and "ready" or blockedReason
    end

    local details = request.details or {}
    local rows = {
        text("rl_job_detail_npc", "NPC: %s", tostring(request.npcName or profile.npcName or profile.ownerName or "-")),
        text("rl_job_detail_property", "Property: %s", tostring(request.farmName or profile.displayName or request.farmId or "-")),
        text("rl_job_detail_plot", "Plot: %s", plotLabel(request)),
        text("rl_job_detail_source", "Source: %s", jobSourceLabel(request.source)),
        text("rl_job_detail_type", "Type: %s", jobTypeLabel(request.contractType)),
        text("rl_job_detail_reward", "Reward: %s", tostring(request.rewardText or "-")),
        text("rl_job_detail_field_area", "Estimated field area: %s", detailArea(details.fieldArea) or "-"),
        text("rl_job_detail_status", "Status: %s", jobStatusLabel(request.status)),
        text("rl_job_detail_relationship", "Relationship: %s", relationshipBand(profile.relationshipScore)),
        text("rl_job_detail_effect", "Relationship effect: %s", relationshipEffectText(request)),
    }

    if request.generated == true then
        rows[#rows + 1] = text("rl_job_detail_generated_note", "Informational Rural Ledger request; no live contract can be started.")
    end

    local profit = detailMoney(details.profit)
    if profit ~= nil then
        rows[#rows + 1] = text("rl_job_detail_profit", "Estimated profit: %s", profit)
    end

    local workTime = detailDuration(details.workTime)
    if workTime ~= nil then
        rows[#rows + 1] = text("rl_job_detail_work_time", "Estimated work time: %s", workTime)
    end

    local profitPerMinute = detailMoney(details.profitPerMinute)
    if profitPerMinute ~= nil then
        rows[#rows + 1] = text("rl_job_detail_profit_per_minute", "Profit per minute: %s", profitPerMinute)
    end

    local usageCost = detailMoney(details.usageCost)
    if usageCost ~= nil then
        rows[#rows + 1] = text("rl_job_detail_usage_cost", "Usage cost: %s", usageCost)
    end

    local leaseCost = detailMoney(details.leaseCost)
    if leaseCost ~= nil then
        rows[#rows + 1] = text("rl_job_detail_lease_cost", "Lease cost: %s", leaseCost)
    end

    local deliveryHint = detailValue(details.deliveryHint)
    if deliveryHint ~= nil then
        rows[#rows + 1] = text("rl_job_detail_delivery", "Delivery: %s", deliveryHint)
    end

    local keepHint = detailValue(details.keepHint)
    if keepHint ~= nil then
        rows[#rows + 1] = text("rl_job_detail_keep", "Keep product: %s", keepHint)
    end

    if JobRequests ~= nil and JobRequests.getMonthlyJobLimitInfo ~= nil then
        local limit = JobRequests.getMonthlyJobLimitInfo()
        if (limit or {}).available == true then
            rows[#rows + 1] = text(
                "rl_job_detail_monthly_jobs",
                "BetterContracts monthly jobs left: %s / %s",
                tostring(limit.jobsLeft or "-"),
                tostring(limit.hardLimit or "-")
            )
        end
    end

    if canStart then
        rows[#rows + 1] = text("rl_job_detail_launch_ready", "Start Contract is available from the footer.")
    else
        rows[#rows + 1] = text("rl_job_detail_launch_blocked", "Start Contract unavailable: %s", jobBlockedReasonLabel(blockedReason))
    end

    if options.includeDebug == true then
        rows[#rows + 1] = text("rl_job_detail_debug_request", "Debug request ID: %s", tostring(request.requestId))
        rows[#rows + 1] = text("rl_job_detail_debug_mission", "Debug mission ID: %s", tostring(request.missionId or "none"))
    end

    return {
        requestId = request.requestId,
        farmId = request.farmId,
        title = text("rl_job_detail_dialog_title", "Job Detail"),
        subtitle = text(
            "rl_job_detail_dialog_subtitle",
            "%s - %s",
            tostring(request.npcName or profile.displayName or "-"),
            tostring(jobTitleLabel(request))
        ),
        rows = rows,
        request = request,
        launchable = canStart == true,
        blockedReason = blockedReason,
        blockedReasonLabel = jobBlockedReasonLabel(blockedReason),
    }
end

function UiModels.buildNewspaperArchive(state, options)
    options = options or {}

    local newspaper = PhobosRuralLedger.Newspaper
    local rows = newspaper ~= nil and newspaper.buildArchiveRows ~= nil
        and newspaper.buildArchiveRows(state)
        or {}

    if #rows == 0 then
        return {
            title = text("rl_newspaper_title", "Local Newspaper"),
            subtitle = text("rl_newspaper_subtitle", "Recent editions delivered at 06:00."),
            emptyText = text("rl_newspaper_archive_empty", "No editions have been delivered yet."),
            rows = {},
        }
    end

    return {
        title = text("rl_newspaper_title", "Local Newspaper"),
        subtitle = text("rl_newspaper_subtitle", "Recent editions delivered at 06:00."),
        emptyText = "",
        rows = rows,
    }
end

function UiModels.buildNewspaperEdition(state, editionId, options)
    options = options or {}

    local newspaper = PhobosRuralLedger.Newspaper
    if newspaper == nil or newspaper.buildEditionModel == nil then
        return {
            editionId = nil,
            title = text("rl_newspaper_dialog_title", "Rural Newspaper"),
            subtitle = text("rl_newspaper_archive_empty", "No editions have been delivered yet."),
            masthead = text("rl_newspaper_masthead", "THE RURAL LEDGER"),
            headline = text("rl_newspaper_archive_empty", "No editions have been delivered yet."),
            rows = {},
        }
    end

    local newspaperState = newspaper.normalizeState((state or {}).newspaper)
    local edition = newspaper.getEditionById(newspaperState, editionId)
    return newspaper.buildEditionModel(edition)
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
    local jobDiagnostics = JobRequests ~= nil and JobRequests.getDiagnostics ~= nil
        and JobRequests.getDiagnostics(state)
        or ((state or {}).jobDiagnostics or {})
    local newspaper = PhobosRuralLedger.Newspaper
    local newspaperDiagnostics = newspaper ~= nil and newspaper.getDiagnostics ~= nil
        and newspaper.getDiagnostics(state)
        or {}

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
        text("rl_debug_jobs_total", "Jobs: %d total, %d launchable", jobDiagnostics.totalRequests or 0, jobDiagnostics.launchableRequests or 0),
        text("rl_debug_jobs_sources", "Job sources: BetterContracts %d, vanilla %d, generated %d", jobDiagnostics.betterContractsRequests or 0, jobDiagnostics.vanillaRequests or 0, jobDiagnostics.generatedRequests or 0),
        text("rl_debug_jobs_launch", "Job launch: %s, attempts %d, reason %s", tostring(jobDiagnostics.lastLaunchStatus or "not attempted"), jobDiagnostics.launchAttempts or 0, tostring(jobDiagnostics.lastLaunchReason or "none")),
        text("rl_debug_jobs_outcome_hook", "Job outcome hook: %s", tostring(jobDiagnostics.outcomeHookStatus or "not attempted")),
        text("rl_debug_jobs_relationships", "Relationship records: %d, job history: %d", jobDiagnostics.relationshipRecordCount or 0, jobDiagnostics.historyCount or 0),
        text("rl_debug_newspaper_delivery", "Newspaper delivery: %s", tostring(newspaperDiagnostics.deliveryTime or "06:00")),
        text("rl_debug_newspaper_last_day", "Newspaper last delivered day: %s", tostring(newspaperDiagnostics.lastDeliveredDay or "none")),
        text("rl_debug_newspaper_archive", "Newspaper archive: %d edition(s)", newspaperDiagnostics.archiveCount or 0),
        text("rl_debug_newspaper_pending", "Newspaper pending delivery: %s", tostring(newspaperDiagnostics.pendingDelivery or "none")),
        text("rl_debug_newspaper_clock", "Newspaper clock: %s, current %s/%s", tostring(newspaperDiagnostics.clockSource or "not checked"), tostring(newspaperDiagnostics.currentDay or "unknown"), tostring(newspaperDiagnostics.currentMinute or "unknown")),
        text("rl_debug_newspaper_gate", "Newspaper gate: %s via %s, baseline %s, previous %s/%s, crossed %s", tostring(newspaperDiagnostics.status or "not checked"), tostring(newspaperDiagnostics.trigger or "unknown"), newspaperDiagnostics.hasBaseline == true and "yes" or "no", tostring(newspaperDiagnostics.lastCheckedDay or "unknown"), tostring(newspaperDiagnostics.lastCheckedMinute or "unknown"), newspaperDiagnostics.crossedDelivery == true and "yes" or "no"),
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
        text("rl_debug_save_last_load_counts", "Last load counts: %d opportunities, %d events, %d cooldowns, %d jobs, %d relationships, %d papers", (saveDiagnostics.lastLoadCounts or {}).opportunities or 0, (saveDiagnostics.lastLoadCounts or {}).events or 0, (saveDiagnostics.lastLoadCounts or {}).cooldowns or 0, (saveDiagnostics.lastLoadCounts or {}).jobHistory or 0, (saveDiagnostics.lastLoadCounts or {}).relationships or 0, (saveDiagnostics.lastLoadCounts or {}).newspaperEditions or 0),
        text("rl_debug_save_last_save_counts", "Last save counts: %d opportunities, %d events, %d cooldowns, %d jobs, %d relationships, %d papers", (saveDiagnostics.lastSaveCounts or {}).opportunities or 0, (saveDiagnostics.lastSaveCounts or {}).events or 0, (saveDiagnostics.lastSaveCounts or {}).cooldowns or 0, (saveDiagnostics.lastSaveCounts or {}).jobHistory or 0, (saveDiagnostics.lastSaveCounts or {}).relationships or 0, (saveDiagnostics.lastSaveCounts or {}).newspaperEditions or 0),
        text("rl_debug_loaded_period", "Loaded opportunity period: %s", tostring((state or {}).loadedOpportunityPeriodId or "none")),
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
