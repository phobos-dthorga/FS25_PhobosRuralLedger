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

## Shared Library Boundary

Keep mod-specific economy rules in this repository. Move generic helpers to
`FS25_PhobosLib` when they become useful beyond Rural Ledger:

- logging wrappers;
- active-mod detection;
- save XML helper wrappers;
- guarded optional integration helpers;
- small table/math utilities;
- common Phobos constants.
