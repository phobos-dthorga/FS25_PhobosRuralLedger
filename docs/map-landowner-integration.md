# Map-First Landowner Integration

This document records a core design correction for Rural Ledger: farms and
properties must be assessed from the current map's existing landowners,
farmlands, fields, contracts, and field state wherever FS25 exposes that data.

Rural Ledger can still add hidden finance, behaviour, pressure, relationship,
and report layers. Those layers are overlays on real map property data, not a
replacement for it.

## Design Rule

Every Rural Ledger farm or property record should be anchored to real map data:

- existing landowner or farm identity when available;
- farmland IDs and field IDs from the loaded map;
- crop type, growth state, soil state, and field size from existing field data;
- contract references tied to the same field or farmland IDs;
- Precision Farming pH, nitrogen, and environmental data when the official mod
  is installed and safe to read.

Generated profile data is allowed only as an overlay. For example, Rural Ledger
may assign a "debt-heavy dairy operator" profile to an existing landowner, but
it should not invent a standalone farm that does not correspond to map land
unless FS25 gives no usable owner source.

## Fallback Rule

Synthetic farms are a temporary fallback, not the desired model.

If FS25 APIs do not expose a landowner cleanly during an early implementation
slice, Rural Ledger may create fallback records so the UI and ledger math remain
testable. Fallback records must:

- be clearly marked with `source = "fallback"`;
- attach to known farmland or field IDs when those are available;
- avoid land, contract, auction, or ownership mutation;
- be replaced by map-derived records once the runtime discovery path is proven.

## Preserved Runtime Evidence

Screenshots from an in-game test have been saved under:

`docs/assets/runtime-reference/2026-06-12-landowner-map-evidence/`

They show the FS25 surfaces that Rural Ledger should learn from:

- contracts tied to specific field IDs, NPC portraits, names, rewards, and
  work types;
- crop-type map overlays with numbered fields and current crop coverage;
- growth-stage map overlays with cultivated, growing, harvest-ready, harvested,
  and other states;
- soil-composition map overlays for weeds, ploughing, rolling, stones, mulch,
  and watering state;
- Precision Farming pH and nitrogen overlays, including field status and
  environmental-score context.

These are reference screenshots only. They are not shipped in the mod package.

## Target Runtime Discovery

The first map-aware implementation should build a read-only discovery snapshot
on load, manual refresh, or a scheduled period update. It must not scan all
fields or contracts from a per-frame path.

`v0.1.5.0` implements the first provisional version of this snapshot for
vanilla FS25 data. It reads loaded fields, farmlands, owner farm IDs, field
state, active field missions, and optional Precision Farming mod availability.
It does not mutate land, contracts, save data, ownership, or economy state.
Exact Precision Farming pH/nitrogen values are intentionally not faked and
remain pending until a safe API is verified.

The first runtime test of `v0.1.5.0` showed why discovery must be tied to the
map lifecycle instead of plain Lua bootstrap. At bootstrap, the relevant
managers can exist but still expose zero usable fields/farmlands, producing a
misleading permanent `No map source` screen. `v0.1.5.1` changes the lifecycle:

- bootstrap builds fallback profiles with `mapReadyAttempted = false`;
- `loadMap` performs one bounded map-ready discovery pass;
- first screen open retries once only if discovery is still empty;
- manual Refresh performs one explicit rediscovery pass;
- Overview and Settings / Debug show a prominent localized no-data notice when
  a map-ready attempt still finds no usable fields.

The BetterContracts reference was useful for owner identity. Its pattern shows
that an NPC owner can be resolved from `farmland.npcIndex` through
`g_npcManager:getNPCByIndex(...)`. Rural Ledger now uses the same style of
nil-safe lookup, without copying third-party code.

Runtime testing of `v0.1.5.1` showed that `loadMap` can still be too early for
usable field records even when `g_fieldManager.fields` already has raw entries.
The failing log showed `raw=200` fields, zero usable discovery records, and
repeated `MapDiscovery.lua:125` errors from later UI/input retries. The
Soil/Fertilizer reference provided the stronger lifecycle lesson: its code
treats `loadMission00Finished` as useful for setup, but waits until
`Mission00.onStartMission` before relying on fully populated field data.
`v0.1.5.2` therefore keeps `loadMap` as a bounded probe and adds a mission-start
discovery pass as the first trusted map-backed read.

The same Soil/Fertilizer reference is useful for Precision Farming boundaries.
It exposes a diagnostic/PF-bridge style for investigating APIs, but Rural Ledger
does not copy that code and does not fake exact pH or nitrogen values. For now,
Rural Ledger only records optional Precision Farming availability through
PhobosLib's guarded integration helper. Exact pH/nitrogen reads need a separate
runtime proof or debug probe before they become player-facing data.

Candidate discovery output:

```lua
{
    mapId = "zielonka",
    periodId = 1,
    owners = {
        {
            ownerId = "map_owner_001",
            displayName = "Walter",
            source = "map",
            farmlands = { 170 },
            fields = {
                {
                    fieldId = 170,
                    farmlandId = 170,
                    areaHa = 6.06,
                    cropType = "wheat",
                    growthState = "readyToHarvest",
                    soilFlags = {
                        weeds = false,
                        needsPlowing = false,
                        needsRolling = true
                    },
                    precisionFarming = {
                        available = true,
                        exactValues = false,
                        summary = "available; exact values pending"
                    }
                }
            },
            recentContracts = {
                {
                    contractId = "mission_170_baleWrapping",
                    fieldId = 170,
                    type = "baleWrapping",
                    reward = 28087
                }
            }
        }
    }
}
```

The exact key names can change once the FS25 APIs are verified. The important
part is the ownership direction: existing map data first, Rural Ledger profile
overlay second.

## Ledger Integration Direction

Once discovery is proven, ledger calculations should consume real property
facts:

- field count and area from discovered fields;
- enterprise mix from actual crop types, livestock, and production ownership
  where available;
- income estimates from field size, crop type, growth stage, expected yield, and
  current prices;
- pressure causes from real field states such as weeds, ploughing need, harvest
  readiness, poor pH, or low nitrogen;
- contract context from active or recent missions tied to those fields.

The player-facing UI should then show source-aware summaries, such as field
numbers, crop mix, known issues, and whether Precision Farming data is present.
Exact finance remains hidden unless debug mode or relationship rules allow it.

## Implementation Stages

1. Add a read-only map discovery service that can enumerate landowners,
   farmlands, fields, crops, growth, soil flags, and active contracts where
   APIs are verified. Implemented provisionally in `v0.1.5.0`.
2. Build a `MapPropertyProfile` layer that attaches Rural Ledger profile and
   stress data to discovered owner/property records. Implemented provisionally
   in `v0.1.5.0`.
3. Replace standalone generated farm records in `Profiles` with map-derived
   records plus clearly flagged fallback records. Implemented provisionally in
   `v0.1.5.0`.
4. Update `UiModels` so Overview, Farmers, and Farm Detail can show field IDs,
   crop mix, property source, data confidence, and discovery diagnostics.
   Implemented provisionally in `v0.1.5.2`.
5. Add optional Precision Farming reads behind guarded integration checks.
   Availability is guarded in `v0.1.5.2`; exact pH/nitrogen values are still
   pending.
6. Harden map lifecycle timing, no-data visibility, and NPC owner lookup.
   Implemented provisionally in `v0.1.5.2`.
7. Only after the read-only path is stable, consider land, auction, and contract
   hooks.

## Performance Boundary

Map discovery can be moderately expensive, so it must be bounded:

- run on load, manual refresh, save reload, or period simulation;
- cache the discovered owner/property snapshot;
- never rescan all farms, fields, farmlands, active contracts, vehicles,
  placeables, fill types, or active mods per frame;
- log missing optional data with PhobosLib debug/info helpers, not repeated
  warnings.

If a map discovery implementation causes a performance hard miss, new Rural
Ledger feature work freezes until the miss is fixed or the feature is removed.

## Research Links

The API questions that block this work are tracked in
`docs/research-questions.md`, especially the sections on economy, land, field
state, Precision Farming, contracts, save identity, and UI drill-down paths.
