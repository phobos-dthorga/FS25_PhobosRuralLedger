# Player-Facing UX

The simulation should be visible through diegetic reports and practical
decisions, not only through internal numbers.

## Output Ideas

- Local newspaper: "Hansen Farm sells 12 ha after poor canola season."
- Auction board: upcoming land and equipment auctions.
- Bank report: credit conditions tightening or loosening.
- Co-op bulletin: high demand for hay, milk, maize silage, straw, or slurry
  hauling.
- Neighbour requests: "Can you finish harvest before Friday?"
- Annual farm rankings: most profitable, most indebted, biggest landholder,
  fastest-growing business.
- Map economy dashboard: land values, average debt, crop mix, commodity
  pressure, farm failures, and co-op demand.

## Dashboard Sections

The first dashboard should be compact and decision-focused. The detailed screen
roadmap lives in `ui-screen-plan.md`; this page captures the player-facing
style and information rules.

- local market mood;
- land demand and recent listings;
- bank lending mood;
- top commodity pressure;
- farms under visible stress;
- active neighbour requests;
- annual summary when the season turns over.

Avoid exposing every internal variable. Show enough to make the player believe
the simulation and decide what to do next.

## Screen Principle

Overview tells the player what matters. Farm Detail tells them why.
Opportunities tell them what they can do. History proves the world remembers.

Exact accounting values should stay hidden unless debug visibility is enabled.
Public screens should prefer bands such as cash position, debt pressure, margin
trend, storage pressure, and risk buffer.

## Report Detail Pattern

Every generated report should answer four questions:

- what happened;
- which farm or market caused it;
- why it happened;
- what the player can do before it expires.

Example shape:

```text
Miller Farm is requesting urgent barley harvest support.
Reason: weak operating cash after last season's soybean loss.
Opportunity: premium harvest contract available for 3 days.
Relationship: completion improves Miller Farm reputation.
```

## Tone

The UI should feel like local rural finance, not a spreadsheet bolted onto the
game. Reports should be concise, believable, and actionable.

## Action Surfaces

Likely player entry points:

- an economy report screen;
- contract list annotations;
- land sale notices;
- auction notices;
- neighbour bulletin messages;
- co-op board;
- annual summary report.

## Accessibility And Clarity

The player should always be able to answer:

- why did this event happen;
- what can I do about it;
- what risk or opportunity does it create;
- when does it expire.

## Text Style

- Prefer local, practical wording over abstract economic labels.
- Use farm names and field numbers when available.
- Keep report titles short.
- Mention the cause in plain language.
- Avoid jokes in event text. The mod can have personality without breaking the
  serious simulation tone.
