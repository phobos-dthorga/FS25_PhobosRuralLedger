PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Simulation = PhobosRuralLedger.Simulation or {}

local Simulation = PhobosRuralLedger.Simulation
local Constants = PhobosRuralLedger.Constants
local Ledgers = PhobosRuralLedger.Ledgers

function Simulation.isReady()
    return true
end

function Simulation.calculatePeriod(state, options)
    if state == nil then
        return nil
    end

    local periodId = state.periodId or Constants.DEFAULT_PERIOD_ID
    state.ledgerSnapshots = Ledgers.calculateSnapshots(state.profiles or {}, periodId, options)

    return state
end

function Simulation.countStressStates(state)
    local counts = {}

    for _, stressState in pairs(Constants.STRESS_STATES) do
        counts[stressState] = 0
    end

    for _, snapshot in ipairs((state or {}).ledgerSnapshots or {}) do
        local snapshotState = snapshot.stressState or Constants.STRESS_STATES.STABLE
        counts[snapshotState] = (counts[snapshotState] or 0) + 1
    end

    return counts
end
