PhobosRuralLedger = PhobosRuralLedger or {}

PhobosRuralLedger.MOD_NAME = "FS25_PhobosRuralLedger"
PhobosRuralLedger.DISPLAY_NAME = "Phobos' Rural Ledger"
PhobosRuralLedger.VERSION = "0.1.0.0"

function PhobosRuralLedger.bootstrap()
    if PhobosRuralLedger.isBootstrapped then
        return
    end

    PhobosRuralLedger.isBootstrapped = true
end

PhobosRuralLedger.bootstrap()
