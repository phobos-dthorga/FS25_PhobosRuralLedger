#!/usr/bin/env python3
"""Cross-platform package builder for CI."""

from __future__ import annotations

import argparse
import zipfile
from pathlib import Path


def package_mod(repo_root: Path, source_path: Path, output_path: Path) -> None:
    mod_root = source_path if source_path.is_absolute() else repo_root / source_path
    if not mod_root.is_dir():
        raise FileNotFoundError(f"Mod source folder not found: {mod_root}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.unlink()

    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(mod_root.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(mod_root).as_posix())


def main() -> int:
    parser = argparse.ArgumentParser(description="Build FS25_PhobosRuralLedger zip")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument("--source", default="mod", help="Mod source folder relative to the repository root")
    parser.add_argument("--output", default="dist/FS25_PhobosRuralLedger.zip", help="Output zip path")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = repo_root / output_path

    package_mod(repo_root, Path(args.source), output_path)
    print(f"Created {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
