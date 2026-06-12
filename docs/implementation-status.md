# Implementation Status

## Current Slice

Implemented:

- explicit Lua module load order in `modDesc.xml`;
- constants and save key definitions;
- deterministic NPC farm profile generation;
- deterministic ledger snapshot calculation;
- stress score and stress state assignment;
- read-only local economy report lines;
- versioned persistence import/export shape;
- bootstrap initialization of an in-memory Rural Ledger state.

## Runtime Evidence

`v0.1.0.0` was published as the first prerelease and installed with
`FS25_PhobosLib`. The refreshed FS25 log showed both mods loading and no
Phobos-owned errors or warnings.

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

1. Add a simple verified report/debug access path for the generated economy
   report.
2. Add the first cause-carrying neighbour opportunity from strained or worse
   farms.
3. Research and wire FS25 save/load lifecycle hooks only after the read-only
   state and opportunity data remain stable.
