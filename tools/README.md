# Tools

## Package

```powershell
powershell -ExecutionPolicy Bypass -File tools/package.ps1
```

Creates `dist/FS25_PhobosRuralLedger.zip` from `mod/`.

## Package Set

```powershell
python tools/package_set.py --validate --write-sha256 --write-json
```

Builds all packages from `tools/package_manifest.json`, validates source and
package structure, and writes release metadata.

## Release Automation

GitHub Actions owns the normal release path through
`.github/workflows/release.yml`.

The workflow runs on `v*` tags or manual dispatch. It builds the versioned
package set from `tools/package_manifest.json`, validates each package, writes
checksums and `package-set.json`, and publishes all zips as GitHub release
assets. Manual dispatch creates the matching tag when needed.

Release notes are hybrid: the workflow generates a commit changelog since the
previous `v*` tag and package metadata, then blends in curated `summary`,
`notes`, `testing`, and `known_issues` inputs when supplied.

Use the local `tools/release.ps1` only as a fallback.

## Validation

```powershell
python tools/validate_mod.py
```

Performs static checks that do not require launching FS25. Runtime behavior must
still be verified in game.
