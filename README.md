# FS25_PhobosRuralLedger

Farming Simulator 25 design and staging repository for **Phobos' Rural Ledger**.

## Status

This repository is the planning and implementation home for a PC-first FS25 mod
that gives NPC farmers hidden financial lives: cash flow, debt, risk, farm
personalities, and believable reasons to buy, lease, sell, request help, or
compete with the player.

The first commit is intentionally light on game logic. The goal is to capture
the design, repository shape, packaging path, and early mod descriptor before
any FS25 economy or UI API assumptions are locked in.

## Working Goals

- Model NPC farms as businesses, not random bank balances.
- Make local land, contract, and commodity activity feel connected.
- Keep the simulation causal, explainable, and save-safe.
- Expose the economy through player-facing reports, jobs, auctions, and local
  news rather than raw accounting screens only.
- Keep optional integrations guarded so standalone installs remain stable.

## Design Promise

Phobos' Rural Ledger should make the countryside feel accounted for. Every NPC
farm should have enough hidden financial state to explain why it expands,
struggles, rents land, sells land, requests contract help, joins local co-ops,
or competes with the player.

The mod should stay broad and playable rather than becoming accounting
homework. Real farm-finance categories are used to create pressure, opportunity,
and readable consequences.

## Repository Layout

- `mod/` - Farming Simulator mod source files.
- `docs/` - design notes, research questions, and implementation planning.
- `tools/` - local helper scripts for packaging and static validation.
- `.github/` - CI, issue templates, and pull request workflow files.

## Current Design Direction

Version 1 should start with shadow ledgers only:

- assign each NPC farmer a profile and land/enterprise mix;
- estimate seasonal crop income from field size, crop type, yield, and price;
- estimate costs from crop type, field size, and operating style;
- run monthly or seasonal profit/loss updates;
- trigger contracts, land leases, and land sales from financial condition;
- show a small economy dashboard or report layer.

Later versions can add debt servicing, auctions, crop-choice changes, storage
timing, co-ops, insurance, disasters, production-chain pressure, neighbour
reputation, and regional presets.

## Dependency Direction

The mod is staged to depend on `FS25_PhobosLib` for shared Phobos FS25 helpers.
Any helper that becomes useful across multiple Phobos FS25 mods should move
there instead of staying local.

## Packaging

Build a local package with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/package.ps1
```

Or run the cross-platform package set builder:

```powershell
python tools/package_set.py --validate --write-sha256 --write-json
```

## Documentation

Start with:

- `docs/README.md`
- `docs/design-brief.md`
- `docs/feature-matrix.md`
- `docs/mvp-scope.md`
- `docs/roadmap.md`
- `docs/architecture.md`
- `docs/simulation-model.md`
- `docs/event-causality.md`
- `docs/player-facing-ux.md`
- `docs/integration-strategy.md`
- `docs/naming-and-tone.md`
- `docs/research-questions.md`
- `docs/visual-assets.md`

## Author

phobosgekko

## License

This project uses dual licensing:

- **Code** (Lua scripts, XML definitions, tools, and documentation): [MIT License](LICENSE)
- **Assets** (textures, icons, images, models, and other media): [CC BY-NC-SA 4.0](LICENSE-CC-BY-NC-SA.txt)

Forks and addons are encouraged. Code is permissively licensed for integration.
Assets are protected from commercial use and must preserve attribution and
ShareAlike terms.
