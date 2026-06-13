# MVP Scope

## MVP Rule

Start with shadow ledgers only. Do not make NPCs physically perform every
operation at first.

The MVP succeeds if the player can read a report, understand why neighbouring
farms are under pressure, and see a small number of useful opportunities emerge
from that pressure.

## Included In MVP

- Discover existing map landowners/properties where the FS25 APIs expose them.
- Assign each discovered landowner a Rural Ledger profile overlay and controlled
  field list.
- Estimate crop income from actual field size, crop type, growth state, yield
  quality, and price.
- Estimate operating costs from crop type, field size, field condition, and farm
  personality.
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

1. Confirm Rural Ledger loads as a self-contained FS25 mod.
2. Add constants, profile data, deterministic calculation modules, and a
   fallback profile registry.
3. Prove a read-only map discovery path for landowners, farmlands, fields,
   contracts, and field state.
4. Add save/load schema for map-derived profile and ledger state.
5. Add one debug/report output path.
6. Add one cause-carrying opportunity tied to a discovered property if the FS25
   contract path is verified.
7. Test load, save, reload, and game log cleanliness.

## MVP Acceptance Questions

- Can a farm be profitable, strained, or distressed for understandable reasons?
- Is each displayed farm/property tied to the current map, or clearly marked as
  fallback while API research continues?
- Does the player receive useful information without being flooded?
- Can a save be loaded after a tuning change?
- Does multiplayer authority remain clear?
- Can the next feature be added without rewriting the ledger model?
