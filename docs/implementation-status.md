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
- Farm Detail as a selected-property footer action/dialog, not as a top-level
  overview tab;
- read-only public opportunity candidates generated from map-backed strained
  or worse properties;
- context-aware `Opportunities` footer action and read-only opportunities
  dialog;
- compact dedicated save XML persistence for opportunities, cooldowns, and
  bounded event history;
- self-contained local helper paths for logging, translation fallback,
  optional mod detection, save path resolution, and XMLFile access;
- read-only property History dialog backed by bounded event history;
- debug-only ledger period advancement foundation for save/reload and history
  testing;
- first playable NPC Jobs tab, grouped by NPC or plot, with live-contract rows
  discovered from BetterContracts when available or vanilla contracts
  otherwise;
- Rural Ledger-generated non-launchable gap-fill job requests for NPCs/plots
  without a live contract;
- context-aware `Job Detail` and `Start Contract` footer actions;
- live contract start through the normal `MissionStartEvent` path without
  leased equipment;
- Rural Ledger-local relationship band overrides and bounded job history
  persisted in the dedicated save XML;
- `v0.1.8.1` footer polish where unavailable Farmers/Jobs actions are hidden
  instead of shown disabled;
- localized generated job labels and overview alerts, avoiding raw internal
  keys such as `rl_overview_alert_row` or `fieldwork_support request`;
- richer read-only Job Detail rows for NPC, plot, reward, field area, status,
  relationship, start eligibility, and BetterContracts-enriched values when
  available;
- `v0.1.9.0` daily rural newspaper foundation: a 06:00 in-game delivery check,
  classic off-white newspaper dialog, top-level archive tab, and optional
  bounded newspaper save data.
- `v0.1.9.1` newspaper delivery hotfix: load/map-start checks are baseline-only,
  auto-open waits for active mission updates, and old accidental pending papers
  are kept in the archive without reopening.
- `v0.1.9.2` newspaper input hotfix: auto-delivered papers carry explicit
  dialog context and restore gameplay pointer/focus state on close, while
  archive-opened papers keep normal menu UI behavior.

## Runtime Evidence

`v0.1.0.0` was published as the first prerelease and tested with the original
shared-helper dependency installed. The refreshed FS25 log showed both mods
loading and no Phobos-owned errors or warnings.

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
availability is still detected through local guarded mod checks, but exact pH
and nitrogen values remain pending until a safe API is proven.

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

Runtime testing of `v0.1.5.8` confirmed the double-click identity fix, so
`v0.1.6.0` adds the first read-only opportunity slice. Opportunities are
generated only from map-backed properties that are strained, distressed, or
insolvent, capped at 12 active candidates, and exposed through Overview counts,
Farm Detail summaries, and a context-aware footer dialog. The save/load hook is
limited to a compact `FS25_PhobosRuralLedger.xml` file for opportunities,
cooldowns, and bounded event history; profiles and ledger snapshots remain
rebuilt from the live map and reconciled after discovery.

Runtime testing of `v0.1.6.2` confirmed the dedicated save XML is created with
the local FS25 XML adapter. That success also confirmed that the older FS25
shared-library approach was adding avoidable visibility and dependency
friction. `v0.1.7.0` therefore makes Rural Ledger self-contained, removes the
runtime dependency, keeps the working local helper paths, adds a read-only
History dialog, and adds a debug-only period advance foundation so opportunity
expiry and history can be tested before any gameplay mutation is introduced.

`v0.1.8.0` adds the first playable NPC job layer. The new Jobs tab can group
requests by NPC name or by plot, prefers BetterContracts-enriched live mission
data when that mod is detected, falls back to vanilla field missions, and fills
missing NPC/property rows with Rural Ledger-generated non-launchable requests.
The only gameplay bridge in this slice is starting an existing live contract
through `MissionStartEvent` with no leased equipment. Rural Ledger does not
create contracts, refresh/delete contract lists, mutate land, change rewards,
or write live mission objects to XML. Contract outcomes are observed through a
local `AbstractMission.finish` append and recorded as Rural Ledger relationship
band changes plus bounded job history.

Runtime testing of `v0.1.8.0` confirmed that contract discovery/start
integration is working, but exposed UI polish gates: unavailable footer actions
were visible, the Overview leaked raw l10n keys, generated job rows leaked
internal request codes, the Opportunities action could appear without useful
context, and Job Detail did not provide enough contract information before
starting a mission. `v0.1.8.1` is the targeted hotfix for that evidence.

`v0.1.9.0` adds the first daily local newspaper slice. The paper is delivered
once per in-game day at 06:00 when the clock reaches or crosses that time,
including sleep/time jumps. It auto-opens a pending edition only after the GUI
is ready, and the Newspaper tab keeps the newest seven editions for re-reading.
Articles summarize existing economy, job, opportunity, relationship/history,
and discovery data without creating contracts, paying rewards, changing land,
or mutating relationships.

Runtime testing of `v0.1.9.0` found three hard misses: a paper could deliver
and open over the loading screen from a first clock sample at 21:11, the
newspaper dialog profile referenced an unresolved `center` trait, and optional
newspaper save reads could trigger XML schema errors on existing saves.
`v0.1.9.1` changes delivery to crossing-only after an established baseline,
keeps `loadMap` and `missionStart` checks baseline-only, clears stale
`v0.1.9.0` pending auto-open state while preserving archived editions, and
hardens optional XML reads.

Runtime testing of `v0.1.9.1` confirmed the crossing-only delivery was much
better, but closing the auto-delivered newspaper could leave gameplay controls
and screen interaction captured. `v0.1.9.2` treats that as a release gate and
adds auto-delivery-only focus/pointer cleanup on close. Manual archive reads
remain ordinary Rural Ledger UI dialogs and do not force gameplay cursor state.

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
- relationship overrides;
- bounded job history.
- optional newspaper state: last delivered day, pending edition, clock
  diagnostics, and up to seven archived editions.

`v0.1.6.0` wires a narrow local save hook for opportunity state only. The hook
remains provisional until runtime save/reload proof confirms that FS25 writes
the dedicated XML file without Phobos-owned warnings or save failures.

Runtime testing of `v0.1.6.0` showed a persistence gate: the original
shared-helper package and Rural Ledger loaded cleanly, but no
`FS25_PhobosRuralLedger.xml` file was created and the log had no Rural
Ledger-owned save write, save failure, or missing-save lines. `v0.1.6.1`
therefore hardens the local save hook by retrying registration from
map/mission-ready lifecycle paths, reporting hook/path availability in
Settings / Debug, logging the exact XML path on load/write, and treating an
unavailable save path as a Phobos-owned hard miss.

Runtime testing of `v0.1.6.1` proved that the save hook fires, but load/write
still reported `xml_api_unavailable` because the shared XML wrapper was not
visible to Rural Ledger at runtime. `v0.1.6.2` fell back to the global FS25
`XMLFile` API for this dedicated save file and records the active XML adapter
in Settings / Debug. The user then confirmed the save file is created.

`v0.1.7.0` keeps the proven local save path, removes the retired shared-helper
dependency entirely, and extends the save surface only with bounded history and
debug-only period advancement.

`v0.1.8.0` extends the same XML file with relationship overrides and bounded
job history. Live contract objects are reconstructed from the current runtime
mission managers and are never persisted. `v0.1.8.1` does not change the save
shape.

`v0.1.9.0` extends the XML file with optional newspaper data. Missing
newspaper nodes are treated as an empty archive so older saves remain
compatible. `v0.1.9.1` additionally clears stale pending newspaper IDs loaded
from `v0.1.9.0`, preserving the archived paper but preventing another automatic
load-screen open.

## Next Implementation Slice

Recommended next code step:

1. Runtime-test `v0.1.9.2` by triggering an auto-delivered paper across 06:00,
   closing it, and confirming movement, camera, vehicle controls, map/menu
   buttons, and mouse interaction recover immediately.
2. Open Rural Ledger > Newspaper and re-read archived editions, confirming the
   archive dialog closes back to a usable Rural Ledger screen.
3. Confirm the paper dialog keeps its off-white newspaper layout at ultrawide
   and 1080p without clipped masthead/headline/body text.
4. Confirm the custom XML remains below the 50 KB MVP target on a normal save.
5. Confirm no Rural Ledger-owned `Error:`, `Warning:`, or `Warning (` lines
   appear. If clean, proceed to leased-equipment/borrow-flow research or a
   developer-only Precision Farming probe for exact pH/nitrogen API research.
