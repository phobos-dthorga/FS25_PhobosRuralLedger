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

## Validation

```powershell
python tools/validate_mod.py
```

Performs static checks that do not require launching FS25. Runtime behavior must
still be verified in game.
