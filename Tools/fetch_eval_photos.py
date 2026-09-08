#!/usr/bin/env python3
"""Fetch openly-licensed photos into an evaluation set.

This builds TEST DATA, not catalogue content. Nothing it downloads is shipped: the
photos land in `.eval-photos/` (gitignored) and exist only so the photo matcher's
accuracy can be measured against species it hasn't been tuned on.

Only CC0 and CC BY photos are taken, and every one keeps its attribution in the
manifest. Shipping any of these would additionally need a caption naming the feature
each photo shows, which is a human judgement, not something to auto-fill.

    python3 Tools/fetch_eval_photos.py [--per-species N] [--out DIR]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.inaturalist.org/v1/observations"
USER_AGENT = "ForageNZ-eval/1.0 (catalogue matcher evaluation)"
ACCEPTED_LICENCES = ("cc0", "cc-by")

# Catalogue id -> scientific name. Weighted towards the confusable fungi, because that
# is where a visual matcher either works or is dangerous.
TAXA = {
    "field-mushroom": "Agaricus campestris",
    "porcini": "Boletus edulis",
    "slippery-jack": "Suillus luteus",
    "saffron-milk-cap": "Lactarius deliciosus",
    "death-cap": "Amanita phalloides",
    "wood-ear": "Auricularia cornea",
    "dandelion": "Taraxacum officinale",
    "chickweed": "Stellaria media",
    "nettle": "Urtica dioica",
    "wild-fennel": "Foeniculum vulgare",
    "blackberry": "Rubus fruticosus",
    "watercress": "Nasturtium officinale",
    "kawakawa": "Piper excelsum",
    "horopito": "Pseudowintera colorata",
}


# Plants that are common in NZ and deliberately NOT in the catalogue. Several are
# seriously toxic, which is the point: photographing one must not produce a confident
# shortlist of edible entries.
OUT_OF_CATALOGUE = {
    "foxglove": "Digitalis purpurea",
    "hemlock": "Conium maculatum",
    "ragwort": "Jacobaea vulgaris",
    "agapanthus": "Agapanthus praecox",
    "arum-lily": "Zantedeschia aethiopica",
    "buttercup": "Ranunculus repens",
}


def request_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def observations(scientific_name: str, wanted: int) -> list[dict]:
    """Research-grade observations carrying a reusable photo licence."""
    query = urllib.parse.urlencode(
        {
            "taxon_name": scientific_name,
            "quality_grade": "research",
            "photo_license": ",".join(ACCEPTED_LICENCES),
            "per_page": min(wanted * 3, 60),
            "order_by": "votes",
        }
    )
    return request_json(f"{API}?{query}").get("results", [])


def download(url: str, destination: pathlib.Path) -> bool:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            destination.write_bytes(response.read())
        return True
    except (urllib.error.URLError, TimeoutError) as error:
        print(f"    download failed: {error}", file=sys.stderr)
        return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--per-species", type=int, default=8)
    parser.add_argument("--out", default=".eval-photos")
    parser.add_argument("--set", choices=["catalogue", "out-of-catalogue"], default="catalogue")
    arguments = parser.parse_args()

    root = pathlib.Path(arguments.out)
    root.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, list[dict]] = {}

    taxa = TAXA if arguments.set == "catalogue" else OUT_OF_CATALOGUE
    for species_id, scientific_name in taxa.items():
        directory = root / species_id
        directory.mkdir(exist_ok=True)
        records: list[dict] = []

        try:
            found = observations(scientific_name, arguments.per_species)
        except (urllib.error.URLError, TimeoutError) as error:
            print(f"{species_id}: query failed ({error})", file=sys.stderr)
            continue

        for observation in found:
            if len(records) >= arguments.per_species:
                break
            for photo in observation.get("photos", []):
                if len(records) >= arguments.per_species:
                    break
                licence = photo.get("license_code")
                if licence not in ACCEPTED_LICENCES:
                    continue

                # `square.jpg` is a thumbnail; `medium` is the largest openly served size.
                url = (photo.get("url") or "").replace("square.", "medium.")
                if not url:
                    continue

                index = len(records) + 1
                path = directory / f"{species_id}-{index}.jpg"
                if not download(url, path):
                    continue

                records.append(
                    {
                        "file": path.name,
                        "licence": licence,
                        "attribution": photo.get("attribution") or "",
                        "photoId": photo.get("id"),
                        "observationURL": observation.get("uri"),
                    }
                )
                time.sleep(0.4)  # be a considerate API client

        manifest[species_id] = records
        print(f"{species_id}: {len(records)} photo(s) ({scientific_name})")

    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    total = sum(len(v) for v in manifest.values())
    print(f"\n{total} photos across {len([k for k, v in manifest.items() if v])} species -> {root}/")
    print("Test data only — not shipped, and not catalogue content.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
