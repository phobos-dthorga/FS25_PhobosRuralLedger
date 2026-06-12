# Release Process

This repository is in early staging. The process below becomes active once the
first playable package exists.

## Before Release

- Update `mod/modDesc.xml` version.
- Run static validation.
- Build a package set.
- Launch FS25 and check the game log.
- Test loading an existing save when save data exists.
- Review multiplayer and optional-integration impact.

## Build

```powershell
python tools/package_set.py --validate --write-sha256 --write-json --versioned
```

## Publish

`tools/release.ps1` is staged for GitHub release publishing. It will build a
versioned package, tag the current commit, push the tag, and create a GitHub
release when the repository is ready for releases.

Early releases should usually be prereleases.
