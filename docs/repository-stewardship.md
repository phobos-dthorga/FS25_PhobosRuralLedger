# Repository Stewardship

## Branching

Use `main` for the current working baseline until development branches become
useful. Once releases begin, keep release commits narrow and avoid unrelated
cleanup in the same change.

## Commits

Prefer small commits with messages that describe the gameplay or tooling reason.

Examples:

- `Add first ledger model docs`
- `Validate mod descriptor source files`
- `Add economy report design notes`

## Issues

Use issues for:

- API research tasks;
- design decisions;
- test findings;
- balance notes;
- release blockers.

## Releases

Each shipped mod version should get a GitHub release. Keep old releases so the
project timeline remains visible.

## Performance Gate

If a hard miss is discovered, new feature work stops in this repository until
the target is met again. Allowed work is limited to fixing, measuring,
documenting, splitting, or removing the cause.

Review `performance-targets.md` before feature merges and releases.
