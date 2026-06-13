# Measurement And Automation

CI can prove package shape and syntax. FS25 runtime behavior still needs a
local launch and log review.

## Automated Checks

Run:

```powershell
python tools/package_set.py --validate --write-sha256 --write-json
```

CI also performs:

- Python tool compilation;
- Lua syntax compilation;
- package build;
- package validation;
- artifact upload.

The validator checks required performance docs, `modDesc.xml`, the absence of
the retired FS25 shared-helper dependency, referenced source files, and package
contents.

## Local Runtime Recipe

For the current smoke test:

- install `FS25_PhobosRuralLedger.zip`;
- load a disposable save;
- confirm the mod loads and initializes without Phobos-owned log errors;
- save and reload once save behavior exists;
- inspect `log.txt`.

For future savegame work, record the disposable save/load result before the
feature is considered stable.

## Load-Time Measurement

Record:

- map and save name;
- FS25 game version;
- enabled mods;
- package version or commit;
- baseline load time;
- Rural-Ledger-enabled load time;
- added seconds and percent over baseline.

Use the same save and mod set except for Rural Ledger.

## Log Triage

Search for:

- `Error:`
- `Warning (`
- `FS25_PhobosRuralLedger`
- `PhobosRuralLedger`
- retired FS25 shared-helper dependency names

Classify each Phobos-owned line as:

- expected and documented;
- soft miss;
- hard miss;
- unrelated external mod issue.

Known temporary lines belong in `docs/known-log-lines.md`.

## Automation Backlog

- Keep log-triage rules documented as copyable conventions until FS25 proves a
  safer shared-code path.
- Add load-time records to release notes once runtime testing becomes regular.
- Add package-size trend checks if player-facing assets grow beyond the MVP
  icon.
