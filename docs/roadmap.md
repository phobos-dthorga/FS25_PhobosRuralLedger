# Roadmap

## Phase 0: Research And Skeleton

- Keep the repo packageable and CI-validated.
- Verify FS25 save/load, mission, farmland, contract, and UI API paths.
- Decide the first persistence format before storing any real save data.
- Keep all gameplay-affecting logic out of UI code.
- Add static checks as soon as the first data files appear.

## Version 1: Shadow Ledgers And Reports

Do not try to make NPCs physically perform every operation at first.

- Assign each NPC farmer a profile and fields.
- Estimate crop income from field size, crop type, yield, and price.
- Estimate costs from crop type and field size.
- Run monthly or seasonal profit/loss updates.
- Trigger contracts, land leases, and land sales from financial condition.
- Add an economy dashboard or report.

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

## Version 3: Regional Systems

- Insurance and disasters.
- Co-ops.
- Production-chain supply and demand.
- Regional presets based on US, EU, and Australian datasets.

## Parking Lot

- Physically simulated NPC machinery and task execution.
- Full accounting-grade balance sheets.
- Deep legal/business ownership structures.
- AI-driven narrative generation beyond templated local reports.
- Complex inheritance, succession law, and family ownership modeling.

These are not rejected ideas. They are deferred until the core simulation proves
it can create good gameplay without overwhelming the player or the save.
