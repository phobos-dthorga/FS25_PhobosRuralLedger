# FS25_PhobosRuralLedger Agent Notes

These notes guide AI/code-agent work in this repository.

## FS25 API Rule

Do not guess FS25 Lua APIs from memory. Before adding or changing any FS25 Lua
API call, class usage, lifecycle hook, specialization, GUI call, save/load call,
network event, economy call, or placeable interaction, verify against local FS25
references or proven source examples.

If local references are not yet configured for this repository, pause and ask
for their location before implementing API-sensitive code.

## Current Scope

This repository is the staging home for **Phobos' Rural Ledger**, a PC-first
Farming Simulator 25 economy simulation mod. The core idea is hidden NPC farm
ledgers that produce believable land, contract, debt, auction, reputation, and
commodity-pressure events.

## Dependency Rule

This mod should depend on `FS25_PhobosLib` for shared helpers. Move reusable
logging, mod detection, XML, save/load, compatibility, and small utility code
into `FS25_PhobosLib` once it is useful to more than one Phobos FS25 mod.

## Architecture Preferences

- Keep `modDesc.xml` as the explicit entry point for Lua source files.
- Prefer a small loader/bootstrap and focused modules loaded in dependency
  order.
- Keep economy/business rules separate from UI and reports.
- Use constants for mod IDs, save keys, tuning values, event names, report
  identifiers, and integration IDs.
- Keep simulation state server-authoritative.
- Treat multiplayer and save/load compatibility as first-class concerns.
- Prefer data-driven profile definitions over scattered hard-coded branches.
- Keep optional integrations guarded by active mod and runtime capability
  checks.
- Add cleanup paths for any hook, event, or global state installed by the mod.

## Design Discipline

- Keep the simulation causal. NPCs should struggle or succeed because of debt,
  yields, commodity pressure, weather, storage, specialization, or operating
  choices, not unexplained random penalties.
- Keep the first playable version modest. Shadow ledgers, land pressure,
  contract context, and a readable economy report are more valuable than a huge
  accounting system.
- Avoid UI-first mutation. UI and report surfaces may display data and delegate
  actions, but authoritative state changes belong in shared gameplay services.
- Document every FS25 API uncertainty in `docs/research-questions.md` instead
  of filling gaps with invented calls.

## Local References To Configure

Add project-specific paths here once available:

- FS25 Community LUADOC:
- FS25 Lua scripting examples:
- Farming Simulator 25 mods folder:
- Farming Simulator 25 log file: `D:\synologydrive\phobosdthorga\cloudstation drive\google drive\gekko-data\Documents\My Games\FarmingSimulator2025\log.txt`
- GIANTS Editor:

## Implementation Discipline

- Check the game log after test launches.
- Run `python tools/package_set.py --validate --write-sha256 --write-json`
  before proposing a release.
- Prefer narrow commits with clear messages.
- Avoid direct pushes to stable branches once a development branch workflow is
  introduced.
