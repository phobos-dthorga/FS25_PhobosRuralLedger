# Implementation Approach

## First Playable Slice

1. Bootstrap cleanly and confirm the mod loads with `FS25_PhobosLib`.
2. Add a tiny in-memory farm profile registry.
3. Add a deterministic seasonal ledger calculation.
4. Persist and reload ledger snapshots.
5. Generate a report-only economy summary.
6. Add one gameplay hook after the relevant FS25 API path is verified.

## Development Rules

- Prefer deterministic calculations with seeded variation.
- Keep event reasons attached to event outcomes.
- Keep tuning values centralized.
- Keep save data versioned and resilient to missing fields.
- Add static checks before adding runtime-heavy features.

## What To Avoid Early

- Custom UI before the data model earns it.
- Physically simulated NPC operations.
- Large numbers of random events.
- Deep integration with land/contracts before API research.
- Accounting detail that does not create player-facing decisions.
