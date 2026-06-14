PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Newspaper = PhobosRuralLedger.Newspaper or {}

local Newspaper = PhobosRuralLedger.Newspaper
local Constants = PhobosRuralLedger.Constants
local I18n = PhobosRuralLedger.I18n
local UiModels = PhobosRuralLedger.UiModels

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

local function trim(value, fallback)
    local stringValue = tostring(value or fallback or "")
    stringValue = string.gsub(stringValue, "^%s+", "")
    stringValue = string.gsub(stringValue, "%s+$", "")
    return stringValue
end

local function clampMinute(value)
    value = tonumber(value)
    if value == nil then
        return nil
    end

    value = math.floor(value)
    while value < 0 do
        value = value + 1440
    end

    return value % 1440
end

local function timeLabel(minute)
    minute = clampMinute(minute) or Constants.NEWSPAPER_DELIVERY_MINUTE
    return string.format("%02d:%02d", math.floor(minute / 60), minute % 60)
end

local function normalizeDayTime(dayTime)
    local raw = tonumber(dayTime)
    if raw == nil then
        return nil, "unavailable"
    end

    if raw > 1440 then
        return clampMinute(raw / 60000), "milliseconds"
    elseif raw > 24 then
        return clampMinute(raw), "minutes"
    end

    return clampMinute(raw * 60), "hours"
end

local function copySections(sections)
    local result = {}

    for _, section in ipairs(sections or {}) do
        result[#result + 1] = {
            title = trim(section.title, ""),
            body = trim(section.body, ""),
        }
    end

    return result
end

local function newestFirst(left, right)
    if (left.day or 0) ~= (right.day or 0) then
        return (left.day or 0) > (right.day or 0)
    end

    return tostring(left.editionId or "") > tostring(right.editionId or "")
end

function Newspaper.normalizeEdition(record)
    if record == nil then
        return nil
    end

    local day = tonumber(record.day)
    local editionId = trim(record.editionId, "")
    if editionId == "" and day ~= nil then
        editionId = string.format("daily_%04d", day)
    end

    if editionId == "" then
        return nil
    end

    return {
        editionId = editionId,
        day = day or 0,
        deliveryMinute = clampMinute(record.deliveryMinute) or Constants.NEWSPAPER_DELIVERY_MINUTE,
        dateline = trim(record.dateline, text("rl_newspaper_dateline_unknown", "Dateline unavailable")),
        masthead = trim(record.masthead, text("rl_newspaper_masthead", "THE RURAL LEDGER")),
        headline = trim(record.headline, text("rl_newspaper_headline_default", "Morning Ledger")),
        summary = trim(record.summary, ""),
        sections = copySections(record.sections),
    }
end

function Newspaper.createEmptyState(options)
    options = options or {}

    return Newspaper.normalizeState({
        lastDeliveredDay = options.lastDeliveredDay,
        lastCheckedDay = options.lastCheckedDay,
        lastCheckedMinute = options.lastCheckedMinute,
        pendingEditionId = options.pendingEditionId,
        diagnostics = options.diagnostics,
        editions = options.editions,
    })
end

function Newspaper.normalizeState(value)
    value = value or {}
    local result = {
        lastDeliveredDay = tonumber(value.lastDeliveredDay),
        lastCheckedDay = tonumber(value.lastCheckedDay),
        lastCheckedMinute = clampMinute(value.lastCheckedMinute),
        pendingEditionId = value.pendingEditionId ~= nil and tostring(value.pendingEditionId) or nil,
        diagnostics = {},
        editions = {},
    }

    for key, diagnosticValue in pairs(value.diagnostics or {}) do
        result.diagnostics[key] = diagnosticValue
    end

    for _, edition in ipairs(value.editions or {}) do
        local normalized = Newspaper.normalizeEdition(edition)
        if normalized ~= nil then
            result.editions[#result.editions + 1] = normalized
        end
    end

    table.sort(result.editions, newestFirst)

    while #result.editions > Constants.MAX_NEWSPAPER_EDITIONS do
        table.remove(result.editions)
    end

    if result.pendingEditionId ~= nil and Newspaper.getEditionById(result, result.pendingEditionId) == nil then
        result.pendingEditionId = nil
    end

    return result
end

function Newspaper.readClock(mission)
    local activeMission = mission or g_currentMission
    local environment = activeMission ~= nil and activeMission.environment or nil
    if environment == nil then
        return {
            available = false,
            reason = "environment_unavailable",
            source = "unavailable",
        }
    end

    local day = tonumber(environment.currentDay)
    local minute, unit = normalizeDayTime(environment.dayTime)
    if day == nil or minute == nil then
        return {
            available = false,
            reason = "clock_values_unavailable",
            source = unit or "unavailable",
            rawDay = environment.currentDay,
            rawDayTime = environment.dayTime,
        }
    end

    return {
        available = true,
        day = math.floor(day),
        minute = minute,
        timeLabel = timeLabel(minute),
        source = unit,
        rawDay = environment.currentDay,
        rawDayTime = environment.dayTime,
    }
end

function Newspaper.getEditionById(newspaperState, editionId)
    if editionId == nil then
        return nil
    end

    for _, edition in ipairs((newspaperState or {}).editions or {}) do
        if tostring(edition.editionId or "") == tostring(editionId) then
            return edition
        end
    end

    return nil
end

local function firstAlert(overview)
    for _, alert in ipairs((overview or {}).alerts or {}) do
        if alert ~= nil and alert ~= "" then
            return alert
        end
    end

    return text("rl_overview_empty_alert", "No public pressure alerts this period.")
end

local function countLaunchableJobs(state)
    local count = 0

    for _, job in ipairs((state or {}).jobRequests or {}) do
        if job.launchable == true then
            count = count + 1
        end
    end

    return count
end

local function communityNote(state)
    local historyCount = #((state or {}).eventHistory or {}) + #((state or {}).jobHistory or {})
    if historyCount > 0 then
        return text(
            "rl_newspaper_community_body_history",
            "The parish notes record %d recent Rural Ledger event(s), keeping the memory of local work alive.",
            historyCount
        )
    end

    return text(
        "rl_newspaper_community_body_quiet",
        "Community ledgers are quiet this morning, though the district is still watching field work and contracts closely."
    )
end

function Newspaper.generateEdition(state, clock, options)
    options = options or {}
    clock = clock or {}

    local deliveryMinute = clampMinute(options.deliveryMinute) or Constants.NEWSPAPER_DELIVERY_MINUTE
    local day = tonumber(clock.day) or 0
    local overview = UiModels ~= nil and UiModels.buildOverview ~= nil
        and UiModels.buildOverview(state, {maxAlerts = 3})
        or {}
    local farmRows = UiModels ~= nil and UiModels.buildFarmList ~= nil
        and UiModels.buildFarmList(state, {})
        or {}
    local jobs = (state or {}).jobRequests or {}
    local discovery = (state or {}).mapDiscovery or {}
    local strained = (overview.strainedOrWorseFarms or 0)
    local activeOpportunities = #((state or {}).opportunities or {})
    local launchableJobs = countLaunchableJobs(state)

    local headline = strained > 0
        and text(
            "rl_newspaper_headline_pressure",
            "%d Farms Face Morning Pressure",
            strained
        )
        or text("rl_newspaper_headline_steady", "Steady Morning Across the District")

    local topFarm = farmRows[1] or {}
    local dateline = text(
        "rl_newspaper_dateline_day_time",
        "Day %d, %s edition",
        day,
        timeLabel(deliveryMinute)
    )

    local sections = {
        {
            title = text("rl_newspaper_section_local_economy", "Local Economy"),
            body = text(
                "rl_newspaper_local_economy_body",
                "%s. Rural Ledger is tracking %d map-backed properties and %d discovered fields.",
                tostring(overview.localMarketMood or text("rl_mood_steady", "Steady")),
                overview.trackedFarms or #farmRows,
                (overview.discovery or {}).discoveredFields or discovery.discoveredFieldCount or 0
            ),
        },
        {
            title = text("rl_newspaper_section_farms_pressure", "Farms Under Pressure"),
            body = text(
                "rl_newspaper_farms_pressure_body",
                "%s The leading pressure today is %s.",
                firstAlert(overview),
                tostring(overview.dominantPressure or text("rl_pressure_none", "No dominant pressure"))
            ),
        },
        {
            title = text("rl_newspaper_section_jobs_contracts", "Jobs & Contracts"),
            body = text(
                "rl_newspaper_jobs_body",
                "%d job request(s) are on the board, with %d live contract(s) ready to start.",
                #jobs,
                launchableJobs
            ),
        },
        {
            title = text("rl_newspaper_section_public_opportunities", "Public Opportunities"),
            body = text(
                "rl_newspaper_opportunities_body",
                "%d public opportunity candidate(s) are visible for pressured farms. They remain informational for now.",
                activeOpportunities
            ),
        },
        {
            title = text("rl_newspaper_section_community_notes", "Community Notes"),
            body = text(
                "rl_newspaper_community_body",
                "%s %s remains the property drawing the closest attention this morning.",
                communityNote(state),
                tostring(topFarm.displayName or text("rl_detail_no_farm_title", "No farm selected"))
            ),
        },
    }

    return Newspaper.normalizeEdition({
        editionId = string.format("daily_%04d", day),
        day = day,
        deliveryMinute = deliveryMinute,
        dateline = dateline,
        masthead = text("rl_newspaper_masthead", "THE RURAL LEDGER"),
        headline = headline,
        summary = text(
            "rl_newspaper_summary",
            "%d farms tracked, %d opportunities, %d live contracts.",
            overview.trackedFarms or #farmRows,
            activeOpportunities,
            launchableJobs
        ),
        sections = sections,
    })
end

function Newspaper.addEdition(newspaperState, edition)
    local state = Newspaper.normalizeState(newspaperState)
    local normalized = Newspaper.normalizeEdition(edition)
    if normalized == nil then
        return state, nil
    end

    local replaced = false
    for index, existing in ipairs(state.editions) do
        if tostring(existing.editionId or "") == tostring(normalized.editionId or "") then
            state.editions[index] = normalized
            replaced = true
            break
        end
    end

    if not replaced then
        state.editions[#state.editions + 1] = normalized
    end

    table.sort(state.editions, newestFirst)
    while #state.editions > Constants.MAX_NEWSPAPER_EDITIONS do
        table.remove(state.editions)
    end

    return state, normalized
end

function Newspaper.deliverIfDue(state, options)
    options = options or {}
    state = state or {}
    state.newspaper = Newspaper.normalizeState(state.newspaper)

    local clock = options.clock or Newspaper.readClock(options.mission)
    local diagnostics = state.newspaper.diagnostics or {}
    diagnostics.clockAvailable = clock.available == true
    diagnostics.clockSource = clock.source or "unavailable"
    diagnostics.clockReason = clock.reason or "available"
    diagnostics.trigger = options.trigger or diagnostics.trigger or "unknown"
    diagnostics.deliveryMinute = Constants.NEWSPAPER_DELIVERY_MINUTE

    if clock.available ~= true then
        diagnostics.status = "clock_unavailable"
        state.newspaper.diagnostics = diagnostics
        return nil, "clock_unavailable", clock
    end

    local previousDay = state.newspaper.lastCheckedDay
    local previousMinute = state.newspaper.lastCheckedMinute
    local hasBaseline = previousDay ~= nil and previousMinute ~= nil
    local crossedSameDay = previousDay == clock.day
        and previousMinute < Constants.NEWSPAPER_DELIVERY_MINUTE
        and clock.minute >= Constants.NEWSPAPER_DELIVERY_MINUTE
    local crossedAfterDayJump = previousDay ~= nil
        and previousDay < clock.day
        and clock.minute >= Constants.NEWSPAPER_DELIVERY_MINUTE
    local crossedDelivery = hasBaseline and (crossedSameDay or crossedAfterDayJump)
    local dueToday = crossedDelivery
        and state.newspaper.lastDeliveredDay ~= clock.day

    diagnostics.lastCheckedDay = previousDay
    diagnostics.lastCheckedMinute = previousMinute
    diagnostics.currentDay = clock.day
    diagnostics.currentMinute = clock.minute
    diagnostics.hasBaseline = hasBaseline == true
    diagnostics.crossedDelivery = crossedDelivery == true

    state.newspaper.lastCheckedDay = clock.day
    state.newspaper.lastCheckedMinute = clock.minute
    state.newspaper.diagnostics = diagnostics

    if not hasBaseline then
        diagnostics.status = "baseline"
        return nil, "baseline", clock
    end

    if previousDay ~= nil and previousDay > clock.day then
        diagnostics.status = "clock_reset"
        return nil, "clock_reset", clock
    end

    if options.baselineOnly == true then
        diagnostics.status = "baseline"
        return nil, "baseline", clock
    end

    if not dueToday then
        diagnostics.status = "not_due"
        return nil, "not_due", clock
    end

    local edition = Newspaper.generateEdition(state, clock, options)
    state.newspaper, edition = Newspaper.addEdition(state.newspaper, edition)
    if edition ~= nil then
        state.newspaper.lastDeliveredDay = clock.day
        state.newspaper.pendingEditionId = edition.editionId
        diagnostics.status = "delivered"
        state.newspaper.diagnostics = diagnostics
        return edition, "delivered", clock
    end

    diagnostics.status = "generation_failed"
    return nil, "generation_failed", clock
end

function Newspaper.markPendingShown(state, editionId)
    if state == nil then
        return false
    end

    state.newspaper = Newspaper.normalizeState(state.newspaper)
    local pendingId = editionId or state.newspaper.pendingEditionId
    if pendingId == nil then
        return false
    end

    if tostring(state.newspaper.pendingEditionId or "") == tostring(pendingId or "") then
        state.newspaper.pendingEditionId = nil
        return true
    end

    return false
end

function Newspaper.getPendingEdition(state)
    local newspaper = Newspaper.normalizeState((state or {}).newspaper)
    return Newspaper.getEditionById(newspaper, newspaper.pendingEditionId)
end

function Newspaper.buildArchiveRows(state)
    local newspaper = Newspaper.normalizeState((state or {}).newspaper)
    local rows = {}

    for _, edition in ipairs(newspaper.editions or {}) do
        rows[#rows + 1] = {
            editionId = edition.editionId,
            day = edition.day,
            dateline = edition.dateline,
            headline = edition.headline,
            summary = edition.summary,
            deliveredText = text(
                "rl_newspaper_archive_row",
                "Day %d at %s",
                edition.day or 0,
                timeLabel(edition.deliveryMinute)
            ),
        }
    end

    return rows
end

function Newspaper.buildEditionModel(edition)
    local normalized = Newspaper.normalizeEdition(edition)
    if normalized == nil then
        return {
            title = text("rl_newspaper_dialog_title", "Rural Newspaper"),
            subtitle = text("rl_newspaper_archive_empty", "No editions have been delivered yet."),
            masthead = text("rl_newspaper_masthead", "THE RURAL LEDGER"),
            headline = text("rl_newspaper_archive_empty", "No editions have been delivered yet."),
            sections = {},
            rows = {},
        }
    end

    local rows = {}
    for _, section in ipairs(normalized.sections or {}) do
        rows[#rows + 1] = {
            title = section.title,
            body = section.body,
        }
    end

    return {
        editionId = normalized.editionId,
        day = normalized.day,
        title = text("rl_newspaper_dialog_title", "Rural Newspaper"),
        subtitle = normalized.dateline,
        masthead = normalized.masthead,
        headline = normalized.headline,
        summary = normalized.summary,
        sections = normalized.sections,
        rows = rows,
    }
end

function Newspaper.getDiagnostics(state)
    local newspaper = Newspaper.normalizeState((state or {}).newspaper)
    local diagnostics = newspaper.diagnostics or {}

    return {
        deliveryTime = timeLabel(Constants.NEWSPAPER_DELIVERY_MINUTE),
        lastDeliveredDay = newspaper.lastDeliveredDay ~= nil and tostring(newspaper.lastDeliveredDay) or "none",
        archiveCount = #newspaper.editions,
        pendingDelivery = newspaper.pendingEditionId ~= nil and newspaper.pendingEditionId or "none",
        clockSource = tostring(diagnostics.clockSource or "not checked"),
        clockAvailable = diagnostics.clockAvailable == true,
        trigger = tostring(diagnostics.trigger or "unknown"),
        status = tostring(diagnostics.status or "not checked"),
        hasBaseline = diagnostics.hasBaseline == true,
        lastCheckedDay = diagnostics.lastCheckedDay ~= nil and tostring(diagnostics.lastCheckedDay) or "unknown",
        lastCheckedMinute = diagnostics.lastCheckedMinute ~= nil and timeLabel(diagnostics.lastCheckedMinute) or "unknown",
        currentDay = diagnostics.currentDay ~= nil and tostring(diagnostics.currentDay) or "unknown",
        currentMinute = diagnostics.currentMinute ~= nil and timeLabel(diagnostics.currentMinute) or "unknown",
        crossedDelivery = diagnostics.crossedDelivery == true,
    }
end
