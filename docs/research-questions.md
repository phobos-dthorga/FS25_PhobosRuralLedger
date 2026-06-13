# Research Questions

Document uncertainties here before implementing API-sensitive features.

## FS25 Economy And Land APIs

- How can a mod inspect field ownership and land ownership safely?
- How can a mod enumerate existing map landowners/farms and correlate them with
  farmland IDs and field IDs? Provisional answer in `v0.1.5.0`: use loaded
  `g_fieldManager.fields`, field center/farmland data, `g_farmlandManager`, and
  owner farm IDs in a bounded read-only pass.
- Can land sale availability and price be changed by script?
- Can a mod add contextual annotations to contracts?
- How can a mod correlate active or completed contracts with landowner,
  farmland, and field IDs? Provisional answer in `v0.1.5.0`: active field
  missions with a readable `field` are attached by field ID.
- Can a mod create or alter contracts without breaking multiplayer?
- What is the safe server-authoritative path for economy state changes?
- Can the mod observe mission completion and reward data without replacing
  core mission logic?
- Can the mod attach additional metadata to farms, farmlands, or contracts?
- Which IDs remain stable across save reloads, map restarts, and map variants?

## Save And Multiplayer

- Which XML save hooks are available for non-placeable mod state?
- What is the current best-practice pattern for versioned save data?
- Which network event pattern should be used for UI requests and reports?
- Where should server-only ledger updates run in the FS25 lifecycle?
- How should clients request report data without mutating authoritative state?

## UI

- What is the least invasive way to expose a report screen? Current V1 answer:
  load a standalone `ScreenElement` with `g_gui:loadGui`, open it with
  `g_gui:showGui`, and provide a guarded keybinding plus settings-menu entry.
  Runtime proof showed the standalone screen can open, but the first fixed
  layout clipped on ultrawide. The `v0.1.4.0` follow-up uses FS25 menu
  containers and list widgets before adding gameplay interaction.
- Can existing menu pages be extended safely?
- Should the first version use notifications/reports instead of custom UI?
- Is there a safe way to add a market board or economy report entry point to
  existing menus?
- Can reports be exposed as read-only pages before custom interactions exist?

## Economy Data

- Which game systems expose current crop prices and price history?
- Can a mod read field crop state, growth stage, and harvest readiness safely?
- Can a mod read soil-composition flags such as weeds, needs ploughing, needs
  rolling, stones, mulched, and watered state safely? Provisional answer in
  `v0.1.5.2`: field state exposes raw crop/growth/soil fields after
  `Mission00.onStartMission`; exact gameplay interpretation remains
  conservative until runtime-tested.
- When the official Precision Farming mod is installed, can Rural Ledger read
  pH, nitrogen, environmental score, and sample freshness without taking a hard
  dependency? Still open. `v0.1.5.2` only records guarded mod availability via
  local optional-mod checks. The Soil/Fertilizer reference suggests a future
  diagnostic probe or bridge can be useful before exact pH/nitrogen values
  become player-facing.
- Can storage ownership and capacity be inspected for NPC-like profiles?
- Are NPC farms represented strongly enough in vanilla data to map ledgers onto
  them, and what fallback is acceptable when a map has fields but no useful
  owner identity?

## Local References Needed

- FS25 Community LUADOC.
- Proven FS25 mod examples for save/load and GUI.
- Local game data paths for field, farmland, contracts, and economy systems.
- Official Precision Farming integration references or proven examples.
- Farming Simulator 25 log path for test verification.

## Research Policy

If a question affects implementation, verify it before coding. If it cannot be
verified yet, keep the feature in design docs instead of writing speculative
Lua.
