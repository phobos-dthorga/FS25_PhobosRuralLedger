# Release Process

This repository is in early staging. The process below becomes active once the
first playable package exists.

## Before Release

- Update `mod/modDesc.xml` version.
- Run static validation.
- Build a package set.
- Launch FS25 and check the game log.
- Test loading an existing save when save data exists.
- Review `performance-targets.md`; do not release with a known hard miss.
- Review multiplayer and optional-integration impact.

## Build

```powershell
python tools/package_set.py --validate --write-sha256 --write-json --versioned
```

## Publish

`.github/workflows/release.yml` is the release owner for GitHub releases.

The workflow:

- compiles Python and Lua files;
- builds the package set from `tools/package_manifest.json` with versioned
  names;
- validates package contents;
- writes `SHA256SUMS.txt` and `package-set.json`;
- creates or verifies a `vX.Y.Z.W` tag for manual dispatches;
- publishes all package zips plus release metadata as GitHub release assets;
- publishes as a prerelease by default.

For manual dispatch, leave the version empty to use `mod/modDesc.xml`, or enter
the same version to make the intent explicit. The workflow refuses to release
when the requested version, tag version, and package version disagree.

`tools/release.ps1` remains a local fallback, but GitHub Actions is the
preferred release path.

Early releases should usually be prereleases.

## Performance Gate

If a hard miss is found, release work switches to fixing, measuring,
documenting, splitting, or removing the cause. New feature release work resumes
only after the affected target is met again.
