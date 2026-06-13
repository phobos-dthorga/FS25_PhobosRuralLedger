# Architecture

## Intended Layers

`modDesc.xml` loads a small bootstrap, then modules in explicit dependency
order.

Planned layers:

- constants and configuration;
- profile definitions;
- ledger state;
- economic simulation services;
- event generation services;
- persistence and migration;
- player-facing reports and UI adapters;
- optional integration adapters.

## Candidate Module Map

Early Lua modules should stay small and boring:

- `Constants`: mod IDs, save keys, stress states, event types, and tuning keys.
- `Profiles`: profile archetypes attached to map-derived landowners and
  fallback identity only when runtime map data is unavailable.
- `Ledgers`: current ledger state and ledger snapshots.
- `Simulation`: seasonal/monthly profit, stress, and market indicator updates.
- `Events`: opportunity selection, reasons, cooldowns, and event history.
- `Reports`: read-only formatting for local news, dashboards, and annual
  summaries.
- `UiModels`: read-only display-table builders for Overview, Farmers, selected
  Farm Detail drill-downs, and later Market Board or opportunity cards.
- `Persistence`: save/load and schema migration.
- `Integrations`: optional runtime-gated links to other mods.
- `Main`: bootstrap and module load order.

Avoid a large all-knowing manager module. If a module needs both UI formatting
and state mutation, split it.

## Business Logic Separation

UI and report files should present data and delegate actions. They should not
directly mutate farm status, ledgers, reputation, contracts, land state, or
economy outcomes.

Authoritative economy changes belong in shared gameplay services. This should
make save/load, multiplayer, and testing easier once implementation begins.

## Map-First Landowner Rule

Rural Ledger farms and properties must be anchored to the loaded map's existing
landowners, farmlands, fields, contracts, and field state wherever FS25 exposes
that data. Generated profiles are an overlay on real map property data, not the
primary source of farm existence.

Temporary fallback records are allowed while API paths are being verified, but
they must be marked as fallback, attach to real field or farmland IDs when
possible, and avoid land, contract, auction, or ownership mutation until a
map-derived source exists.

The planned map-aware layer should discover existing landowners/properties on
load, manual refresh, save reload, or period simulation. It must cache results
for UI/report use and avoid any unbounded per-frame scans. See
`map-landowner-integration.md` for the staged implementation plan and runtime
reference screenshots.

## UI Model Boundary

Build display models before building custom FS25 screens. `UiModels` should
return plain Lua tables for screen adapters and report formatters:

- `buildOverview(state, options)`;
- `buildFarmList(state, options)`;
- `buildFarmDetail(state, farmId, options)`;
- later `buildMarketBoard(state, options)` and
  `buildOpportunities(state, options)`.

`UiModels` must not call GUI APIs, mutate state, create contracts, change
reputation, alter land ownership, or recompute full ledgers per frame. GUI
adapters can render the tables and delegate player actions back to gameplay
services.

Rebuild UI models on save load, after period simulation, after accepted
opportunities, or after manual refresh. Do not perform unbounded farm, field,
vehicle, placeable, fillType, or active-mod scans from a per-frame UI path.

## Multiplayer Direction

The server should own ledger updates and any gameplay-changing decisions.
Clients can display reports and request actions, but should not decide economic
outcomes locally.

## Persistence Direction

The save format should be versioned from the beginning. Missing values should
load with defaults so older saves survive tuning changes.

Recommended state groups:

- mod save schema version;
- regional preset and tuning version;
- map-derived owner/property registry;
- NPC farm profiles attached to discovered owners/properties;
- seasonal ledger summaries;
- active pressure flags;
- generated land/contract/reputation opportunities;
- cooldowns and event history.

`v0.1.6.0` starts with the smallest runtime save surface: a dedicated
`FS25_PhobosRuralLedger.xml` file stores read-only opportunities, cooldowns,
and bounded event history only. Map-derived properties, profiles, and ledgers
are rebuilt from the live map and reconciled against the saved opportunity
records after discovery.

## Save Versioning

Every saved root should include a schema version. Migrations should be explicit
and idempotent:

- missing optional values get defaults;
- removed values are ignored;
- renamed values migrate once and keep a compatibility note;
- invalid generated state can be rebuilt only when it is safe and documented.

## Shared Library Boundary

Keep mod-specific economy rules in this repository. Move generic helpers to
`FS25_PhobosLib` when they become useful beyond Rural Ledger:

- logging wrappers;
- active-mod detection;
- save XML helper wrappers;
- guarded optional integration helpers;
- small table/math utilities;
- common Phobos constants.
