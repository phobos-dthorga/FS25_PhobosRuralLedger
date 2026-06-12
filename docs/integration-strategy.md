# Integration Strategy

## Base Rule

Rural Ledger should remain useful as a standalone economy layer. Optional
integrations must be guarded so players with only this mod and its required
Phobos library do not see errors or broken references.

## Phobos Integrations

Cross-mod tie-ins are welcome when they are optional and runtime-gated.

Potential future tie-ins:

- `FS25_BgaExtensions`: local substrate demand, dry fuel logistics, production
  supply pressure, and contractor work.
- `FS25_PhobosLib`: shared logging, active-mod detection, save helpers, and
  guarded compatibility utilities.

## External Integrations

Possible future integration categories:

- market/commodity mods;
- precision agriculture or soil systems;
- livestock expansion mods;
- production-chain mods;
- map-specific economy data packs.

Do not reference provider-owned fill types, placeables, or APIs until their
provider is declared or detected as required by the integration design.

## Data Pack Direction

A future data-pack system could let map authors or players define:

- named NPC farms;
- regional presets;
- crop/cost/price biases;
- farm personality weights;
- starting debt and land pressure;
- event text templates.

This should wait until the core model stabilizes.
