#!/usr/bin/env python3
"""Static validation for FS25_PhobosRuralLedger.

These checks cover only what can be proven without launching FS25. The game log
and disposable-save tests remain the authority for runtime behavior.
"""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


VERSION_RE = re.compile(r"^\d+\.\d+\.\d+\.\d+$")
FORBIDDEN_PACKAGE_PREFIXES = (
    ".git/",
    ".github/",
    "build/",
    "dist/",
    "docs/",
    "mod/",
    "release/",
    "tools/",
)
REQUIRED_DOCS = (
    "docs/performance-targets.md",
    "docs/measurement-and-automation.md",
    "docs/known-log-lines.md",
)
REQUIRED_LOCALES = ("en", "de")
REQUIRED_L10N_KEYS = ("input_PHOBOS_RURAL_LEDGER_MENU",)


class Validation:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def report(self) -> int:
        for warning in self.warnings:
            print(f"::warning::{warning}")
        for error in self.errors:
            print(f"::error::{error}")
        if self.errors:
            print(f"Validation failed with {len(self.errors)} error(s).")
            return 1
        print("Validation passed.")
        return 0


def parse_xml_file(path: Path, validation: Validation) -> ET.ElementTree | None:
    try:
        return ET.parse(path)
    except ET.ParseError as exc:
        validation.error(f"XML parse failed: {path}: {exc}")
    return None


def l10n_files_from_prefix(mod_root: Path, prefix: str) -> dict[str, Path]:
    return {
        locale: mod_root / f"{prefix}_{locale}.xml"
        for locale in REQUIRED_LOCALES
    }


def read_l10n_keys(path: Path, validation: Validation) -> set[str]:
    tree = parse_xml_file(path, validation)
    if tree is None:
        return set()

    keys: set[str] = set()
    for node in tree.getroot().findall("./texts/text"):
        name = (node.get("name") or "").strip()
        if name:
            keys.add(name)

    return keys


def validate_required_docs(repo_root: Path, validation: Validation) -> None:
    for doc in REQUIRED_DOCS:
        if not (repo_root / doc).is_file():
            validation.error(f"Missing required documentation: {doc}")


def validate_moddesc(mod_root: Path, validation: Validation) -> None:
    moddesc_path = mod_root / "modDesc.xml"
    if not moddesc_path.is_file():
        validation.error(f"Missing modDesc.xml: {moddesc_path}")
        return

    tree = parse_xml_file(moddesc_path, validation)
    if tree is None:
        return

    root = tree.getroot()
    if root.tag != "modDesc":
        validation.error("modDesc.xml root must be modDesc")

    version = (root.findtext("version") or "").strip()
    if not VERSION_RE.match(version):
        validation.error(f"modDesc.xml version must be X.Y.Z.W, found '{version}'")

    author = (root.findtext("author") or "").strip()
    if author != "phobosgekko":
        validation.warn(f"Expected author 'phobosgekko', found '{author}'")

    title = (root.findtext("title/en") or "").strip()
    if title != "Phobos' Rural Ledger":
        validation.error(f"Unexpected English title: '{title}'")

    icon_filename = (root.findtext("iconFilename") or "").strip()
    if icon_filename and not (mod_root / icon_filename).is_file():
        validation.warn(f"modDesc.xml references missing iconFilename: {icon_filename}")

    l10n_node = root.find("l10n")
    if l10n_node is None:
        validation.error("modDesc.xml must declare <l10n filenamePrefix=\"translations/translation\"/>")
    else:
        filename_prefix = (l10n_node.get("filenamePrefix") or "").strip()
        if filename_prefix != "translations/translation":
            validation.error(f"Unexpected l10n filenamePrefix: '{filename_prefix}'")

    dependencies = {
        (node.text or "").strip()
        for node in root.findall("./dependencies/dependency")
        if (node.text or "").strip()
    }
    if "FS25_PhobosLib" not in dependencies:
        validation.error("Expected dependency FS25_PhobosLib")

    for node in root.findall("./extraSourceFiles/sourceFile"):
        filename = node.get("filename", "").strip()
        if filename and not (mod_root / filename).is_file():
            validation.error(f"modDesc.xml references missing sourceFile: {filename}")


def validate_l10n(mod_root: Path, validation: Validation) -> None:
    moddesc_path = mod_root / "modDesc.xml"
    tree = parse_xml_file(moddesc_path, validation)
    if tree is None:
        return

    l10n_node = tree.getroot().find("l10n")
    if l10n_node is None:
        return

    filename_prefix = (l10n_node.get("filenamePrefix") or "").strip()
    if not filename_prefix:
        validation.error("modDesc.xml l10n node must define filenamePrefix")
        return

    locale_files = l10n_files_from_prefix(mod_root, filename_prefix)
    keys_by_locale: dict[str, set[str]] = {}
    for locale, path in locale_files.items():
        if not path.is_file():
            validation.error(f"Missing required {locale} translation file: {path.relative_to(mod_root)}")
            keys_by_locale[locale] = set()
            continue
        keys_by_locale[locale] = read_l10n_keys(path, validation)

    english_keys = keys_by_locale.get("en", set())
    german_keys = keys_by_locale.get("de", set())
    for key in REQUIRED_L10N_KEYS:
        if key not in english_keys:
            validation.error(f"English translation is missing required key: {key}")
        if key not in german_keys:
            validation.error(f"German translation is missing required key: {key}")

    for key in sorted(english_keys - german_keys):
        validation.error(f"German translation is missing key present in English: {key}")
    for key in sorted(german_keys - english_keys):
        validation.error(f"English translation is missing key present in German: {key}")

    validate_gui_l10n_references(mod_root, keys_by_locale, validation)


def validate_gui_l10n_references(
    mod_root: Path,
    keys_by_locale: dict[str, set[str]],
    validation: Validation,
) -> None:
    gui_root = mod_root / "gui"
    if not gui_root.is_dir():
        return

    all_keys = set.intersection(*keys_by_locale.values()) if keys_by_locale else set()
    for path in sorted(gui_root.rglob("*.xml")):
        tree = parse_xml_file(path, validation)
        if tree is None:
            continue

        for node in tree.getroot().iter():
            text_value = (node.get("text") or "").strip()
            if not text_value:
                continue

            if not text_value.startswith("$l10n_"):
                validation.error(
                    f"GUI text must use l10n key in {path.relative_to(mod_root)}: '{text_value}'"
                )
                continue

            key = text_value[len("$l10n_"):]
            if key not in all_keys:
                validation.error(
                    f"GUI l10n key is not present in all required locales in {path.relative_to(mod_root)}: {key}"
                )


def validate_xml_files(mod_root: Path, validation: Validation) -> None:
    xml_files = sorted(mod_root.rglob("*.xml"))
    if not xml_files:
        validation.error("No XML files found under mod source")
        return
    for path in xml_files:
        parse_xml_file(path, validation)


def validate_source(repo_root: Path, mod_source: str, validation: Validation) -> None:
    source_path = Path(mod_source)
    mod_root = source_path if source_path.is_absolute() else repo_root / source_path
    if not mod_root.is_dir():
        validation.error(f"Missing mod source directory: {mod_root}")
        return

    validate_required_docs(repo_root, validation)
    validate_xml_files(mod_root, validation)
    validate_moddesc(mod_root, validation)
    validate_l10n(mod_root, validation)


def package_expected_entries(names: set[str], archive: zipfile.ZipFile, validation: Validation) -> set[str]:
    expected = {"modDesc.xml"}
    if "modDesc.xml" not in names:
        return expected

    try:
        root = ET.fromstring(archive.read("modDesc.xml"))
    except ET.ParseError as exc:
        validation.error(f"Package modDesc.xml parse failed: {exc}")
        return expected

    icon_filename = (root.findtext("iconFilename") or "").strip()
    if icon_filename:
        expected.add(icon_filename.replace("\\", "/"))

    for node in root.findall("./extraSourceFiles/sourceFile"):
        filename = node.get("filename", "").strip()
        if filename:
            expected.add(filename.replace("\\", "/"))

    l10n_node = root.find("l10n")
    if l10n_node is not None:
        filename_prefix = (l10n_node.get("filenamePrefix") or "").strip()
        for locale in REQUIRED_LOCALES:
            expected.add(f"{filename_prefix}_{locale}.xml".replace("\\", "/"))

    return expected


def validate_package(package_path: Path, validation: Validation, soft_size_limit: int) -> None:
    if not package_path.is_file():
        validation.error(f"Package not found: {package_path}")
        return

    package_size = package_path.stat().st_size
    if package_size > soft_size_limit:
        validation.warn(
            f"Package size is {package_size} bytes; XML-only soft target is {soft_size_limit} bytes"
        )

    try:
        with zipfile.ZipFile(package_path) as archive:
            names = sorted(info.filename for info in archive.infolist())
            name_set = set(names)
            expected_entries = package_expected_entries(name_set, archive, validation)
    except zipfile.BadZipFile as exc:
        validation.error(f"Invalid zip file: {package_path}: {exc}")
        return

    missing = sorted(expected_entries - set(names))
    for entry in missing:
        validation.error(f"Package is missing expected entry referenced by modDesc.xml: {entry}")

    for name in names:
        if "\\" in name:
            validation.error(f"Package entry uses backslash instead of slash: {name}")
        lower = name.lower()
        for prefix in FORBIDDEN_PACKAGE_PREFIXES:
            if lower.startswith(prefix):
                validation.error(f"Package contains forbidden repository path: {name}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate FS25_PhobosRuralLedger source or package")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument("--mod-source", default="mod", help="Mod source folder relative to the repository root")
    parser.add_argument("--package", help="Optional package zip to validate")
    parser.add_argument(
        "--package-size-soft-limit",
        type=int,
        default=1_000_000,
        help="Soft package size warning threshold in bytes",
    )
    args = parser.parse_args()

    validation = Validation()
    repo_root = Path(args.repo_root).resolve()

    validate_source(repo_root, args.mod_source, validation)
    if args.package:
        validate_package(Path(args.package).resolve(), validation, args.package_size_soft_limit)

    return validation.report()


if __name__ == "__main__":
    sys.exit(main())
