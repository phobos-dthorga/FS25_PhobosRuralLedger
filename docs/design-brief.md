# Design Brief

## Working Title

**Phobos' Rural Ledger**

Subtitle candidates:

- Living farm finances for a living countryside.
- Every field has a balance. Every harvest has a cost.

## Core Concept

Give every existing NPC farmer or landowner on the loaded map a hidden business
profile where FS25 exposes the needed data. The player should feel that
neighbouring farms have cash flow, debt, risk habits, real properties, and real
reasons for the decisions they make.

The mod should become the backbone of a living local farm economy where land
ownership, contracts, leases, prices, auctions, and relationships are connected.

## Plausible FS25 Shape

Treat Rural Ledger as a scripted PC-first mod unless a feature can be kept fully
data/placeable based. Console release is not a near-term design target because
scripted economy and UI behavior would need GIANTS and ModHub validation.

The initial implementation should avoid deep hooks until the relevant FS25 APIs
are verified. The design can still be ambitious, but early code should be
modest, testable, and reversible.

## What It Is

- A shadow economy model for NPC farms.
- A source of contextual contracts, reports, land pressure, and neighbour
  opportunities.
- A way to make existing field ownership, crop state, soil state, and local
  production feel connected.
- A design base for future Phobos FS25 cross-mod tie-ins.

## What It Is Not

- A full real-world accounting simulator.
- A promise that NPCs physically drive every operation.
- A random event pack with unexplained penalties.
- A replacement for FS25's core economy until specific API paths are proven.

## NPC Farm Profile Axes

- Farmer identity: small family farm, large contractor, dairy operator, grain
  grower, struggling beginner, wealthy landholder.
- Assets: map-derived owned fields, rented fields, storage, livestock,
  abstracted machinery, and possibly production sites.
- Income: crop sales, livestock sales, contracts, government support, insurance
  payouts, rent, and production-chain income.
- Costs: seed, fertiliser, lime, fuel, labour, repairs, land rent, loan interest,
  depreciation, transport, and crop losses.
- Risk: drought exposure, debt level, crop diversity, storage capacity, machinery
  age, and soil productivity.
- Behaviour: risk-averse, expansionist, co-op minded, aggressive bidder,
  conservation-focused, debt-heavy.

## Player Impact

The economy should affect the player in visible, believable ways:

- distressed farms offer urgent contract work;
- debt-heavy neighbours sell or lease land;
- wealthy neighbours bid hard at auction;
- local crop oversupply can soften commodity prices;
- co-op participation can unlock better logistics or discounts;
- reputations can influence leases, contracts, and access to shared equipment.

## Strongest Gameplay Ideas

Dynamic land ownership is the strongest first feature. Land should not simply
sit for sale forever at a fixed price. Every NPC farmer should have a reason to
hold, lease, expand, subdivide, or sell.

That ambition depends on a map-first property model. Rural Ledger should assess
the landowners and fields already present in the world, then layer finance and
behaviour on top of them. It should not invent disconnected farms as the
primary design model.

Contracts with context are the second strongest feature. A harvest job is more
interesting when it is "Miller Farm is short on cash after a poor soybean year"
than when it is just another anonymous field job.

A local market board is the third strong feature. It can show regional
indicators such as grain oversupply, hay shortage, milk margin, diesel price,
fertiliser index, bank lending mood, land demand, and NPC stress.

## Player Fantasy

The player should feel like they are farming inside a local economy rather than
beside static field owners. A good session might include reading a bank note
about tightening credit, accepting an urgent harvest job from a stressed
neighbour, noticing that hay demand is high, and deciding whether to save cash
for a possible land auction.

## Design North Star

The mod should feel grounded and serious, not like a random-event pack. It
should quietly keep account of every farm's fate.
