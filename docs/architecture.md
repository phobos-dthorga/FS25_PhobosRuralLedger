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
- `Profiles`: profile archetypes and generated NPC farm identity.
- `Ledgers`: current ledger state and ledger snapshots.
- `Simulation`: seasonal/monthly profit, stress, and market indicator updates.
- `Events`: opportunity selection, reasons, cooldowns, and event history.
- `Reports`: read-only formatting for local news, dashboards, and annual
  summaries.
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
- NPC farm profiles;
- seasonal ledger summaries;
- active pressure flags;
- generated land/contract/reputation opportunities;
- cooldowns and event history.

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
