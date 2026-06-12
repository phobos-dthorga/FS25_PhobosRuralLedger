# Implementation Status

## Current Slice

Implemented:

- explicit Lua module load order in `modDesc.xml`;
- constants and save key definitions;
- deterministic NPC farm profile generation;
- deterministic ledger snapshot calculation;
- stress score and stress state assignment;
- read-only local economy report lines;
- bounded log-debug access to the generated economy report;
- read-only UI model builders for Overview, Farmers, Farm Detail, and
  Settings / Debug;
- first native FS25 screen controller and XML layout for the V1 Rural Ledger
  screen;
- guarded GUI access through a keybinding and settings-menu entry point;
- versioned persistence import/export shape;
- bootstrap initialization of an in-memory Rural Ledger state.

## Runtime Evidence

`v0.1.0.0` was published as the first prerelease and installed with
`FS25_PhobosLib`. The refreshed FS25 log showed both mods loading and no
Phobos-owned errors or warnings.

`v0.1.1.0` was installed and loaded successfully after adding deterministic
ledger calculations. The broader log contained unrelated errors from other
mods, but no Phobos-owned errors or warnings.

`v0.1.2.0` adds bounded log-debug visibility for the generated report. It still
needs the same disposable-save runtime log check before the next feature slice.

`v0.1.3.0` adds the first native read-only screen UI. Static validation can
prove the Lua, XML, package, and UI model behavior, but the actual FS25 screen
open path still requires a disposable-save runtime pass before it can be called
proven in game.

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

1. Runtime-test the `v0.1.3.0` screen open path with `FS25_PhobosLib` installed.
2. Confirm the keybinding, settings entry, tab switching, farm selection,
   refresh, and debug toggle in `log.txt`.
3. Add the first cause-carrying neighbour opportunity from strained or worse
   farms.
4. Research and wire FS25 save/load lifecycle hooks only after the read-only
   state and opportunity data remain stable.
