# MVP Scope

## MVP Rule

Start with shadow ledgers only. Do not make NPCs physically perform every
operation at first.

The MVP succeeds if the player can read a report, understand why neighbouring
farms are under pressure, and see a small number of useful opportunities emerge
from that pressure.

## Included In MVP

- Assign each NPC farmer a profile and controlled fields.
- Estimate crop income from field size, crop type, yield quality, and price.
- Estimate operating costs from crop type, field size, and farm personality.
- Run monthly or seasonal profit/loss updates.
- Calculate farm stress scores.
- Generate report-only local economy summaries.
- Generate a small number of urgent work or neighbour-request opportunities if
  the FS25 contract path is verified.
- Save ledger snapshots and event cooldowns.

## Excluded From MVP

- Fully physical NPC field operations.
- Complex auctions.
- Deep debt servicing.
- Direct commodity price mutation.
- Direct land sale mutation before API verification.
- Custom visual UI beyond the simplest verified report path.
- Region-specific calibration beyond broad presets.

## First Development Milestones

1. Confirm load order with `FS25_PhobosLib`.
2. Add constants, profile data, and deterministic calculation modules.
3. Add save/load schema for profile and ledger state.
4. Add one debug/report output path.
5. Add one generated opportunity with a readable cause.
6. Test load, save, reload, and game log cleanliness.

## MVP Acceptance Questions

- Can a farm be profitable, strained, or distressed for understandable reasons?
- Does the player receive useful information without being flooded?
- Can a save be loaded after a tuning change?
- Does multiplayer authority remain clear?
- Can the next feature be added without rewriting the ledger model?
