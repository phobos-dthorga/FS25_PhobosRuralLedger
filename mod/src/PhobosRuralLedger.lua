PhobosRuralLedger = PhobosRuralLedger or {}

local Constants = PhobosRuralLedger.Constants
local Persistence = PhobosRuralLedger.Persistence

PhobosRuralLedger.MOD_NAME = Constants.MOD_NAME
PhobosRuralLedger.DISPLAY_NAME = Constants.DISPLAY_NAME
PhobosRuralLedger.VERSION = Constants.VERSION

function PhobosRuralLedger.bootstrap()
    if PhobosRuralLedger.isBootstrapped then
        return
    end

    PhobosRuralLedger.isBootstrapped = true
    PhobosRuralLedger.state = Persistence.importState(nil)
end

PhobosRuralLedger.bootstrap()
