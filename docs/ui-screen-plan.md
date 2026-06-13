# UI Screen Plan

This document turns the current Rural Ledger design notes into a staged screen
plan. The first goal is not to build every screen immediately. The goal is to
shape the data that future screens will need, keep the UI honest about what the
player should know, and avoid mixing presentation with gameplay mutation.

## Goals

- Show the living economy clearly.
- Let players drill down from map-level pressure to farm-level causes.
- Ground farms and farm detail in existing map landowners, farmlands, field
  IDs, crop state, and field condition wherever that data is available.
- Avoid turning hidden ledgers into full public accounting statements.
- Keep all gameplay mutation outside UI code.
- Keep all early screens useful even when deeper systems are still deferred.

## Design Principle

Overview tells the player what matters. Farmers lists the map-backed
properties. Farm Detail tells them why after the player selects one.
Opportunities tell them what they can do. History proves the world remembers.

## Screen Roadmap

| Phase | Screens | Purpose |
| --- | --- | --- |
| Version 1 | Overview, Farmers with Farm Detail drill-down, Settings / Debug | Read-only economy visibility, farm pressure list/detail, and diagnostics. |
| Version 2 | Market Board, Land & Auctions, Relationships, Farm Detail tabs | Playable local-economy surfaces after opportunity, land, and relationship hooks exist. |
| Version 3 | Regional Outlook, Co-op Board, Supply Chains, Disaster & Insurance, Annual Report | Regional economy office views and annual report layers before hard integrations. |

Do not add empty UI promises. A screen should appear only when the state behind
it exists or the screen is clearly marked as a debug/development surface.

Top tabs are reserved for overview-level destinations. Row-specific drill-downs
should be exposed through context-aware footer actions: selecting a row enables
the relevant bottom command, and pressing that command opens the read-only
detail surface. Double-clicking a row may invoke the same command as a
convenience, but it must not be the only way to drill down. In V1, Farm Detail
is therefore a Farmers context action, not a top-level tab or an inline
sub-panel.

## Version 1 Screens

### Overview

The Overview is the first player-facing Rural Ledger dashboard. Keep it compact
and decision-focused:

- local market mood;
- tracked farms;
- farms in trouble;
- most pressured farm type or enterprise;
- active opportunities;
- recent economy notes.

The Overview should show only enough detail to make the local economy readable.
It should not expose full ledgers or exact accounting values.

### Farmers

The Farmers screen is a sortable list of tracked map-derived farms/properties.
Suggested columns:

- farm;
- source or confidence, when useful during development;
- type;
- fields or farmland IDs;
- stress;
- main pressure;
- opportunity;
- relationship.

Suggested filters:

- all farms;
- under watch, strained, or distressed;
- farms with active opportunities;
- relationship farms.

Suggested sorts:

- stress high to low;
- farm name;
- field count;
- relationship;
- opportunity expiry.

### Farm Detail Drill-Down

Farm Detail explains why a single farm is doing well or struggling. It appears
only after selecting a Farmers row and pressing the footer `Farm Detail`
action, or by double-clicking a row as a shortcut to that same action. Farmers
stays selected in the top navigation, and returning from the dialog restores
the list unchanged.
Suggested sections:

- summary: farm name, type, stress state, and primary pressure;
- financial health: public bands for cash position, debt pressure, revenue,
  costs, and risk buffer;
- land: controlled field count, farmland IDs, field IDs, approximate land
  pressure, and likely land action when that system exists;
- crop plan: current crops, growth state, field condition, market exposure, and
  likely future shift;
- field condition: weeds, ploughing, rolling, stones, mulching, watering, and
  optional Precision Farming pH/nitrogen summaries when available;
- relationship: status, trust effect, and what improves or harms it;
- opportunities: active opportunity cards;
- history: season notes and event memory.

### Settings / Debug

Settings / Debug is a development-safe access path for diagnostics:

- manual report refresh;
- debug visibility toggle;
- current period and seed;
- raw state preview for developers;
- log/report diagnostics.

Exact internal values belong here only, and only when debug visibility is
enabled.

## Version 2 Screens

### Market Board

Market Board should make local demand and pressure visible after the underlying
systems exist:

- commodity mood;
- input pressure;
- local demand;
- opportunity cards;
- contract notes.

It can start as a read-only board and later become the place where market-driven
opportunities are accepted.

### Land And Auctions

Land and auction screens should wait until Rural Ledger can produce real land
pressure, distress leads, auction warnings, and history. Do not show speculative
listings unless they come from saved or reproducible state.

### Relationships

Relationships should expose trust, neighbour reputation, favours, private
opportunities, and warnings that the player has earned through prior help.

### Farm Detail Tabs

Farm Detail can grow tabs only after the base screen earns them:

- summary;
- finance;
- land;
- crop plan;
- relationship;
- history;
- opportunities.

## Version 3 Screens

### Regional Outlook

Regional Outlook summarizes the broader local economy:

- regional mood;
- dominant enterprise;
- input cost index;
- government support or subsidy pressure;
- land market trend;
- seasonal pressure theme.

### Co-op Board

Co-op Board should create choices through institutional channels, not random
popup errands:

- local demand;
- shared services;
- community notes;
- bulk hauling or storage needs;
- reputation-gated requests.

### Supply Chains

Supply Chains can show demand, status, and cause for local production pressure.
Example rows might include dairy demand, biogas manure demand, grain storage
pressure, or cold-storage shortage.

### Disaster And Insurance

Disaster and insurance screens should explain seasonal events, affected
enterprises, risk notes, insurance buffers, co-op buffers, and available player
actions.

### Annual Report

Annual Report should summarize the remembered year:

- farms that improved or deteriorated;
- bankruptcies, sales, or distress events;
- land movement;
- largest opportunity themes;
- relationship consequences;
- regional pressure trend.

## View Model Boundary

Build UI models before building FS25 GUI screens. These models should be plain
Lua tables that can be tested without FS25 UI APIs.

Initial builders:

```lua
UiModels.buildOverview(state, options)
UiModels.buildFarmList(state, options)
UiModels.buildFarmDetail(state, farmId, options)
```

Later builders:

```lua
UiModels.buildMarketBoard(state, options)
UiModels.buildOpportunities(state, options)
```

Rules:

- UI models return read-only display tables.
- UI models do not mutate Rural Ledger state.
- UI models do not call GUI APIs.
- UI models do not directly create contracts, change reputation, alter land, or
  modify ledgers.
- GUI adapters render UI models and delegate actions back to gameplay services.

Suggested data flow:

```text
state -> UiModels.buildOverview(state) -> GUI adapter renders cards
state -> UiModels.buildFarmList(state) -> GUI adapter renders table rows
state -> UiModels.buildFarmDetail(state, farmId) -> GUI adapter renders sections
```

## Suggested View Models

### FarmUiSummary

```lua
{
    farmId = "npc_farm_03",
    displayName = "Miller Farm",
    profileLabel = "Grain Grower",
    stressState = "strained",
    stressTrend = "worsening",
    primaryPressure = "Weak season margin",
    visiblePressureBand = "Debt pressure heavy",
    source = "map",
    fieldIds = { 170, 171 },
    cropMix = "Wheat, barley",
    relationshipBand = "neutral",
    activeOpportunityCount = 1,
    nextOpportunityHint = "Harvest support may appear this period",
    lastNote = "Barley margin compressed by high input costs"
}
```

### FarmDetailView

```lua
{
    farmId = "npc_farm_03",
    displayName = "Miller Farm",
    profileLabel = "Grain Grower",
    status = {
        stressState = "strained",
        trend = "worsening",
        headline = "Miller Farm is under margin pressure."
    },
    explanation = {
        mainCause = "Weak season margin",
        supportingCauses = {
            "Debt service is heavy",
            "Storage limits selling options",
            "Field 170 has low nitrogen"
        },
        playerMeaning = "Urgent contract work may appear this period."
    },
    property = {
        source = "map",
        farmlands = { 170 },
        fields = { 170, 171 },
        cropSummary = "Wheat and barley",
        fieldCondition = "One field needs rolling",
        precisionFarming = "pH good, nitrogen low"
    },
    ledgerEstimate = {
        cash = "tight",
        revenue = "moderate",
        costs = "high",
        debt = "heavy",
        riskBuffer = "low"
    },
    opportunities = {},
    history = {}
}
```

### OpportunityView

```lua
{
    opportunityId = "opp_0007",
    farmId = "npc_farm_03",
    title = "Urgent barley harvest support",
    reason = "Weak operating cash after a poor margin period.",
    actionText = "Accept harvest work",
    expiresText = "Expires in 3 days",
    relationshipText = "Improves Miller Farm reputation",
    severity = "strained"
}
```

Opportunity records should use saved `causeCode`, `reason`, `sourcePeriod`, and
`expiresPeriod` so the UI can explain them after reload without recalculating
the original trigger.

## Visibility Rules

### Public Information

Always visible:

- farm name;
- farm type;
- general stress state;
- primary visible pressure;
- fields controlled;
- active public opportunities;
- recent public events.

### Relationship-Gated Information

Visible when the player has helped that farm or earned trust:

- more precise cash and debt bands;
- likely land decisions;
- private lease offers;
- early warning before auction;
- better explanation of crop-choice changes.

### Debug / Developer Information

Visible only in debug mode:

- exact operating cash;
- exact total debt;
- exact stress score;
- exact pressure score composition;
- raw opportunity cause codes;
- cooldown keys;
- save schema fields.

## Refresh Rules

- Build on save load.
- Rebuild after period simulation.
- Rebuild after an accepted opportunity.
- Rebuild on manual refresh.
- Never recompute full ledgers per frame.

The UI should consume cached or recently generated state. Expensive farm,
field, vehicle, placeable, fillType, and active-mod scans remain prohibited in
per-frame paths.

## Recommended Build Order

1. Add Version 1 text models: `UiModels.buildOverview`,
   `UiModels.buildFarmList`, and `UiModels.buildFarmDetail`.
2. Refactor report formatting so `Reports.lua` can consume UI models instead
   of assembling every display line directly from raw state.
3. Add a developer/debug report screen path, even if it begins as bounded log
   output or a simple message surface.
4. Add a simple visual Rural Ledger screen with Overview, Farmers, and selected
   Farm Detail drill-down only.
5. Add opportunity cards using saved cause and expiry data.
6. Add Version 2 tabs only after gameplay hooks are real.
7. Add Version 3 regional screens as report layers before hard integrations.

## Version 1 Implementation Note

`v0.1.3.0` implemented the first pass through steps 1-4: read-only UI models,
report consumption of those models, and a native Rural Ledger screen with
Overview, Farmers, Farm Detail, and Settings / Debug.

`v0.1.4.0` repairs the first runtime UI findings. The screen should use
FS25-native menu containers, `SmoothList` tables, sliders, stretching profiles,
and `$l10n_...` labels instead of a fixed 1520px absolute-position canvas.
Farmers is list-backed, farm detail/debug output is list-backed, and compact
farm-table columns hide lower-priority Type/Relationship fields on narrower
containers. The reusable GUI-loading pattern remains a future `FS25_PhobosLib`
candidate only after more than one Phobos FS25 mod needs it.

`v0.1.5.4` removed Farm Detail from the overview-level top tabs. Runtime UI
review then clarified that selected-property drill-downs should behave like
context-aware bottom commands, not inline sub-panels. `v0.1.5.5` keeps the
read-only data model, keeps Farmers as the primary table, enables a footer
`Farm Detail` action after row selection, and opens detail in a dialog.
`v0.1.5.6` adds a double-click shortcut for that same dialog so players do not
need to move the pointer to the footer every time.
`v0.1.5.7` tightens row-to-dialog identity: a detail model is only produced for
the exact selected farm/profile, and the Farmers table uses the documented
SmoothList double-click callback path.
`v0.1.5.8` narrows that further after runtime testing: the footer action stayed
correct, but double-click needed to resolve the clicked row from the full
SmoothList callback arguments and ignore index `0` header/non-row events.

The next model correction is map-first ownership. Current V1 UI data is still
fallback-generated while the FS25 landowner, farmland, field, contract, and
Precision Farming API paths are researched. Future UI rows should migrate to
map-derived owner/property records before Rural Ledger adds land, auction,
contract, or relationship gameplay effects.
