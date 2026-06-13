PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Opportunities = PhobosRuralLedger.Opportunities or {}

local Opportunities = PhobosRuralLedger.Opportunities
local Constants = PhobosRuralLedger.Constants
local Ledgers = PhobosRuralLedger.Ledgers

local STRESS_RANK = {
    stable = 1,
    watch = 2,
    strained = 3,
    distressed = 4,
    insolvent = 5,
}

local PRESSURE_TO_TYPE = {
    negative_cash = "urgent_work",
    weak_margin = "margin_support",
    debt_service = "debt_relief",
    storage_shortage = "transport_storage",
    machinery_cost = "machine_support",
    low_diversity = "rotation_advice",
}

local function sanitize(value)
    return string.gsub(string.lower(tostring(value or "unknown")), "[^%w_]+", "_")
end

local function periodParts(periodId)
    local text = tostring(periodId or Constants.DEFAULT_PERIOD_ID)
    local prefix, number = string.match(text, "^(.-)(%d+)$")

    if prefix ~= nil and number ~= nil then
        return prefix, tonumber(number), string.len(number)
    end

    return text .. "_", 0, 4
end

local function nextPeriod(periodId)
    local prefix, number, width = periodParts(periodId)
    return string.format("%s%0" .. tostring(width) .. "d", prefix, (number or 0) + 1)
end

local function periodCompare(left, right)
    local leftPrefix, leftNumber = periodParts(left)
    local rightPrefix, rightNumber = periodParts(right)

    if leftPrefix == rightPrefix then
        if leftNumber == rightNumber then
            return 0
        end

        return leftNumber < rightNumber and -1 or 1
    end

    left = tostring(left or "")
    right = tostring(right or "")
    if left == right then
        return 0
    end

    return left < right and -1 or 1
end

local function isExpired(record, currentPeriod)
    local expiresPeriod = (record or {}).expiresPeriod
    if expiresPeriod == nil or expiresPeriod == "" then
        return false
    end

    return periodCompare(expiresPeriod, currentPeriod) <= 0
end

local function cooldownActive(cooldowns, cooldownKey, periodId)
    local expiresPeriod = (cooldowns or {})[cooldownKey]
    if expiresPeriod == nil then
        return false
    end

    return periodCompare(expiresPeriod, periodId) >= 0
end

local function normalizeOpportunity(record)
    if type(record) ~= "table" then
        return nil
    end

    local farmId = record.farmId
    if farmId == nil or farmId == "" then
        return nil
    end

    local opportunityType = record.type or "urgent_work"
    local causeCode = record.causeCode or record.reason or Constants.PRESSURE_TYPES.NONE
    local sourcePeriod = record.sourcePeriod or Constants.DEFAULT_PERIOD_ID

    return {
        opportunityId = record.opportunityId
            or string.format(
                "opp_%s_%s_%s",
                sanitize(farmId),
                sanitize(sourcePeriod),
                sanitize(opportunityType)
            ),
        farmId = farmId,
        type = opportunityType,
        reason = record.reason or causeCode,
        causeCode = causeCode,
        sourcePeriod = sourcePeriod,
        expiresPeriod = record.expiresPeriod or nextPeriod(sourcePeriod),
        severity = record.severity or Constants.STRESS_STATES.STRAINED,
        cooldownKey = record.cooldownKey
            or string.format("%s:%s:%s", tostring(farmId), tostring(opportunityType), tostring(causeCode)),
        playerVisible = record.playerVisible ~= false,
    }
end

local function normalizeHistory(record)
    if type(record) ~= "table" then
        return nil
    end

    return {
        eventId = record.eventId or string.format("event_%s_%s", sanitize(record.farmId), sanitize(record.periodId)),
        periodId = record.periodId or Constants.DEFAULT_PERIOD_ID,
        farmId = record.farmId,
        type = record.type,
        causeCode = record.causeCode or record.reason,
        message = record.message,
        modVersion = record.modVersion or Constants.VERSION,
    }
end

local function profileByFarmId(profiles)
    local result = {}

    for _, profile in ipairs(profiles or {}) do
        if profile.farmId ~= nil then
            result[profile.farmId] = profile
        end
    end

    return result
end

local function opportunitySortKey(snapshot, profilesByFarmId)
    local profile = profilesByFarmId[snapshot.farmId] or {}
    return tostring(profile.displayName or snapshot.farmId or "")
end

local function eligibleSnapshots(state)
    local profilesByFarmId = profileByFarmId((state or {}).profiles)
    local snapshots = {}

    for _, snapshot in ipairs((state or {}).ledgerSnapshots or {}) do
        local rank = STRESS_RANK[snapshot.stressState or Constants.STRESS_STATES.STABLE] or 0
        if rank >= STRESS_RANK.strained then
            snapshots[#snapshots + 1] = snapshot
        end
    end

    table.sort(snapshots, function(left, right)
        local leftRank = STRESS_RANK[left.stressState or Constants.STRESS_STATES.STABLE] or 0
        local rightRank = STRESS_RANK[right.stressState or Constants.STRESS_STATES.STABLE] or 0
        if leftRank ~= rightRank then
            return leftRank > rightRank
        end

        if (left.stressScore or 0) ~= (right.stressScore or 0) then
            return (left.stressScore or 0) > (right.stressScore or 0)
        end

        return opportunitySortKey(left, profilesByFarmId) < opportunitySortKey(right, profilesByFarmId)
    end)

    return snapshots, profilesByFarmId
end

local function createOpportunity(snapshot, profile, periodId)
    local pressureType = snapshot.primaryPressure or Constants.PRESSURE_TYPES.NONE
    local opportunityType = PRESSURE_TO_TYPE[pressureType] or "urgent_work"
    local farmId = snapshot.farmId or (profile or {}).farmId
    local expiresPeriod = nextPeriod(periodId)
    local cooldownKey = string.format("%s:%s:%s", tostring(farmId), opportunityType, pressureType)

    return normalizeOpportunity({
        opportunityId = string.format(
            "opp_%s_%s_%s",
            sanitize(farmId),
            sanitize(periodId),
            sanitize(opportunityType)
        ),
        farmId = farmId,
        type = opportunityType,
        reason = pressureType,
        causeCode = pressureType,
        sourcePeriod = periodId,
        expiresPeriod = expiresPeriod,
        severity = snapshot.stressState or Constants.STRESS_STATES.STRAINED,
        cooldownKey = cooldownKey,
        playerVisible = true,
    })
end

local function addHistory(state, opportunity)
    state.eventHistory = state.eventHistory or {}

    state.eventHistory[#state.eventHistory + 1] = normalizeHistory({
        eventId = string.format("event_%s", tostring(opportunity.opportunityId)),
        periodId = opportunity.sourcePeriod,
        farmId = opportunity.farmId,
        type = opportunity.type,
        causeCode = opportunity.causeCode,
        message = string.format(
            "Generated read-only opportunity %s for %s.",
            tostring(opportunity.type),
            tostring(opportunity.farmId)
        ),
    })

    while #state.eventHistory > Constants.MAX_EVENT_HISTORY do
        table.remove(state.eventHistory, 1)
    end
end

local function addExpiredHistory(state, opportunity, periodId)
    state.eventHistory = state.eventHistory or {}

    state.eventHistory[#state.eventHistory + 1] = normalizeHistory({
        eventId = string.format("event_expired_%s_%s", sanitize(opportunity.opportunityId), sanitize(periodId)),
        periodId = periodId,
        farmId = opportunity.farmId,
        type = "expired",
        causeCode = opportunity.type or opportunity.causeCode,
        message = string.format(
            "Expired read-only opportunity %s for %s.",
            tostring(opportunity.type),
            tostring(opportunity.farmId)
        ),
    })

    while #state.eventHistory > Constants.MAX_EVENT_HISTORY do
        table.remove(state.eventHistory, 1)
    end
end

function Opportunities.nextPeriod(periodId)
    return nextPeriod(periodId)
end

function Opportunities.periodCompare(left, right)
    return periodCompare(left, right)
end

function Opportunities.isExpired(record, currentPeriod)
    return isExpired(record, currentPeriod)
end

function Opportunities.normalizeOpportunity(record)
    return normalizeOpportunity(record)
end

function Opportunities.normalizeHistory(record)
    return normalizeHistory(record)
end

function Opportunities.reconcile(state, options)
    options = options or {}
    if state == nil then
        return {}
    end

    local periodId = state.periodId or Constants.DEFAULT_PERIOD_ID
    local profilesByFarmId = profileByFarmId(state.profiles)
    local cooldowns = state.cooldowns or {}
    local retained = {}
    local retainedByFarmId = {}

    for _, record in ipairs(state.opportunities or {}) do
        local opportunity = normalizeOpportunity(record)
        if opportunity ~= nil
            and opportunity.playerVisible == true
            and profilesByFarmId[opportunity.farmId] ~= nil
            and not isExpired(opportunity, periodId)
            and #retained < Constants.MAX_ACTIVE_OPPORTUNITIES
        then
            retained[#retained + 1] = opportunity
            retainedByFarmId[opportunity.farmId] = true
            cooldowns[opportunity.cooldownKey] = opportunity.expiresPeriod
        end
    end

    local canGenerate = options.allowFallback == true or ((state.mapDiscovery or {}).source == "map")
    if canGenerate then
        local snapshots, indexedProfiles = eligibleSnapshots(state)
        for _, snapshot in ipairs(snapshots) do
            if #retained >= Constants.MAX_ACTIVE_OPPORTUNITIES then
                break
            end

            local farmId = snapshot.farmId
            local profile = indexedProfiles[farmId]
            if farmId ~= nil and profile ~= nil and retainedByFarmId[farmId] ~= true then
                local candidate = createOpportunity(snapshot, profile, periodId)
                if not cooldownActive(cooldowns, candidate.cooldownKey, periodId) then
                    retained[#retained + 1] = candidate
                    retainedByFarmId[farmId] = true
                    cooldowns[candidate.cooldownKey] = candidate.expiresPeriod
                    if options.skipHistory ~= true then
                        addHistory(state, candidate)
                    end
                end
            end
        end
    end

    state.opportunities = retained
    state.cooldowns = cooldowns
    state.eventHistory = state.eventHistory or {}

    return retained
end

function Opportunities.pruneExpiredCooldowns(cooldowns, periodId)
    local retained = {}
    local removed = 0

    for key, expiresPeriod in pairs(cooldowns or {}) do
        if periodCompare(expiresPeriod, periodId) >= 0 then
            retained[key] = expiresPeriod
        else
            removed = removed + 1
        end
    end

    return retained, removed
end

function Opportunities.getForFarm(state, farmId)
    local result = {}
    if farmId == nil then
        return result
    end

    for _, record in ipairs((state or {}).opportunities or {}) do
        local opportunity = normalizeOpportunity(record)
        if opportunity ~= nil and tostring(opportunity.farmId) == tostring(farmId) then
            result[#result + 1] = opportunity
        end
    end

    table.sort(result, function(left, right)
        if left.expiresPeriod ~= right.expiresPeriod then
            return tostring(left.expiresPeriod) < tostring(right.expiresPeriod)
        end

        return tostring(left.opportunityId) < tostring(right.opportunityId)
    end)

    return result
end

function Opportunities.recalculate(state, options)
    if state ~= nil then
        state.ledgerSnapshots = Ledgers.calculateSnapshots(state.profiles or {}, state.periodId or Constants.DEFAULT_PERIOD_ID)
    end

    return Opportunities.reconcile(state, options)
end

function Opportunities.advancePeriod(state, options)
    options = options or {}
    if state == nil then
        return nil
    end

    local previousPeriod = state.periodId or Constants.DEFAULT_PERIOD_ID
    local currentPeriod = options.periodId or nextPeriod(previousPeriod)
    local expired = {}
    local retained = {}

    state.periodId = currentPeriod

    for _, record in ipairs(state.opportunities or {}) do
        local opportunity = normalizeOpportunity(record)
        if opportunity ~= nil and isExpired(opportunity, currentPeriod) then
            expired[#expired + 1] = opportunity
            addExpiredHistory(state, opportunity, currentPeriod)
        elseif opportunity ~= nil then
            retained[#retained + 1] = opportunity
        end
    end

    state.opportunities = retained
    state.cooldowns = Opportunities.pruneExpiredCooldowns(state.cooldowns or {}, currentPeriod)

    if Ledgers ~= nil and Ledgers.calculateSnapshots ~= nil then
        state.ledgerSnapshots = Ledgers.calculateSnapshots(state.profiles or {}, currentPeriod)
    end

    Opportunities.reconcile(state, {skipHistory = options.skipHistory == true})

    local cooldownCount = 0
    for _ in pairs(state.cooldowns or {}) do
        cooldownCount = cooldownCount + 1
    end

    return {
        previousPeriod = previousPeriod,
        currentPeriod = currentPeriod,
        expiredOpportunities = #expired,
        activeOpportunities = #(state.opportunities or {}),
        eventCount = #(state.eventHistory or {}),
        cooldownCount = cooldownCount,
    }
end
