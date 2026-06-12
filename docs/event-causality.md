# Event Causality

## Principle

Rural Ledger events should feel earned. The simulation may use probability, but
the player-facing result must have a cause in the ledger, regional preset, or
recent history.

## Bad Pattern

```text
Random roll says Farm 4 lost money.
Farm 4 sells land.
```

This is not acceptable because it gives the player no believable chain of
events.

## Good Pattern

```text
Fertiliser index rose.
Miller Farm has high debt and low cash buffer.
Soybean margin falls below the farm's safe threshold.
Miller Farm enters strained status.
The report board offers urgent harvest work with a premium.
```

The player does not need every number, but the report should expose the plain
reason.

## Cause Categories

- Weather or disease pressure.
- Input cost pressure.
- Debt and interest pressure.
- Crop oversupply or poor price.
- Storage shortage and forced harvest-time sale.
- Machinery age or maintenance cost.
- Low crop diversity.
- Weak yield from skipped lime, fertiliser, or soil care.
- Land expansion at the wrong time.
- Strong specialization during a favorable market.
- Co-op access, storage, or better logistics.

## Event Outputs

| Cause | Internal result | Player-facing output |
| --- | --- | --- |
| Low cash before harvest | Strained status | Urgent harvest, baling, transport, or spraying work |
| High debt and weak margin | Distressed status | Lease offer, land sale rumor, or auction warning |
| Local oversupply | Commodity pressure | Market board warning and lower enthusiasm for that crop |
| Hay shortage | Demand pressure | Co-op bulletin, hauling request, or premium supply job |
| Strong storage and patience | Resilient status | Annual ranking or quiet success note |
| Good relationship | Trust flag | Better contract terms or exclusive notice |
| Aggressive auction behavior | Relationship penalty | Colder neighbour interactions |

## Design Guardrails

- Every event needs a `reason` field.
- Every event needs a cooldown.
- Repeated failures should escalate gradually.
- Events should be limited per period so the player is not flooded.
- Randomness may choose among eligible events, but it should not invent the
  underlying cause.
