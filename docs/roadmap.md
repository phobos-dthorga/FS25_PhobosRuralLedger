# Roadmap

## Phase 0: Research And Skeleton

- Keep the repo packageable and CI-validated.
- Verify FS25 save/load, mission, farmland, contract, and UI API paths.
- Verify how to enumerate map landowners, farmlands, field IDs, crop state,
  growth state, soil flags, and optional Precision Farming data.
- Decide the first persistence format before storing any real save data.
- Keep all gameplay-affecting logic out of UI code.
- Add static checks as soon as the first data files appear.

## Version 1: Shadow Ledgers And Reports

Do not try to make NPCs physically perform every operation at first.

- Discover existing landowners/properties from the current map where FS25 APIs
  expose them.
- Assign each discovered landowner a Rural Ledger profile overlay and attach it
  to their real farmlands and field IDs.
- Estimate crop income from actual field size, crop type, growth state, yield,
  and price.
- Estimate costs from crop type, field size, field condition, and optional
  Precision Farming pH/nitrogen context when available.
- Run monthly or seasonal profit/loss updates.
- Trigger contracts, land leases, and land sales from financial condition only
  after the related map owner/property and FS25 hook paths are proven.
- Add read-only UI models for Overview, Farmers, and Farm Detail before custom
  FS25 screen work.
- Add an economy dashboard or report that consumes those models where possible.

Version 1 should be useful even if it only reports pressure and creates limited
opportunities. The success test is whether the player understands why nearby
farms are doing well or struggling.

## Version 1.1: Contextual Opportunities

- Add templated local news items.
- Add urgent work requests from stressed farms.
- Add soft market-board indicators such as land demand, input pressure, and
  commodity pressure.
- Add cooldowns so the same farm does not spam the same event.
- Add player-readable reasons to every generated opportunity.

## Version 2: Debt And Market Pressure

- Loans, interest, and debt servicing.
- Auctions and bidding pressure.
- Crop-choice changes.
- Storage and delayed selling.
- Neighbour reputation.
- More direct pressure on contract rewards and land availability.
- Market Board, Land & Auctions, Relationships, and expanded Farm Detail tabs
  only after the underlying hooks and saved state exist.

## Version 3: Regional Systems

- Insurance and disasters.
- Co-ops.
- Production-chain supply and demand.
- Regional presets based on US, EU, and Australian datasets.
- Regional Outlook, Co-op Board, Supply Chains, Disaster & Insurance, and Annual
  Report screens as report layers before hard integrations.

## Parking Lot

- Physically simulated NPC machinery and task execution.
- Full accounting-grade balance sheets.
- Deep legal/business ownership structures.
- AI-driven narrative generation beyond templated local reports.
- Complex inheritance, succession law, and family ownership modeling.

These are not rejected ideas. They are deferred until the core simulation proves
it can create good gameplay without overwhelming the player or the save.
