# Performance Targets

These targets apply to `FS25_PhobosRuralLedger`. They intentionally match the
house style used by the Phobos FS25 repos so performance misses are handled
consistently.

## Freeze Rule

If a hard miss is found, new feature development stops in this repository.
Allowed work is limited to fixing, measuring, documenting, splitting, or
removing the cause. Feature work resumes only after the repo is back at target
or below.

The freeze applies to this repo when Rural Ledger causes the miss. It does not
freeze unrelated Phobos FS25 repos.

## Log Health

- Release candidates must have no Phobos-owned `Error:` lines.
- Release candidates must have no Phobos-owned `Warning (` lines.
- Development builds must not produce repeated Phobos-owned runtime warnings.
- Any temporary known line must be documented in `known-log-lines.md` with
  owner, cause, status, and removal condition.

Phobos-owned means the line clearly points at `FS25_PhobosRuralLedger`,
`PhobosRuralLedger`, this repository's files, or shared helpers called by this
mod.

## Load Impact

- Target: less than 5 seconds added load time, or less than 10 percent over the
  baseline save.
- Hard miss: more than 10 seconds added load time, or more than 20 percent over
  baseline.

Measure baseline and Rural-Ledger-enabled loads on the same map, save,
hardware, and mod set except for the package being tested.

## Simulation Cadence

Hard misses:

- unbounded per-frame scans of all farms, fields, vehicles, placeables,
  fillTypes, active mods, or productions;
- per-frame ledger recomputation for every NPC farm;
- repeated active-mod or fillType scans that could be cached or scheduled;
- repeated warning logs from missing optional integrations.

Rural Ledger should run financial simulation on bounded lifecycle points such
as load, month/season transition, explicit report refresh, or future scheduled
economy ticks. It should not become a hidden per-frame accounting engine.

## Report And UI Work

- MVP report generation should stay bounded to the configured NPC farm set.
- Default report views should remain small and readable.
- Future high-farm-count, large-map, or production-chain reports need a
  measurement note before release.

## Save Data

- Target: custom Rural Ledger save data stays under 50 KB for normal MVP saves.
- Hard miss: unbounded save data growth, duplicated history entries, or save
  files that grow every load/save cycle without new game state.

History should be capped or summarized before it becomes a normal release
feature.

## Package Size And Assets

- Soft target: XML/Lua/package-light releases stay under 1 MB.
- Any intentional asset growth must be documented before release.
- DDS/icon raw-format warnings for Phobos-owned assets are hard misses.

## PR And Release Gate

Every PR and release review must answer:

- Are log-health targets met?
- Are load-impact targets met or unchanged?
- Are simulation loops bounded?
- Is save data bounded?
- Is the package still light, or is asset growth intentional and documented?
- Is there any hard miss that freezes new feature work?
