# Data Model

This document captures candidate data structures. Names are placeholders until
the FS25 save/load path is verified.

## Farm Profile

```text
farm_id
display_name
profile_type
owned_fields
leased_fields
enterprise_mix
storage_rating
machinery_rating
debt_attitude
risk_attitude
relationship_score
```

## Ledger Snapshot

```text
farm_id
period_id
operating_cash
total_debt
interest_due
gross_revenue
direct_costs
fixed_costs
risk_buffer
season_profit
stress_score
```

## Opportunity

```text
opportunity_id
farm_id
type
reason
expires_period
player_visible
effects
cooldown_key
```

Example opportunity types:

- urgent contract;
- discounted transport or baling work;
- lease offer;
- land sale;
- auction;
- co-op request;
- reputation favour;
- distress purchase.

## Regional Preset

```text
preset_id
label
commodity_biases
cost_indices
land_pressure
interest_pressure
subsidy_style
disaster_profile
```

Regional presets should be broad, not precise. They exist to make a US Midwest,
Australian broadacre, EU mixed farming, Alpine dairy, or rice-region map feel
different without turning the mod into accounting homework.
