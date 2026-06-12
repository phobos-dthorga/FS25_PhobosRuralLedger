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
- native FS25 screen controller and responsive list-backed XML layout for the
  V1 Rural Ledger screen;
- English and German translation files for player-facing Rural Ledger UI,
  report, and input-binding text;
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

`v0.1.3.0` added the first native read-only screen UI and the packaged mod
opened in game, but the runtime screenshot showed fixed-position UI elements
bleeding off the left side of a 3440x1440 display. The log also contained the
Phobos-owned warning `Missing l10n 'input_PHOBOS_RURAL_LEDGER_MENU'`.

`v0.1.4.0` is the repair slice for that runtime evidence. It replaces the
fixed 1520px screen shell with FS25-style menu containers, `SmoothList` backed
tables, stretching list profiles, compact farm-list columns, and English/German
translation files. Runtime proof is still required after packaging, but static
validation now blocks missing Rural Ledger l10n keys and hardcoded GUI text.

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

1. Runtime-test the `v0.1.4.0` responsive screen with `FS25_PhobosLib`
   installed.
2. Confirm the keybinding, settings entry, tab switching, farm selection,
   refresh, debug toggle, and German/English l10n behavior in `log.txt`.
3. Add the first cause-carrying neighbour opportunity from strained or worse
   farms.
4. Research and wire FS25 save/load lifecycle hooks only after the read-only
   state and opportunity data remain stable.
