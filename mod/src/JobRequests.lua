PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.JobRequests = PhobosRuralLedger.JobRequests or {}

local JobRequests = PhobosRuralLedger.JobRequests
local Constants = PhobosRuralLedger.Constants
local Ledgers = PhobosRuralLedger.Ledgers

JobRequests.outcomeHookRegistered = JobRequests.outcomeHookRegistered == true
JobRequests.outcomeHookStatus = JobRequests.outcomeHookStatus or "not_attempted"
JobRequests.lastLaunchStatus = JobRequests.lastLaunchStatus or "not_attempted"
JobRequests.lastLaunchReason = JobRequests.lastLaunchReason or nil
JobRequests.lastLaunchRequestId = JobRequests.lastLaunchRequestId or nil
JobRequests.launchAttempts = JobRequests.launchAttempts or 0

local STRESS_RANK = {
    stable = 1,
    watch = 2,
    strained = 3,
    distressed = 4,
    insolvent = 5,
}

local PRESSURE_TO_CONTRACT = {
    negative_cash = "harvest_support",
    weak_margin = "fieldwork_support",
    debt_service = "transport_support",
    storage_shortage = "transport_support",
    machinery_cost = "fieldwork_support",
    low_diversity = "cultivation_support",
}

local FAILURE_STATES = {
    FAILED = true,
    CANCELLED = true,
    CANCELED = true,
    TIMED_OUT = true,
    TIMEDOUT = true,
}

local function formatMessage(message, ...)
    if select("#", ...) == 0 then
        return tostring(message)
    end

    local ok, value = pcall(string.format, tostring(message), ...)
    if ok then
        return value
    end

    return tostring(message)
end

local function logInfo(message, ...)
    if PhobosRuralLedger.logInfo ~= nil then
        PhobosRuralLedger.logInfo(message, ...)
    elseif print ~= nil then
        print(string.format("[PhobosRuralLedger][INFO] %s", formatMessage(message, ...)))
    end
end

local function logWarn(message, ...)
    if PhobosRuralLedger.logWarn ~= nil then
        PhobosRuralLedger.logWarn(message, ...)
    elseif print ~= nil then
        print(string.format("[PhobosRuralLedger][WARN] %s", formatMessage(message, ...)))
    end
end

local function sanitize(value)
    return string.gsub(string.lower(tostring(value or "unknown")), "[^%w_]+", "_")
end

local function call(object, methodName, ...)
    if type(object) == "table" and object[methodName] ~= nil then
        local ok, value = pcall(object[methodName], object, ...)
        if ok then
            return value
        end
    end

    return nil
end

local function tableValue(object, key)
    if type(object) == "table" then
        return object[key]
    end

    return nil
end

local function displayName(object)
    if object == nil then
        return nil
    end

    if type(object) ~= "table" then
        return tostring(object)
    end

    return object.title
        or object.name
        or object.displayName
        or call(object, "getName")
        or call(object, "getTitle")
end

local function appendUnique(values, value)
    if value == nil then
        return
    end

    for _, existing in ipairs(values or {}) do
        if tostring(existing) == tostring(value) then
            return
        end
    end

    values[#values + 1] = value
end

local function countMap(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

local function profileByFarmId(profiles)
    local result = {}

    for _, profile in ipairs(profiles or {}) do
        if profile.farmId ~= nil then
            result[tostring(profile.farmId)] = profile
        end
    end

    return result
end

local function snapshotsByFarmId(state)
    if Ledgers ~= nil and Ledgers.indexSnapshotsByFarmId ~= nil then
        return Ledgers.indexSnapshotsByFarmId((state or {}).ledgerSnapshots or {})
    end

    local result = {}
    for _, snapshot in ipairs((state or {}).ledgerSnapshots or {}) do
        if snapshot.farmId ~= nil then
            result[tostring(snapshot.farmId)] = snapshot
        end
    end
    return result
end

local function ownerKey(profileOrRequest)
    local key = (profileOrRequest or {}).npcKey
        or (profileOrRequest or {}).relationshipKey
        or (profileOrRequest or {}).ownerName
        or (profileOrRequest or {}).npcName

    if key ~= nil and key ~= "" then
        return "npc:" .. sanitize(key)
    end

    return "farm:" .. sanitize((profileOrRequest or {}).farmId)
end

local function applyRelationshipOverrides(state)
    local overrides = (state or {}).relationshipOverrides or {}

    for _, profile in ipairs((state or {}).profiles or {}) do
        local key = ownerKey(profile)
        if overrides[key] ~= nil then
            profile.relationshipScore = math.max(1, math.min(5, tonumber(overrides[key]) or 3))
        end
    end
end

local function getMissionField(mission)
    return call(mission, "getField") or tableValue(mission, "field")
end

local function parseFieldName(field)
    local name = displayName(field)
    if name == nil then
        return nil
    end

    local value = string.match(tostring(name), "(%d+)")
    return value ~= nil and tonumber(value) or nil
end

local function getFieldId(field)
    if type(field) ~= "table" then
        return nil
    end

    return field.fieldId
        or field.id
        or field.fieldNumber
        or call(field, "getFieldId")
        or call(field, "getId")
        or parseFieldName(field)
end

local function getFarmlandIdFromField(field)
    if type(field) ~= "table" then
        return nil
    end

    local farmland = field.farmland or call(field, "getFarmland")
    return field.farmlandId
        or tableValue(farmland, "id")
        or tableValue(farmland, "farmlandId")
        or call(farmland, "getId")
end

local function getMissionId(mission, index)
    return call(mission, "getUniqueId")
        or mission.uniqueId
        or mission.missionId
        or mission.id
        or string.format("mission_%03d", tonumber(index) or 0)
end

local function getMissionNpc(mission)
    local npc = call(mission, "getNPC") or mission.npc
    local name = displayName(npc) or mission.npcName

    if name == nil and type(npc) == "table" and npc.index ~= nil then
        name = string.format("NPC %s", tostring(npc.index))
    end

    return name
end

local function missionTypeName(mission)
    return call(mission, "getMissionTypeName")
        or tableValue(tableValue(mission, "type"), "name")
        or mission.typeName
        or mission.name
        or "field_mission"
end

local function missionStatusValue(mission)
    return call(mission, "getStatus") or mission.status
end

local function missionStatusName(mission)
    local status = missionStatusValue(mission)

    if MissionStatus ~= nil then
        for key, value in pairs(MissionStatus) do
            if value == status then
                return tostring(key)
            end
        end
    end

    if type(status) == "string" then
        return string.upper(status)
    end

    return tostring(status or "unknown")
end

local function missionIsCreated(mission)
    local status = missionStatusValue(mission)
    if MissionStatus ~= nil and MissionStatus.CREATED ~= nil then
        return status == MissionStatus.CREATED
    end

    local name = missionStatusName(mission)
    return name == "CREATED" or name == "created"
end

local function contractSource()
    if g_modIsLoaded ~= nil and g_modIsLoaded.FS25_BetterContracts == true then
        return "betterContracts"
    end

    if BetterContracts ~= nil then
        return "betterContracts"
    end

    return "vanilla"
end

local function missionRewardText(mission)
    local reward = call(mission, "getReward") or call(mission, "getTotalReward") or mission.reward
    local info = mission.info or {}

    if info.profit ~= nil then
        reward = info.profit
    end

    if reward == nil then
        return "-"
    end

    if g_i18n ~= nil and g_i18n.formatMoney ~= nil then
        local ok, text = pcall(g_i18n.formatMoney, g_i18n, reward, 0, true, true)
        if ok and text ~= nil then
            return tostring(text)
        end
    end

    return string.format("$%d", math.floor(tonumber(reward) or 0))
end

local function fieldAreaValue(field)
    if type(field) ~= "table" then
        return nil
    end

    return tonumber(call(field, "getAreaHa"))
        or tonumber(field.fieldArea)
        or tonumber(field.areaHa)
        or tonumber(field.area)
end

local function missionDetailValue(mission, info, ...)
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        local value = tableValue(info, key)
        if value == nil then
            value = tableValue(mission, key)
        end
        if value == nil then
            value = call(mission, key)
        end

        if value ~= nil then
            return value
        end
    end

    return nil
end

local function missionDetails(mission, field)
    local info = type(mission.info) == "table" and mission.info or {}

    return {
        fieldArea = fieldAreaValue(field),
        profit = missionDetailValue(mission, info, "profit", "profitValue"),
        workTime = missionDetailValue(mission, info, "workTime", "worktime", "estimatedTime", "timeText"),
        profitPerMinute = missionDetailValue(mission, info, "profitPerMinute", "profitPerMin", "perMin"),
        usageCost = missionDetailValue(mission, info, "usageCost", "usage", "vehicleUseCost"),
        leaseCost = missionDetailValue(mission, info, "leaseCost", "leasingCost", "vehicleLeaseCost"),
        deliveryHint = missionDetailValue(mission, info, "deliveryHint", "delivery", "deliverTo"),
        keepHint = missionDetailValue(mission, info, "keepHint", "keep", "keepProduct"),
    }
end

local function profileForMission(state, mission)
    local field = getMissionField(mission)
    local fieldId = getFieldId(field) or mission.fieldId
    local farmlandId = getFarmlandIdFromField(field) or mission.farmlandId
    local npcName = getMissionNpc(mission)

    for _, profile in ipairs((state or {}).profiles or {}) do
        for _, value in ipairs(profile.fieldIds or profile.ownedFields or {}) do
            if fieldId ~= nil and tostring(value) == tostring(fieldId) then
                return profile, fieldId, farmlandId, npcName
            end
        end

        for _, value in ipairs(profile.farmlandIds or {}) do
            if farmlandId ~= nil and tostring(value) == tostring(farmlandId) then
                return profile, fieldId, farmlandId, npcName
            end
        end

        local profileNpc = profile.npcName or profile.ownerName
        if npcName ~= nil and profileNpc ~= nil and tostring(profileNpc) == tostring(npcName) then
            return profile, fieldId, farmlandId, npcName
        end
    end

    return nil, fieldId, farmlandId, npcName
end

local function normalizeMissionRequest(state, mission, index, source)
    if type(mission) ~= "table" then
        return nil
    end

    local profile, fieldId, farmlandId, npcName = profileForMission(state, mission)
    if profile == nil then
        return nil
    end

    local missionId = getMissionId(mission, index)
    local farmId = profile.farmId
    local statusName = missionStatusName(mission)
    local details = missionDetails(mission, getMissionField(mission))
    local title = mission.title
        or string.format("%s - Field %s", missionTypeName(mission), tostring(fieldId or "?"))

    return {
        requestId = string.format("job_%s_%s", sanitize(source), sanitize(missionId)),
        source = source,
        npcKey = ownerKey(profile),
        npcName = npcName or profile.npcName or profile.ownerName or profile.displayName or tostring(farmId),
        farmId = farmId,
        farmName = profile.displayName,
        farmlandId = farmlandId or (profile.farmlandIds or {})[1],
        fieldId = fieldId or (profile.fieldIds or profile.ownedFields or {})[1],
        missionId = missionId,
        missionRef = mission,
        contractType = missionTypeName(mission),
        title = title,
        rewardText = missionRewardText(mission),
        status = statusName,
        launchable = missionIsCreated(mission),
        blockedReason = missionIsCreated(mission) and nil or "mission_not_created",
        details = details,
        relationshipEffect = {
            success = 1,
            failure = -1,
        },
        relationshipKey = ownerKey(profile),
        generated = false,
    }
end

local function collectRuntimeMissions(state)
    local requests = {}
    local seen = {}
    local seenMissionObjects = {}
    local source = contractSource()
    local index = 0

    local function addMission(mission)
        if type(mission) == "table" then
            if seenMissionObjects[mission] == true then
                return
            end

            seenMissionObjects[mission] = true
        end

        index = index + 1
        local request = normalizeMissionRequest(state, mission, index, source)
        if request == nil then
            return
        end

        local dedupeKey = tostring(request.fieldId or request.missionId or request.requestId)
        if seen[dedupeKey] == true then
            return
        end

        seen[dedupeKey] = true
        requests[#requests + 1] = request
    end

    if g_missionManager ~= nil then
        local missions = call(g_missionManager, "getMissions") or g_missionManager.missions or {}
        for _, mission in pairs(missions) do
            addMission(mission)
        end
    end

    for _, profile in ipairs((state or {}).profiles or {}) do
        for _, mission in ipairs(profile.contractRefs or {}) do
            addMission(mission)
        end
    end

    return requests
end

local function generatedTitle(snapshot)
    local pressure = (snapshot or {}).primaryPressure or Constants.PRESSURE_TYPES.NONE
    local requestType = PRESSURE_TO_CONTRACT[pressure] or "fieldwork_support"

    return requestType, pressure
end

local function addGeneratedGapRequests(state, requests)
    local byFarmId = {}
    for _, request in ipairs(requests or {}) do
        byFarmId[tostring(request.farmId)] = true
    end

    local snapshots = snapshotsByFarmId(state)
    for _, profile in ipairs((state or {}).profiles or {}) do
        if byFarmId[tostring(profile.farmId)] ~= true then
            local snapshot = snapshots[tostring(profile.farmId)] or {}
            local requestType, causeCode = generatedTitle(snapshot)
            local fieldId = (profile.fieldIds or profile.ownedFields or {})[1]
            local farmlandId = (profile.farmlandIds or {})[1]
            local title = string.format("%s request", tostring(requestType))

            requests[#requests + 1] = {
                requestId = string.format(
                    "job_generated_%s_%s",
                    sanitize(profile.farmId),
                    sanitize(state.periodId or Constants.DEFAULT_PERIOD_ID)
                ),
                source = "ruralLedger",
                npcKey = ownerKey(profile),
                npcName = profile.npcName or profile.ownerName or profile.displayName or tostring(profile.farmId),
                farmId = profile.farmId,
                farmName = profile.displayName,
                farmlandId = farmlandId,
                fieldId = fieldId,
                missionId = nil,
                missionRef = nil,
                contractType = requestType,
                title = title,
                rewardText = "-",
                status = "NO_ACTIVE_JOB",
                launchable = false,
                blockedReason = "generated_only",
                relationshipEffect = {
                    success = 1,
                    failure = -1,
                },
                relationshipKey = ownerKey(profile),
                generated = true,
                causeCode = causeCode,
            }
        end
    end
end

local function sortRequests(requests)
    table.sort(requests, function(left, right)
        if (left.launchable == true) ~= (right.launchable == true) then
            return left.launchable == true
        end

        if tostring(left.npcName or "") ~= tostring(right.npcName or "") then
            return tostring(left.npcName or "") < tostring(right.npcName or "")
        end

        if tostring(left.farmlandId or "") ~= tostring(right.farmlandId or "") then
            return tostring(left.farmlandId or "") < tostring(right.farmlandId or "")
        end

        return tostring(left.requestId or "") < tostring(right.requestId or "")
    end)
end

local function trimRequests(requests)
    local retained = {}
    local limit = Constants.MAX_JOB_REQUESTS or 120

    for index, request in ipairs(requests or {}) do
        if index > limit then
            break
        end
        retained[#retained + 1] = request
    end

    return retained
end

local function activeCounts(requests)
    local counts = {
        total = 0,
        betterContracts = 0,
        vanilla = 0,
        ruralLedger = 0,
        launchable = 0,
        generated = 0,
    }

    for _, request in ipairs(requests or {}) do
        counts.total = counts.total + 1
        counts[request.source or "ruralLedger"] = (counts[request.source or "ruralLedger"] or 0) + 1
        if request.launchable == true then
            counts.launchable = counts.launchable + 1
        end
        if request.generated == true then
            counts.generated = counts.generated + 1
        end
    end

    return counts
end

local function normalizeJobHistory(record)
    if type(record) ~= "table" then
        return nil
    end

    return {
        eventId = record.eventId or string.format(
            "job_event_%s_%s",
            sanitize(record.requestId or record.farmId),
            sanitize(record.periodId or Constants.DEFAULT_PERIOD_ID)
        ),
        periodId = record.periodId or Constants.DEFAULT_PERIOD_ID,
        requestId = record.requestId,
        farmId = record.farmId,
        npcKey = record.npcKey,
        npcName = record.npcName,
        farmlandId = record.farmlandId,
        fieldId = record.fieldId,
        type = record.type or "job_event",
        status = record.status or "unknown",
        relationshipDelta = tonumber(record.relationshipDelta) or 0,
        message = record.message,
        modVersion = record.modVersion or Constants.VERSION,
    }
end

local function appendJobHistory(state, record)
    state.jobHistory = state.jobHistory or {}

    local normalized = normalizeJobHistory(record)
    if normalized == nil then
        return nil
    end

    state.jobHistory[#state.jobHistory + 1] = normalized

    while #state.jobHistory > (Constants.MAX_JOB_HISTORY or 80) do
        table.remove(state.jobHistory, 1)
    end

    return normalized
end

local function requestById(state, requestId)
    if requestId == nil then
        return nil
    end

    for _, request in ipairs((state or {}).jobRequests or {}) do
        if tostring(request.requestId or "") == tostring(requestId) then
            return request
        end
    end

    return nil
end

local function requestForMission(state, mission)
    if mission == nil then
        return nil
    end

    local missionId = getMissionId(mission, 0)
    for _, request in ipairs((state or {}).jobRequests or {}) do
        if request.missionRef == mission
            or (request.missionId ~= nil and tostring(request.missionId) == tostring(missionId))
        then
            return request
        end
    end

    return nil
end

local function clampRelationship(score)
    return math.max(1, math.min(5, math.floor((tonumber(score) or 3) + 0.5)))
end

local function adjustRelationship(state, request, delta, status)
    if state == nil or request == nil then
        return nil
    end

    state.relationshipOverrides = state.relationshipOverrides or {}
    local key = request.relationshipKey or request.npcKey or ownerKey(request)
    local current = tonumber(state.relationshipOverrides[key])

    if current == nil then
        for _, profile in ipairs(state.profiles or {}) do
            if tostring(profile.farmId or "") == tostring(request.farmId or "") then
                current = tonumber(profile.relationshipScore)
                break
            end
        end
    end

    current = current or 3
    local nextScore = clampRelationship(current + (delta or 0))
    state.relationshipOverrides[key] = nextScore
    applyRelationshipOverrides(state)

    appendJobHistory(state, {
        eventId = string.format(
            "job_%s_%s_%s",
            sanitize(request.requestId),
            sanitize(status),
            tostring(#(state.jobHistory or {}) + 1)
        ),
        periodId = state.periodId,
        requestId = request.requestId,
        farmId = request.farmId,
        npcKey = request.npcKey,
        npcName = request.npcName,
        farmlandId = request.farmlandId,
        fieldId = request.fieldId,
        type = "job_outcome",
        status = status,
        relationshipDelta = delta or 0,
        message = string.format(
            "Job %s for %s changed relationship by %+d.",
            tostring(status),
            tostring(request.npcName or request.farmName or request.farmId),
            delta or 0
        ),
    })

    return nextScore
end

local function currentFarmId()
    if g_currentMission ~= nil and g_currentMission.getFarmId ~= nil then
        return g_currentMission:getFarmId()
    end

    return FarmManager ~= nil and FarmManager.SPECTATOR_FARM_ID or 1
end

local function betterContractsJobsLeft()
    if BetterContracts == nil or BetterContracts.config == nil then
        return nil, nil
    end

    local hardMode = BetterContracts.config.hardMode == true
    local hardLimit = tonumber(BetterContracts.config.hardLimit)
    if hardMode ~= true or hardLimit == nil or hardLimit < 0 then
        return nil, nil
    end

    local farm = nil
    if g_farmManager ~= nil and g_farmManager.getFarmById ~= nil then
        farm = g_farmManager:getFarmById(currentFarmId())
    end

    local jobsLeft = tableValue(tableValue(farm, "stats"), "jobsLeft")
    if jobsLeft == nil or jobsLeft == -1 then
        jobsLeft = hardLimit
    end

    return jobsLeft, hardLimit
end

local function launchMission(request)
    if MissionStartEvent == nil or MissionStartEvent.new == nil then
        return false, "mission_start_event_unavailable"
    end

    if g_client == nil or g_client.getServerConnection == nil then
        return false, "client_connection_unavailable"
    end

    local connection = g_client:getServerConnection()
    if connection == nil or connection.sendEvent == nil then
        return false, "server_connection_unavailable"
    end

    local jobsLeft = betterContractsJobsLeft()
    if jobsLeft ~= nil and jobsLeft <= 0 then
        return false, "monthly_job_limit"
    end

    local event = MissionStartEvent.new(request.missionRef, currentFarmId(), false)
    if jobsLeft ~= nil then
        event.jobsLeft = jobsLeft - 1
    end

    connection:sendEvent(event)
    return true, "started"
end

function JobRequests.applyRelationshipOverrides(state)
    applyRelationshipOverrides(state)
end

function JobRequests.normalizeHistory(record)
    return normalizeJobHistory(record)
end

function JobRequests.refresh(state, options)
    options = options or {}
    if state == nil then
        return {}
    end

    applyRelationshipOverrides(state)

    local requests = collectRuntimeMissions(state)
    addGeneratedGapRequests(state, requests)
    sortRequests(requests)
    requests = trimRequests(requests)

    local counts = activeCounts(requests)
    state.jobRequests = requests
    state.jobDiagnostics = {
        trigger = options.trigger or "refresh",
        sourcePriority = contractSource(),
        totalRequests = counts.total,
        betterContractsRequests = counts.betterContracts or 0,
        vanillaRequests = counts.vanilla or 0,
        generatedRequests = counts.ruralLedger or counts.generated or 0,
        launchableRequests = counts.launchable or 0,
        relationshipRecordCount = countMap(state.relationshipOverrides),
        historyCount = #(state.jobHistory or {}),
        outcomeHookStatus = JobRequests.outcomeHookStatus or "not_attempted",
        launchAttempts = JobRequests.launchAttempts or 0,
        lastLaunchStatus = JobRequests.lastLaunchStatus or "not_attempted",
        lastLaunchReason = JobRequests.lastLaunchReason,
        lastLaunchRequestId = JobRequests.lastLaunchRequestId,
    }

    if options.log ~= false and options.silent ~= true then
        logInfo(
            "Rural Ledger jobs refreshed (%s): %d total, %d launchable, source=%s, generated=%d.",
            tostring(state.jobDiagnostics.trigger),
            counts.total,
            counts.launchable,
            tostring(state.jobDiagnostics.sourcePriority),
            counts.ruralLedger or counts.generated or 0
        )
    end

    return requests
end

function JobRequests.getForFarm(state, farmId)
    local result = {}
    if farmId == nil then
        return result
    end

    for _, request in ipairs((state or {}).jobRequests or {}) do
        if tostring(request.farmId or "") == tostring(farmId or "") then
            result[#result + 1] = request
        end
    end

    return result
end

function JobRequests.getById(state, requestId)
    return requestById(state, requestId)
end

function JobRequests.getMonthlyJobLimitInfo()
    local jobsLeft, hardLimit = betterContractsJobsLeft()

    return {
        available = jobsLeft ~= nil,
        jobsLeft = jobsLeft,
        hardLimit = hardLimit,
    }
end

function JobRequests.canStartContract(state, requestId)
    local request = requestById(state, requestId)
    if request == nil then
        return false, "no_selection"
    end

    if request.launchable ~= true or request.missionRef == nil then
        return false, request.blockedReason or "not_launchable"
    end

    if not missionIsCreated(request.missionRef) then
        return false, "mission_not_created"
    end

    local jobsLeft = betterContractsJobsLeft()
    if jobsLeft ~= nil and jobsLeft <= 0 then
        return false, "monthly_job_limit"
    end

    return true, "ready"
end

function JobRequests.startContract(state, requestId, options)
    options = options or {}
    state = state or PhobosRuralLedger.getState and PhobosRuralLedger.getState() or nil
    JobRequests.launchAttempts = (JobRequests.launchAttempts or 0) + 1

    local request = requestById(state, requestId)
    if request == nil then
        JobRequests.lastLaunchStatus = "blocked"
        JobRequests.lastLaunchReason = "no_selection"
        JobRequests.lastLaunchRequestId = nil
        return false, "no_selection"
    end

    local allowed, reason = JobRequests.canStartContract(state, requestId)
    if not allowed then
        JobRequests.lastLaunchStatus = "blocked"
        JobRequests.lastLaunchReason = reason
        JobRequests.lastLaunchRequestId = requestId
        return false, reason, request
    end

    local ok, status = launchMission(request)
    JobRequests.lastLaunchStatus = ok and "started" or "blocked"
    JobRequests.lastLaunchReason = status
    JobRequests.lastLaunchRequestId = requestId

    if ok then
        appendJobHistory(state, {
            eventId = string.format("job_started_%s_%d", sanitize(requestId), #(state.jobHistory or {}) + 1),
            periodId = state.periodId,
            requestId = request.requestId,
            farmId = request.farmId,
            npcKey = request.npcKey,
            npcName = request.npcName,
            farmlandId = request.farmlandId,
            fieldId = request.fieldId,
            type = "job_started",
            status = "started",
            relationshipDelta = 0,
            message = string.format("Started live contract %s.", tostring(request.title or request.requestId)),
        })
        logInfo("Rural Ledger started contract for %s: %s.", tostring(request.npcName or request.farmName), tostring(request.title))
    else
        logWarn("Rural Ledger contract start blocked for %s: %s.", tostring(request.requestId), tostring(status))
    end

    return ok, status, request
end

function JobRequests.recordMissionOutcome(mission, success)
    local state = PhobosRuralLedger.getState ~= nil and PhobosRuralLedger.getState() or nil
    local request = requestForMission(state, mission)
    if request == nil then
        return false
    end

    local status = success == true and "completed" or missionStatusName(mission)
    local normalizedStatus = string.upper(tostring(status or "failed"))
    local delta = 1
    if success ~= true or FAILURE_STATES[normalizedStatus] == true then
        delta = -1
        status = normalizedStatus == "UNKNOWN" and "failed" or string.lower(normalizedStatus)
    else
        status = "completed"
    end

    adjustRelationship(state, request, delta, status)

    if PhobosRuralLedger.saveOpportunityState ~= nil then
        PhobosRuralLedger.saveOpportunityState(g_currentMission)
    end

    return true
end

local function onMissionFinish(mission, success)
    JobRequests.recordMissionOutcome(mission, success)
end

function JobRequests.ensureOutcomeHookRegistered()
    if JobRequests.outcomeHookRegistered == true then
        JobRequests.outcomeHookStatus = "already_registered"
        return true, JobRequests.outcomeHookStatus
    end

    if Utils == nil or Utils.appendedFunction == nil then
        JobRequests.outcomeHookStatus = "utils_unavailable"
        return false, JobRequests.outcomeHookStatus
    end

    if AbstractMission == nil or AbstractMission.finish == nil then
        JobRequests.outcomeHookStatus = "target_unavailable"
        return false, JobRequests.outcomeHookStatus
    end

    AbstractMission.finish = Utils.appendedFunction(AbstractMission.finish, onMissionFinish)
    JobRequests.outcomeHookRegistered = true
    JobRequests.outcomeHookStatus = "registered"
    logInfo("Rural Ledger job outcome hook registered: AbstractMission.finish.")
    return true, JobRequests.outcomeHookStatus
end

function JobRequests.getDiagnostics(state)
    local diagnostics = (state or {}).jobDiagnostics or {}

    return {
        sourcePriority = diagnostics.sourcePriority or contractSource(),
        totalRequests = diagnostics.totalRequests or #((state or {}).jobRequests or {}),
        betterContractsRequests = diagnostics.betterContractsRequests or 0,
        vanillaRequests = diagnostics.vanillaRequests or 0,
        generatedRequests = diagnostics.generatedRequests or 0,
        launchableRequests = diagnostics.launchableRequests or 0,
        relationshipRecordCount = countMap((state or {}).relationshipOverrides),
        historyCount = #((state or {}).jobHistory or {}),
        outcomeHookStatus = JobRequests.outcomeHookStatus or "not_attempted",
        launchAttempts = JobRequests.launchAttempts or 0,
        lastLaunchStatus = JobRequests.lastLaunchStatus or "not_attempted",
        lastLaunchReason = JobRequests.lastLaunchReason,
        lastLaunchRequestId = JobRequests.lastLaunchRequestId,
    }
end

function JobRequests._resetForTests()
    JobRequests.outcomeHookRegistered = false
    JobRequests.outcomeHookStatus = "not_attempted"
    JobRequests.lastLaunchStatus = "not_attempted"
    JobRequests.lastLaunchReason = nil
    JobRequests.lastLaunchRequestId = nil
    JobRequests.launchAttempts = 0
end

JobRequests.ensureOutcomeHookRegistered()
