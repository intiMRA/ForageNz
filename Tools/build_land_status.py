#!/usr/bin/env python3
"""Build the offline land-status raster: where a permit is needed, and where taking is banned.

The guide already says pikopiko needs a DOC permit and that karengo beds may sit inside a
marine reserve. It cannot say whether you are standing in one. This bakes DOC's own layers
into a bitmap small enough to ship, so the app can answer that with the radio off.

It is deliberately a coarse raster rather than exact polygons. A forager needs "you are
probably on conservation land, check before you pick", not a survey-grade boundary — and a
raster makes the lookup a single pixel read instead of point-in-polygon over 11,000 shapes.
The app must present it as advisory, never as a legal determination.

    python3 Tools/build_land_status.py            # fetch, rasterise, report size
    python3 Tools/build_land_status.py --degrees 0.005   # coarser grid

Output: ForageNZ/Catalogue/land-status.png plus land-status.json describing the grid.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import dataclass
from enum import IntFlag, StrEnum
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageDraw

from sources import COURTESY_DELAY, get_json

OUTPUT_IMAGE = Path("ForageNZ/Catalogue/land-status.png")
OUTPUT_METADATA = Path("ForageNZ/Catalogue/land-status.json")

DOC_SERVICES = "https://services1.arcgis.com/3JjYDyG3oajxU6HO/ArcGIS/rest/services"
PAGE_SIZE = 1000


class LandStatus(IntFlag):
    """Bit flags packed into the raster's grey value."""

    NONE = 0
    #: DOC public conservation land — harvesting plant material needs a permit.
    CONSERVATION = 1
    #: Marine reserve — no taking of anything, ever.
    MARINE_RESERVE = 2


class Layer(StrEnum):
    CONSERVATION = "DOC_Public_Conservation_Land"
    MARINE_RESERVE = "DOC_Marine_Reserves"

    @property
    def status(self) -> LandStatus:
        return LandStatus.CONSERVATION if self is Layer.CONSERVATION else LandStatus.MARINE_RESERVE


@dataclass(frozen=True)
class Grid:
    """An equirectangular grid over New Zealand, in degrees."""

    min_longitude: float = 166.0
    max_longitude: float = 179.2
    min_latitude: float = -47.6
    max_latitude: float = -33.9
    degrees: float = 0.0025  # ~275 m north-south

    @property
    def width(self) -> int:
        return int((self.max_longitude - self.min_longitude) / self.degrees)

    @property
    def height(self) -> int:
        return int((self.max_latitude - self.min_latitude) / self.degrees)

    def pixel(self, longitude: float, latitude: float) -> tuple[float, float]:
        """Latitude is flipped: image row 0 is the northern edge."""
        x = (longitude - self.min_longitude) / self.degrees
        y = (self.max_latitude - latitude) / self.degrees
        return x, y

    def as_metadata(self) -> dict[str, Any]:
        return {
            "minLongitude": self.min_longitude,
            "maxLongitude": self.max_longitude,
            "minLatitude": self.min_latitude,
            "maxLatitude": self.max_latitude,
            "degreesPerPixel": self.degrees,
            "width": self.width,
            "height": self.height,
            "flags": {
                "conservation": int(LandStatus.CONSERVATION),
                "marineReserve": int(LandStatus.MARINE_RESERVE),
            },
        }


def fetch_rings(layer: Layer, offset_tolerance: float) -> list[list[tuple[float, float]]]:
    """Every exterior + interior ring in a layer, as lon/lat tuples.

    Holes are not modelled: a hole inside conservation land is a rare edge case, and
    over-reporting "you may need a permit" is the safe direction to be wrong in.
    """
    rings: list[list[tuple[float, float]]] = []
    offset = 0

    while True:
        payload = get_json(
            f"{DOC_SERVICES}/{layer}/FeatureServer/0/query",
            {
                "where": "1=1",
                "outFields": "",
                "returnGeometry": "true",
                "maxAllowableOffset": offset_tolerance,
                "geometryPrecision": 5,
                "outSR": 4326,
                "resultRecordCount": PAGE_SIZE,
                "resultOffset": offset,
                "f": "geojson",
            },
        )
        features = payload.get("features") or []
        if not features:
            break

        for feature in features:
            geometry = feature.get("geometry") or {}
            polygons = (
                [geometry.get("coordinates")]
                if geometry.get("type") == "Polygon"
                else geometry.get("coordinates") or []
            )
            for polygon in polygons:
                for ring in polygon or []:
                    if len(ring) >= 3:
                        rings.append([(float(x), float(y)) for x, y, *_ in ring])

        offset += len(features)
        print(f"    {layer}: {offset} features, {len(rings)} rings", file=sys.stderr)
        if len(features) < PAGE_SIZE:
            break
        time.sleep(COURTESY_DELAY)

    return rings


#: Ground truth for a smoke test. Rasterising silently produces a plausible-looking blank
#: image if the projection is wrong, so check places whose status is not in doubt.
KNOWN_POINTS: tuple[tuple[str, float, float, LandStatus], ...] = (
    ("Tongariro National Park", -39.2800, 175.5600, LandStatus.CONSERVATION),
    ("Fiordland National Park", -45.4000, 167.7000, LandStatus.CONSERVATION),
    ("Wellington CBD", -41.2865, 174.7762, LandStatus.NONE),
    ("Hamilton CBD", -37.7870, 175.2793, LandStatus.NONE),
)


def verify(image: Image.Image, grid: Grid) -> None:
    print("\n  checking known points:")
    for name, latitude, longitude, expected in KNOWN_POINTS:
        x, y = grid.pixel(longitude, latitude)
        # A mode "L" image always yields a single int; the wider type is Pillow covering
        # every mode it supports.
        raw = image.getpixel((int(x), int(y)))
        value = LandStatus(raw if isinstance(raw, int) else 0)
        verdict = "ok" if bool(value & expected) == bool(expected) else "UNEXPECTED"
        print(f"    {name:26} {value!s:40} {verdict}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--degrees", type=float, default=Grid.degrees)
    parser.add_argument(
        "--offset-tolerance",
        type=float,
        default=0.002,
        help="server-side generalisation, in degrees",
    )
    arguments = parser.parse_args()

    grid = Grid(degrees=arguments.degrees)
    print(f"Grid {grid.width} x {grid.height} at {grid.degrees}° (~{grid.degrees * 111_000:.0f} m)")

    # Each layer gets its own mask so overlapping layers keep BOTH bits. Drawing them
    # into one image would have the second layer overwrite the first.
    masks: list[Image.Image] = []
    for layer in Layer:
        print(f"  fetching {layer}…")
        rings = fetch_rings(layer, arguments.offset_tolerance)
        print(f"  rasterising {len(rings)} ring(s) for {layer}")

        mask = Image.new("L", (grid.width, grid.height), 0)
        canvas = ImageDraw.Draw(mask)
        for ring in rings:
            canvas.polygon(
                [grid.pixel(longitude, latitude) for longitude, latitude in ring],
                fill=int(layer.status),
            )
        masks.append(mask)

    # The flags are distinct bits and each mask holds only its own, so adding the masks
    # is exactly a bitwise OR — and unlike `lighter` it keeps both bits where they overlap.
    image = masks[0]
    for mask in masks[1:]:
        image = ImageChops.add(image, mask)

    OUTPUT_IMAGE.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT_IMAGE, optimize=True)
    OUTPUT_METADATA.write_text(json.dumps(grid.as_metadata(), indent=2) + "\n")

    verify(image, grid)

    size = OUTPUT_IMAGE.stat().st_size
    print(f"\nWrote {OUTPUT_IMAGE} — {size / 1024:.0f} KB")
    print(f"Wrote {OUTPUT_METADATA}")
    if size > 2_000_000:
        print("That is large for a bundled asset; try a coarser --degrees.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
