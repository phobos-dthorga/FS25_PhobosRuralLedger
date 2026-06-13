# Implementation Status

## Current Slice

Implemented:

- explicit Lua module load order in `modDesc.xml`;
- constants and save key definitions;
- provisional read-only map discovery for fields, farmlands, owner IDs,
  field state, active field missions, and Precision Farming availability;
- deterministic NPC farm profile generation;
- map-derived profile overlays when discovery finds usable owner/property
  records;
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
- bootstrap initialization of an in-memory Rural Ledger fallback state without
  treating early empty map managers as final discovery;
- one bounded map-ready discovery pass after map load;
- one bounded screen-open retry when discovery is still empty;
- manual refresh of the read-only map-backed state and display models;
- prominent localized no-data notices when a map-ready discovery attempt still
  finds no usable field data;
- dedicated Rural Ledger GUI profile loading through `gui/guiProfiles.xml`;
- oversized owner/NPC discovery bucket splitting into farmland-backed property
  records;
- Farm Detail as a selected-property drill-down inside the Farmers screen, not
  as a top-level overview tab.

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

After `v0.1.4.0`, runtime testing confirmed the screen direction is usable:
rows can be selected, debug mode activates, and the layout is orderly enough to
continue. A new design rule is now documented: Rural Ledger farms/properties
must be assessed from the loaded map's existing landowners, farmlands, fields,
contracts, crop state, soil state, and optional Precision Farming data wherever
FS25 exposes them. The current generated profiles are therefore a fallback
implementation detail, not the long-term source of truth. See
`map-landowner-integration.md`.

`v0.1.5.0` is the first implementation of that rule. It adds a bounded
read-only map discovery pass, attaches profiles and ledger snapshots to
discovered owner/property records, exposes source/confidence/field/crop
condition context in the V1 UI models, and keeps fallback profiles only when no
runtime map data is usable. Exact Precision Farming pH/nitrogen values remain
pending until a safe read API is proven; this slice records availability only.

Runtime testing of `v0.1.5.0` found a lifecycle timing failure: bootstrap ran
map discovery before `g_fieldManager` / `g_farmlandManager` had usable map
data, so the screen showed `No map source` even after the map was loaded. The
same test exposed repeated GUI profile warnings for the unresolved `button`
profile path.

`v0.1.5.1` is the hotfix for that evidence. Bootstrap now creates a clearly
non-map-ready fallback state, discovery runs once after map load, the first
Rural Ledger screen open retries once if discovery is still empty, and manual
Refresh remains a single bounded rediscovery pass. The discovery diagnostics
now include manager availability, raw field/farmland/mission counts, and the
trigger that produced the current snapshot. The BetterContracts reference also
confirmed the useful NPC-owner pattern of resolving `farmland.npcIndex` through
`g_npcManager:getNPCByIndex(...)`; Rural Ledger now mirrors that idea without
copying third-party code.

Runtime testing of `v0.1.5.1` then showed a second timing and shape problem:
Rural Ledger saw `raw=200` field-manager entries at `mapLoad`, but still found
zero usable map-backed fields and later raised repeated Phobos-owned
`MapDiscovery.lua:125` errors when UI/input paths retried discovery. The same
log still included repeated unresolved `button` GUI profile warnings.

`v0.1.5.2` is the follow-up hotfix for that evidence. `loadMap` is now treated
as an early diagnostic probe, while `Mission00.onStartMission` performs the
first trusted discovery pass because the Soil/Fertilizer reference documents
that `g_fieldManager.fields` is fully populated at that point. Discovery now
accepts real-style `field.fieldId`, field area, `field.farmland`,
`farmland.id`, and `farmland.npcIndex` shapes; malformed fields or missions are
skipped into bounded diagnostics instead of crashing FS25. Precision Farming
availability is still detected through the guarded PhobosLib integration helper,
but exact pH and nitrogen values remain pending until a safe API is proven.

Runtime testing of `v0.1.5.2` then confirmed the trusted discovery timing:
manual Refresh produced a clean map-backed line with 200 usable fields, 240
farmlands, 41 contracts, zero skipped records, zero discovery errors, and
Precision Farming availability. The same session exposed two remaining
Phobos-owned blockers. The screen load emitted repeated `Could not retrieve GUI
profile 'button'` warnings that matched visible button/tab/footer distortion
after clicking Rural Ledger controls. Discovery also collapsed the whole tested
map into one property, so Farm Detail showed a single `GRANDPA` record with 200
controlled fields.

`v0.1.5.3` targets those blockers. Rural Ledger GUI profiles now live in
`gui/guiProfiles.xml` and are loaded before `RuralLedgerScreen.xml`, matching
the pattern used by the reference UI mods. Button profiles no longer inherit
from the fragile `buttonOK` path for custom screen controls. Map discovery now
keeps small owner/NPC buckets grouped but splits broad owner buckets by
farmland when they exceed 24 fields or 8 farmlands, producing property-scale
records such as `Owner - Farmland 170`. Long field/farmland ID lines are
bounded in the UI with a `(+N more)` suffix.

Runtime testing of `v0.1.5.3` confirmed the property grouping direction: the
Farmers table now shows many map-backed records such as `ANIMAL_DEALER -
Farmland 56`, `FARMER - Farmland 34`, and `FORESTER - Farmland 100` instead of
one giant owner record. The same test refined the UI hierarchy: top tabs are
reserved for overview-level destinations. The first implementation interpreted
selected-property drill-downs as an inline Farmers sub-panel; later UI review
clarified that the intended pattern is a context-aware footer action. The log
still contained repeated generic `Could not retrieve GUI profile 'button'`
warnings before the Rural Ledger profile/screen load messages, so ownership
must be rechecked before feature work resumes.

`v0.1.5.4` implemented the first navigation correction. The top tabs are
Overview, Farmers, and Settings / Debug, and Farm Detail is no longer a
top-level destination. Runtime screenshots then clarified the desired
interaction model: selecting a Farmers row should not open an inline detail
panel. It should only make context-aware footer actions available, matching the
pattern used by table-heavy reference mods such as TSStockCheck.

`v0.1.5.5` implements that clarified footer-action model. Selecting a Farmers
row now keeps the list as the primary surface and enables the bottom `Farm
Detail` action. Pressing that action opens a read-only Farm Detail dialog fed
by the existing `UiModels.buildFarmDetail` model. Static validation blocks both
a top-level `detailTab` and the removed inline Farmers detail panel from
returning.

`v0.1.5.6` adds the matching fast path: double-clicking a Farmers row selects
that property and opens the same read-only Farm Detail dialog as the footer
action. The footer remains the discoverable path; double-click is only a
convenience. The latest inspected log showed `FS25_PhobosRuralLedger` version
`0.1.5.5` available, but the game exited before loading the mod into a save, so
the runtime gate for the context-footer/dialog flow remains open.

Runtime testing of `v0.1.5.6` confirmed the Rural Ledger-owned log path is
clean and mission-start discovery remains map-backed, but exposed one functional
gate: the selected Farmers row could open a mismatched Farm Detail model.
`v0.1.5.7` fixed the footer action by requiring strict farm/profile identity in
`UiModels.buildFarmDetail`, but runtime testing showed the double-click shortcut
could still open a mismatched detail dialog while the footer button remained
correct. `v0.1.5.8` treats that as a dedicated gate: index `0` is no longer
treated as the first farm row, and the double-click handler resolves the clicked
row from the full SmoothList callback shape rather than from stale selected
state. Feature work stays gated until this row-to-dialog identity fix is
runtime-proven.

## Persistence Boundary

`Persistence.lua` currently owns table-shaped save state:

- schema version;
- mod version;
- seed;
- period ID;
- regional preset;
- map discovery snapshot;
- map-derived profiles, or flagged fallback profiles when discovery is
  unavailable;
- ledger snapshots;
- opportunities;
- event history;
- cooldowns.

This is deliberately not wired to FS25 save/load hooks yet. The hook path must
be verified against FS25 references before any runtime save integration is
added.

## Next Implementation Slice

Recommended next code step:

1. Runtime-test the `v0.1.5.8` double-click identity hotfix on the same
   disposable save with `FS25_PhobosLib` installed, and optionally with
   `FS25_precisionFarming`.
2. Confirm no Phobos-owned `Error:`, `Warning:`, or `Warning (` lines appear,
   especially no Rural Ledger-owned `Could not retrieve GUI profile 'button'`.
3. Verify top tabs are overview-level only, Farmers row selection only enables
   the footer `Farm Detail` action, and pressing that action opens/closes the
   read-only dialog cleanly.
4. Verify clicking or double-clicking several Farmers rows opens the same
   read-only Farm Detail dialog with matching property name, field IDs, and
   farmland IDs for each selected row.
5. Verify button, tab, settings/debug, Refresh, and footer interactions do not
   produce visible distortion.
6. Verify the tested map still shows multiple map-backed property records rather
   than one broad owner record, while still reporting the same usable field and
   farmland counts.
7. Add the first read-only cause-carrying neighbour opportunity from strained
   or worse farms only after the `v0.1.5.8` double-click runtime pass is clean.
8. Research exact Precision Farming pH/nitrogen read paths only after this
   runtime pass is clean.
9. Research and wire FS25 save/load lifecycle hooks only after the read-only
   state and opportunity data remain stable.
