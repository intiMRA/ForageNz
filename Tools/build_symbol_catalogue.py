#!/usr/bin/env python3
"""Write the SF Symbols a list can take as its icon, for the app to bundle.

iOS has no API that lists the system symbols, so the names come from the SF Symbols data macOS
ships in CoreGlyphs. Kept: every symbol released by the app's deployment target, in the SF
Symbols app's order. Dropped: symbols Apple restricts to referring to its own features, and the
per-script variants (`character.ja`, `0.circle.ar`), which the system picks for the user's
language on its own. Re-run after raising the deployment target or on a newer macOS.

    python3 Tools/build_symbol_catalogue.py
"""

from __future__ import annotations

import argparse
import json
import plistlib
import sys
from pathlib import Path
from typing import Any

CORE_GLYPHS = Path("/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources")
OUTPUT = Path("ForageNZ/Lists/list-symbols.json")
DEPLOYMENT_TARGET = (18, 0)

#: The SF Symbols app's subject categories, in its order, with its names. Its rendering
#: categories (what's new, draw, variable, multicolour) describe how a symbol animates or is
#: coloured, not what it shows, so they are not offered.
CATEGORY_TITLES = {
    "communication": "Communication",
    "weather": "Weather",
    "maps": "Maps",
    "objectsandtools": "Objects & Tools",
    "devices": "Devices",
    "cameraandphotos": "Camera & Photos",
    "gaming": "Gaming",
    "connectivity": "Connectivity",
    "transportation": "Transportation",
    "automotive": "Automotive",
    "accessibility": "Accessibility",
    "privacyandsecurity": "Privacy & Security",
    "human": "Human",
    "home": "Home",
    "fitness": "Fitness",
    "nature": "Nature",
    "editing": "Editing",
    "textformatting": "Text Formatting",
    "media": "Media",
    "keyboard": "Keyboard",
    "commerce": "Commerce",
    "time": "Time",
    "health": "Health",
    "shapes": "Shapes",
    "arrows": "Arrows",
    "indices": "Indices",
    "math": "Math",
}


def release(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


#: The trailing components that mark a per-script or right-to-left copy of another symbol.
SCRIPT_VARIANT_SUFFIXES = {
    "ar", "bn", "el", "gu", "he", "hi", "ja", "km", "kn", "ko", "mni", "mr", "my", "or", "pa",
    "ru", "rtl", "sat", "si", "ta", "te", "th", "zh",
}


def is_script_variant(name: str, names: set[str]) -> bool:
    base, _, suffix = name.rpartition(".")
    return suffix in SCRIPT_VARIANT_SUFFIXES and base in names


def selectable_symbols(
    order: list[str],
    availability: dict[str, str],
    year_to_ios: dict[str, str],
    restricted: set[str],
    target: tuple[int, ...],
) -> list[str]:
    available = {
        name
        for name in order
        if name in availability
        and release(year_to_ios[availability[name]]) <= target
        and name not in restricted
    }
    return [name for name in order if name in available and not is_script_variant(name, available)]


def build(resources: Path, target: tuple[int, ...]) -> dict[str, Any]:
    def load(name: str) -> Any:
        with (resources / name).open("rb") as file:
            return plistlib.load(file)

    availability = load("name_availability.plist")
    year_to_ios = {year: platforms["iOS"] for year, platforms in availability["year_to_release"].items()}
    symbols = selectable_symbols(
        load("symbol_order.plist"),
        availability["symbols"],
        year_to_ios,
        set(load("symbol_restrictions.strings")),
        target,
    )
    selectable = set(symbols)
    memberships: dict[str, list[str]] = load("symbol_categories.plist")
    categories = [
        {
            "key": category["key"],
            "title": CATEGORY_TITLES[category["key"]],
            # The SF Symbols app's icon for a category can be newer than the target or restricted.
            "symbol": category["icon"] if category["icon"] in selectable else None,
            "symbols": [name for name in symbols if category["key"] in memberships.get(name, [])],
        }
        for category in load("categories.plist")
        if category["key"] in CATEGORY_TITLES
    ]
    return {"symbols": symbols, "categories": categories}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--resources", type=Path, default=CORE_GLYPHS)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    catalogue = build(args.resources, DEPLOYMENT_TARGET)
    args.output.write_text(json.dumps(catalogue, separators=(",", ":")) + "\n")
    print(f"{len(catalogue['symbols'])} symbols in {len(catalogue['categories'])} categories → {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
