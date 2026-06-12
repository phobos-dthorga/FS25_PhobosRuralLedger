PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.Reports = PhobosRuralLedger.Reports or {}

local Reports = PhobosRuralLedger.Reports

function Reports.buildProfileSummary(state)
    local lines = {}
    local profiles = {}

    if state ~= nil and state.profiles ~= nil then
        profiles = state.profiles
    end

    for index, profile in ipairs(profiles) do
        lines[index] = string.format(
            "%s: %s, %d owned fields, %s risk",
            profile.displayName or profile.farmId or "Unknown Farm",
            profile.label or profile.profileType or "Unknown Profile",
            #(profile.ownedFields or {}),
            profile.riskAttitude or "unknown"
        )
    end

    return lines
end
