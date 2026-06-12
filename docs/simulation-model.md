# Simulation Model

## Minimal Ledger

The believable first model needs only five ledgers per NPC:

- operating cash: money available this season;
- debt: machinery loans, land loans, operating loans;
- gross margin per enterprise: revenue minus direct costs;
- fixed costs: land rent, interest, depreciation, wages, maintenance;
- risk buffer: insurance, savings, crop diversity, storage, access to credit.

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
