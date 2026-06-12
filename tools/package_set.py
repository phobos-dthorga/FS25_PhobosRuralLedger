#!/usr/bin/env python3
"""Build and validate the configured FS25_PhobosRuralLedger package set."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

from package_mod import package_mod
from validate_mod import Validation, validate_package, validate_source


DEFAULT_MANIFEST = "tools/package_manifest.json"


def load_package_manifest(path: Path) -> list[dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    packages = data.get("packages")
    if not isinstance(packages, list) or not packages:
        raise ValueError(f"Package manifest must contain a non-empty packages list: {path}")

    result: list[dict[str, str]] = []
    for index, package in enumerate(packages, start=1):
        if not isinstance(package, dict):
            raise ValueError(f"Package manifest entry {index} must be an object")
        package_id = str(package.get("id", "")).strip()
        name = str(package.get("name", "")).strip()
        source = str(package.get("source", "")).strip()
        if not package_id or not name or not source:
            raise ValueError(f"Package manifest entry {index} requires id, name, and source")
        result.append({"id": package_id, "name": name, "source": source})
    return result


def read_mod_version(mod_root: Path) -> str:
    moddesc_path = mod_root / "modDesc.xml"
    root = ET.parse(moddesc_path).getroot()
    version = (root.findtext("version") or "").strip()
    if not version:
        raise ValueError(f"Could not read version from {moddesc_path}")
    return version


def package_output_name(name: str, version: str, suffix: str | None, versioned: bool) -> str:
    if suffix:
        return f"{name}_{suffix}.zip"
    if versioned:
        return f"{name}_v{version}.zip"
    return f"{name}.zip"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def validate_built_package(
    repo_root: Path,
    source: str,
    output_path: Path,
    soft_size_limit: int,
) -> int:
    validation = Validation()
    validate_source(repo_root, source, validation)
    validate_package(output_path, validation, soft_size_limit)
    return validation.report()


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the configured FS25_PhobosRuralLedger package set")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST, help="Package manifest path")
    parser.add_argument("--output-dir", default="dist", help="Directory for package output")
    parser.add_argument("--validate", action="store_true", help="Validate each source and package after building")
    parser.add_argument("--write-sha256", action="store_true", help="Write SHA256SUMS.txt beside the packages")
    parser.add_argument("--write-json", action="store_true", help="Write package-set.json beside the packages")
    parser.add_argument("--allow-mixed-versions", action="store_true", help="Allow package versions to differ")
    parser.add_argument(
        "--package-size-soft-limit",
        type=int,
        default=1_000_000,
        help="Soft package size warning threshold in bytes",
    )
    naming = parser.add_mutually_exclusive_group()
    naming.add_argument("--suffix", help="Append this suffix to package names, for example 'ci'")
    naming.add_argument("--versioned", action="store_true", help="Append each package version to its zip name")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = repo_root / manifest_path
    output_dir = Path(args.output_dir)
    if not output_dir.is_absolute():
        output_dir = repo_root / output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        package_entries = load_package_manifest(manifest_path)
        built: list[dict[str, str | int]] = []
        versions: dict[str, str] = {}

        for package in package_entries:
            source = package["source"]
            source_root = Path(source)
            if not source_root.is_absolute():
                source_root = repo_root / source_root
            if not source_root.is_dir():
                raise FileNotFoundError(f"Package source not found: {source_root}")

            version = read_mod_version(source_root)
            versions[package["name"]] = version
            output_name = package_output_name(package["name"], version, args.suffix, args.versioned)
            output_path = output_dir / output_name

            print(f"Building {package['name']} from {source} -> {output_path}")
            package_mod(repo_root, Path(source), output_path)

            if args.validate:
                print(f"Validating {package['name']}")
                if validate_built_package(repo_root, source, output_path, args.package_size_soft_limit) != 0:
                    return 1

            digest = sha256_file(output_path)
            built.append(
                {
                    "id": package["id"],
                    "name": package["name"],
                    "source": source,
                    "version": version,
                    "filename": output_path.name,
                    "size": output_path.stat().st_size,
                    "sha256": digest,
                }
            )

        unique_versions = sorted(set(versions.values()))
        if len(unique_versions) > 1 and not args.allow_mixed_versions:
            print("::error::Package versions do not match:")
            for name, version in sorted(versions.items()):
                print(f"::error::{name}: {version}")
            return 1

        if args.write_sha256:
            sha_path = output_dir / "SHA256SUMS.txt"
            sha_lines = [f"{record['sha256']}  {record['filename']}" for record in built]
            sha_path.write_text("\n".join(sha_lines) + "\n", encoding="utf-8")
            print(f"Wrote {sha_path}")

        if args.write_json:
            json_path = output_dir / "package-set.json"
            json_path.write_text(json.dumps({"packages": built}, indent=2) + "\n", encoding="utf-8")
            print(f"Wrote {json_path}")

    except (OSError, ValueError, ET.ParseError, json.JSONDecodeError) as exc:
        print(f"::error::{exc}")
        return 1

    print("Package set built successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
