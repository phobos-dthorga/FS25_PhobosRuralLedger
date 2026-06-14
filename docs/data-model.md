# Data Model

This document captures candidate data structures. Names are placeholders until
the FS25 save/load path is verified.

## Map Property Profile

Map property data is the source of truth for which farms/properties exist.
Rural Ledger profile and finance data should attach to these records.

```text
profile_id
source
map_id
owner_id
owner_display_name
farmland_ids
field_ids
contract_refs
field_state_summary
precision_farming_summary
discovery_confidence
fallback_reason
```

`source` should be `map` for records discovered from FS25 map data and
`fallback` only when the runtime API path cannot yet provide a real owner. A
fallback record may keep the UI testable, but it should not drive land,
auction, contract, or ownership changes.

Stable IDs should prefer FS25 map identifiers: owner/farm ID, farmland ID,
field ID, and contract/mission ID. Generated IDs are acceptable only as local
wrappers around those sources or as clearly flagged fallback state.

## Farm Profile

```text
farm_id
profile_id
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

Profile values should be stable across saves and should attach to a map
property profile. If generated procedurally, the seed, schema version, and
source map IDs should be saved so tuning changes do not unexpectedly rewrite a
farm's identity.

## Field State Summary

```text
field_id
farmland_id
area_ha
crop_type
growth_state
is_cultivated
needs_plowing
needs_rolling
has_weeds
has_stones
is_mulched
is_watered
precision_farming_available
nitrogen_band
ph_band
environmental_score_band
last_discovered_period
```

Field state summaries are read-only inputs. They should be rebuilt from the
current map on bounded refresh points and then cached for ledgers, reports, and
UI models.

## Ledger Snapshot

```text
farm_id
profile_id
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

`v0.1.6.0` persists the compact public subset: `opportunity_id`,
`farm_id`, `type`, `reason`, `cause_code`, `source_period`,
`expires_period`, `player_visible`, `severity`, and `cooldown_key`.
Profiles and ledger snapshots are rebuilt from the live map and then the saved
opportunities are reconciled to current farm IDs.

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

## Job Request

```text
request_id
source
npc_key
npc_name
farm_id
farmland_id
field_id
mission_id
contract_type
title
reward_text
status
launchable
relationship_effect
```

`v0.1.8.0` rebuilds job requests from runtime data after map/mission-ready
refresh. BetterContracts-enriched missions are preferred when available,
vanilla field missions are the fallback, and Rural Ledger-generated requests
fill NPC/property gaps without becoming launchable contracts.

`v0.1.8.1` keeps job requests read-only but enriches their UI-facing detail
shape where runtime data exists: estimated field area, profit, work time,
profit per minute, usage or lease cost, delivery/keep hints, and
BetterContracts monthly jobs-left status. Generated Rural Ledger requests keep
stable internal type codes but must be rendered through localized player-facing
labels in UI models.

Live mission/contract objects must never be saved. Persist only local history,
relationship overrides, and compact identifiers that can be reconciled against
the next runtime discovery pass.

## Newspaper State

`v0.1.9.0` adds optional newspaper state to the dedicated Rural Ledger XML:

```text
last_delivered_day
last_checked_day
last_checked_minute
pending_edition_id
editions[0..6]
```

Each archived edition stores only compact, player-facing text:

```text
edition_id
day
delivery_minute
dateline
masthead
headline
summary
sections[0..7].title
sections[0..7].body
```

The newspaper is generated from existing Rural Ledger state and remains
informational. It must not persist live contract objects, field manager
objects, GUI objects, or any mutable gameplay state beyond its own archive and
pending-delivery marker. Missing newspaper nodes are valid and mean the save
has no delivered editions yet.

`v0.1.9.1` treats the first valid clock read after loading as a baseline only.
An edition is created only when a later clock read crosses 06:00. Existing
`v0.1.9.0` editions remain in the archive, but stale pending markers from that
version are cleared on load so accidental load-screen papers do not reopen.

## Relationship Override

```text
relationship_key
score
last_changed_period
```

Relationship overrides are Rural Ledger-local. A successful linked job raises
the score by one band, while failed, cancelled, or timed-out linked jobs lower
it by one band. Scores are clamped from 1 to 5 and do not currently alter
vanilla or BetterContracts rewards, discounts, land prices, or mission lists.

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

`v0.1.8.0` also stores bounded job-history records with request ID, NPC key,
field/farmland identifiers, status, relationship delta, and a compact message.

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
