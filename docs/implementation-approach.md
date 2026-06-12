# Implementation Approach

## First Playable Slice

1. Bootstrap cleanly and confirm the mod loads with `FS25_PhobosLib`.
2. Add a tiny in-memory fallback farm profile registry for early UI and ledger
   proof.
3. Prove a read-only map discovery path for landowners, farmlands, fields,
   contracts, and field state.
4. Attach profiles to discovered map owner/property records.
5. Add a deterministic seasonal ledger calculation.
6. Persist and reload ledger snapshots only after the source IDs are stable.
7. Generate a report-only economy summary.
8. Add read-only UI model builders before any custom visual UI.
9. Add one gameplay hook after the relevant FS25 API path is verified.

## Development Rules

- Prefer deterministic calculations with seeded variation.
- Prefer current-map owner/property data over standalone generated identities.
- Keep event reasons attached to event outcomes.
- Keep tuning values centralized.
- Keep save data versioned and resilient to missing fields.
- Add static checks before adding runtime-heavy features.

## What To Avoid Early

- Custom UI before the data model earns it.
- Custom UI before read-only view models exist.
- Physically simulated NPC operations.
- Large numbers of random events.
- Deep integration with land/contracts before API research.
- Treating fallback profiles as real map owners.
- Accounting detail that does not create player-facing decisions.
