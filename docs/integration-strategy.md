# Integration Strategy

## Base Rule

Rural Ledger should remain useful as a standalone economy layer. Optional
integrations must be guarded so players with only this mod installed do not see
errors or broken references.

## Phobos Integrations

Cross-mod tie-ins are welcome when they are optional and runtime-gated.

Potential future tie-ins:

- `FS25_BgaExtensions`: local substrate demand, dry fuel logistics, production
  supply pressure, and contractor work.
- future Phobos production mods: local input shortages, oversupply, contract
  work, and regional demand reports.

## External Integrations

Possible future integration categories:

- market/commodity mods;
- precision agriculture or soil systems;
- livestock expansion mods;
- production-chain mods;
- map-specific economy data packs.

Do not reference provider-owned fill types, placeables, or APIs until their
provider is declared or detected as required by the integration design.

## Production Chain Economy

The reference design calls out production-chain pressure as a major later
feature. In practice, this should start as abstract demand signals, not direct
rewrites of every production point.

Examples:

- a local BGA raises demand for silage, slurry, manure, or substrate hauling;
- a mill shortage creates grain hauling or grain sale opportunities;
- a dairy-heavy map raises hay, silage, straw, and feed pressure;
- a sawmill or biomass route increases woodchip and transport demand.

Implementation should prefer additive reports and opportunities first. Direct
price or production changes should wait until the FS25 API path is verified.

## Data Pack Direction

A future data-pack system could let map authors or players define:

- named NPC farms;
- regional presets;
- crop/cost/price biases;
- farm personality weights;
- starting debt and land pressure;
- event text templates.

This should wait until the core model stabilizes.
