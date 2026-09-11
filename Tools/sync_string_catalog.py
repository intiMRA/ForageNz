#!/usr/bin/env python3
"""Merge the compiler's extracted strings into the app's String Catalog.

Xcode extracts every `Text("…")` / `LocalizedStringKey` literal at build time into
`*.stringsdata` files, and the IDE writes them into `Localizable.xcstrings` for you. A
command-line build emits the same data but does not touch the catalog, so a project built from
the terminal drifts. This does the write-back: new keys are added in state "new", existing
entries — including any translations — are left exactly as they are, and keys the code no
longer uses are reported so they can be removed on purpose.

    xcodebuild build -project ForageNZ.xcodeproj -scheme ForageNZ -destination '…'
    python3 Tools/sync_string_catalog.py
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

CATALOG = Path("ForageNZ/Resources/Localizable.xcstrings")
DERIVED_DATA = Path.home() / "Library/Developer/Xcode/DerivedData"
#: Only the app target's strings belong in the app's catalog.
TARGET_BUILD_DIR = "ForageNZ.build"


def stringsdata_files(derived_data: Path) -> list[Path]:
    """Every .stringsdata the app target emitted, across all DerivedData folders for it.

    The project's intermediates directory is also called ForageNZ.build, so the check is on the
    target directory immediately above Objects-normal — not on any path component — or the
    macOS editor's strings would land in the iOS app's catalog.
    """
    return sorted(
        path
        for project in derived_data.glob("ForageNZ-*")
        for path in project.rglob("*.stringsdata")
        if path.parent.parent.parent.name == TARGET_BUILD_DIR
    )


def extracted_keys(files: list[Path]) -> dict[str, str]:
    """Key -> comment, for the `Localizable` table."""
    keys: dict[str, str] = {}
    for path in files:
        payload: dict[str, Any] = json.loads(path.read_text())
        tables: dict[str, list[dict[str, Any]]] = payload.get("tables", {})
        for entry in tables.get("Localizable", []):
            key = str(entry["key"])
            keys.setdefault(key, str(entry.get("comment") or ""))
    return keys


def merge(catalog: dict[str, Any], keys: dict[str, str]) -> tuple[list[str], list[str]]:
    """Add missing keys to the catalog in place. Returns (added, stale)."""
    strings: dict[str, Any] = catalog.setdefault("strings", {})
    added = []
    for key, comment in sorted(keys.items()):
        if key in strings:
            continue
        entry: dict[str, Any] = {}
        if comment:
            entry["comment"] = comment
        strings[key] = entry
        added.append(key)
    stale = sorted(key for key in strings if key not in keys)
    return added, stale


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--derived-data", type=Path, default=DERIVED_DATA)
    parser.add_argument("--catalog", type=Path, default=CATALOG)
    arguments = parser.parse_args()

    files = stringsdata_files(arguments.derived_data)
    if not files:
        print("No .stringsdata found — build the ForageNZ scheme first.", file=sys.stderr)
        return 1

    catalog: dict[str, Any] = json.loads(arguments.catalog.read_text())
    added, stale = merge(catalog, extracted_keys(files))
    strings: dict[str, Any] = catalog["strings"]
    arguments.catalog.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    )

    print(f"{len(strings)} key(s) in {arguments.catalog} from {len(files)} source file(s)")
    for key in added:
        print(f"  + {key}")
    if stale:
        print(f"\n{len(stale)} key(s) in the catalog that no source file uses any more:")
        for key in stale:
            print(f"  ? {key}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
