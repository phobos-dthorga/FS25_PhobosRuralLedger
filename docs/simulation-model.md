# Simulation Model

## Minimal Ledger

The believable first model needs only five ledgers per NPC:

- operating cash: money available this season;
- debt: machinery loans, land loans, operating loans;
- gross margin per enterprise: revenue minus direct costs;
- fixed costs: land rent, interest, depreciation, wages, maintenance;
- risk buffer: insurance, savings, crop diversity, storage, access to credit.

## Inputs

The first model can stay coarse. Each farm needs enough data to produce
believable pressure:

- fields controlled by the discovered map owner/property record;
- farmland IDs, field IDs, and contract references where available;
- enterprise mix, such as grain, dairy, livestock, contracting, or mixed;
- current crop mix, growth stage, field condition, and expected yield quality;
- optional Precision Farming pH, nitrogen, and environmental-score bands;
- operating style, such as conservative, expansionist, contractor, or
  specialist;
- debt level and interest sensitivity;
- storage capacity and selling patience;
- machinery age or maintenance burden;
- regional preset and current market pressure.

## Seasonal Profit Sketch

```text
season_profit =
    crop_revenue
  + livestock_revenue
  + contract_income
  + subsidies
  + insurance_payouts
  - seed_cost
  - fertiliser_cost
  - chemical_cost
  - fuel_cost
  - labour_cost
  - maintenance_cost
  - rent
  - interest
  - depreciation
  - tax
```

The math can stay simple while the outcomes feel complex.

## Stress Score

The ledger should produce a single stress score that downstream systems can use
without reading every accounting field.

Suggested inputs:

- negative operating cash;
- debt service above seasonal cash buffer;
- low crop diversity;
- real field-condition problems such as weeds, stones, ploughing need, poor pH,
  or low nitrogen;
- weak storage;
- repeated bad gross margins;
- recent disaster or disease event;
- poor machinery condition;
- high land rent or interest pressure.

Suggested outputs:

- `stable`: no player-facing pressure;
- `watch`: report-only warning;
- `strained`: discounted or urgent contract opportunities;
- `distressed`: lease, sale, auction, or debt-reduction behavior;
- `insolvent`: bankruptcy or receiver-style event when supported.

## Cause Before Consequence

NPCs should not lose money because a random number said so. They should lose
money because:

- a wet spring delayed planting;
- fertiliser prices rose;
- they overborrowed to buy land;
- they grew the same crop as everyone else and prices fell;
- they lacked storage and had to sell at harvest lows;
- they skipped lime, fertiliser, or maintenance and yields declined;
- disease or weather hit a crop or livestock type;
- machinery age increased repair costs;
- they sold land to reduce debt.

NPCs should succeed because:

- they diversified;
- they stored grain and sold later;
- they had low debt;
- they leased instead of buying;
- they specialised in a profitable enterprise;
- they joined a co-op;
- they invested in storage, irrigation, or soil health.

## Farm Personalities

Potential profile archetypes:

- expansionist: borrows heavily, buys land aggressively, vulnerable to interest
  and bad seasons;
- conservative: low debt, slow growth, survives downturns;
- contractor: earns money doing work for others, owns fewer fields but more
  machinery;
- livestock specialist: watches feed prices, hay availability, milk, and meat
  margins;
- absentee landowner: leases land out and rarely farms directly;
- regenerative farmer: accepts lower short-term yield for soil bonuses,
  conservation payments, or lower input costs.

## Decision Style

Every farm should have a bias, but not a script. The conservative farmer can
still expand after several good seasons. The expansionist can still sell land
when interest pressure becomes painful. The goal is personality-shaped
probability, not fixed destiny.

## Event Pipeline

1. Update regional indicators.
2. Update each farm's ledger.
3. Calculate farm stress and opportunity scores.
4. Select a small number of eligible player-facing events.
5. Attach a readable cause to each event.
6. Save event history and cooldowns.

This keeps the simulation explainable and limits noisy output.
