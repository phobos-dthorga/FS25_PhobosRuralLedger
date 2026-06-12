# Research Questions

Document uncertainties here before implementing API-sensitive features.

## FS25 Economy And Land APIs

- How can a mod inspect field ownership and land ownership safely?
- Can land sale availability and price be changed by script?
- Can a mod add contextual annotations to contracts?
- Can a mod create or alter contracts without breaking multiplayer?
- What is the safe server-authoritative path for economy state changes?
- Can the mod observe mission completion and reward data without replacing
  core mission logic?
- Can the mod attach additional metadata to farms, farmlands, or contracts?

## Save And Multiplayer

- Which XML save hooks are available for non-placeable mod state?
- What is the current best-practice pattern for versioned save data?
- Which network event pattern should be used for UI requests and reports?
- Where should server-only ledger updates run in the FS25 lifecycle?
- How should clients request report data without mutating authoritative state?

## UI

- What is the least invasive way to expose a report screen?
- Can existing menu pages be extended safely?
- Should the first version use notifications/reports instead of custom UI?
- Is there a safe way to add a market board or economy report entry point to
  existing menus?
- Can reports be exposed as read-only pages before custom interactions exist?

## Economy Data

- Which game systems expose current crop prices and price history?
- Can a mod read field crop state, growth stage, and harvest readiness safely?
- Can storage ownership and capacity be inspected for NPC-like profiles?
- Are NPC farms represented strongly enough in vanilla data to map ledgers onto
  them, or does Rural Ledger need its own generated farm registry?

## Local References Needed

- FS25 Community LUADOC.
- Proven FS25 mod examples for save/load and GUI.
- Local game data paths for field, farmland, contracts, and economy systems.
- Farming Simulator 25 log path for test verification.

## Research Policy

If a question affects implementation, verify it before coding. If it cannot be
verified yet, keep the feature in design docs instead of writing speculative
Lua.
