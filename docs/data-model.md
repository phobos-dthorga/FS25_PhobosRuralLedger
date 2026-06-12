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
co_op_status
succession_stage
```

Profile values should be stable across saves. If generated procedurally, the
seed and schema version should be saved so tuning changes do not unexpectedly
rewrite a farm's identity.

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
stress_state
primary_pressure
last_updated_period
```

The snapshot is a summary, not a full accounting journal. It should be compact
enough to save for every NPC farm without creating save bloat.

## Opportunity

```text
opportunity_id
farm_id
type
reason
cause_code
source_period
expires_period
player_visible
effects
cooldown_key
relationship_effect
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

Opportunity records should carry enough cause data to render a report after
reload. Do not rely on recalculating the exact reason from current state.

## Event History

```text
event_id
farm_id
period_id
event_type
cause_code
summary_key
impact_score
cooldown_key
```

History is useful for annual reports, cooldowns, and avoiding repetitive
messages. Keep it bounded by period count or max record count.

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

## Derived Market Indicators

```text
period_id
commodity_pressure
land_demand
credit_mood
input_cost_index
weather_pressure
co_op_demand
production_chain_pressure
```

These values can feed reports and opportunities without exposing every internal
ledger field.
