# Implementation Status

## Current Slice

Implemented:

- explicit Lua module load order in `modDesc.xml`;
- constants and save key definitions;
- deterministic NPC farm profile generation;
- empty ledger snapshot creation;
- versioned persistence import/export shape;
- bootstrap initialization of an in-memory Rural Ledger state.

## Persistence Boundary

`Persistence.lua` currently owns table-shaped save state:

- schema version;
- mod version;
- seed;
- period ID;
- regional preset;
- generated profiles;
- ledger snapshots;
- opportunities;
- event history;
- cooldowns.

This is deliberately not wired to FS25 save/load hooks yet. The hook path must
be verified against FS25 references before any runtime save integration is
added.

## Next Implementation Slice

Recommended next code step:

1. Add deterministic ledger calculations.
2. Generate stress states from profile and ledger inputs.
3. Add read-only local economy report output.
4. Only then research and wire FS25 save/load lifecycle hooks.
