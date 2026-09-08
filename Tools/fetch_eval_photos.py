#!/usr/bin/env python3
"""Fetch openly-licensed photos into an evaluation set.

This builds TEST DATA, not catalogue content. Nothing it downloads is shipped: the photos
land in a gitignored directory and exist only so the photo matcher can be measured.

Only CC0 and CC BY photos are taken, and every one keeps its attribution in the manifest.
Shipping any of these would additionally need a caption naming the feature each photo
shows, which is a human judgement and not something to auto-fill.

    python3 Tools/fetch_eval_photos.py
    python3 Tools/fetch_eval_photos.py --set out-of-catalogue --out .eval-photos-negative
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Any

from sources import COURTESY_DELAY, Licence, Source, SourceError, download, results_of


class EvaluationSet(StrEnum):
    """Which population to sample."""

    CATALOGUE = "catalogue"
    OUT_OF_CATALOGUE = "out-of-catalogue"


#: Catalogue id -> scientific name. Weighted towards the confusable fungi, because that is
#: where a visual matcher either works or is dangerous.
CATALOGUE_TAXA: dict[str, str] = {
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

#: Common NZ plants deliberately NOT in the catalogue. Several are seriously toxic, which
#: is the point: photographing one must not produce a confident shortlist of edibles.
OUT_OF_CATALOGUE_TAXA: dict[str, str] = {
    "foxglove": "Digitalis purpurea",
    "hemlock": "Conium maculatum",
    "ragwort": "Jacobaea vulgaris",
    "agapanthus": "Agapanthus praecox",
    "arum-lily": "Zantedeschia aethiopica",
    "buttercup": "Ranunculus repens",
}

TAXA_BY_SET: dict[EvaluationSet, dict[str, str]] = {
    EvaluationSet.CATALOGUE: CATALOGUE_TAXA,
    EvaluationSet.OUT_OF_CATALOGUE: OUT_OF_CATALOGUE_TAXA,
}


@dataclass(frozen=True)
class FetchedPhoto:
    file: str
    licence: Licence
    attribution: str
    photo_id: int | None
    observation_url: str | None

    def as_manifest_entry(self) -> dict[str, Any]:
        return {
            "file": self.file,
            "licence": str(self.licence),
            "attribution": self.attribution,
            "photoId": self.photo_id,
            "observationURL": self.observation_url,
        }


def observations(scientific_name: str, wanted: int) -> list[dict[str, Any]]:
    """Research-grade observations carrying a reusable photo licence."""
    return results_of(
        Source.INAT_OBSERVATIONS,
        {
            "taxon_name": scientific_name,
            "quality_grade": "research",
            "photo_license": Licence.query_value(),
            "per_page": min(wanted * 3, 60),
            "order_by": "votes",
        },
    )


def fetch_species(
    species_id: str, scientific_name: str, directory: Path, wanted: int
) -> list[FetchedPhoto]:
    directory.mkdir(parents=True, exist_ok=True)
    fetched: list[FetchedPhoto] = []

    try:
        found = observations(scientific_name, wanted)
    except SourceError as error:
        print(f"{species_id}: query failed ({error})", file=sys.stderr)
        return fetched

    for observation in found:
        for photo in observation.get("photos") or []:
            if len(fetched) >= wanted:
                return fetched
            try:
                licence = Licence(photo.get("license_code"))
            except ValueError:
                continue

            # `square.jpg` is a thumbnail; `medium` is the largest openly served size.
            url = str(photo.get("url") or "").replace("square.", "medium.")
            if not url:
                continue

            path = directory / f"{species_id}-{len(fetched) + 1}.jpg"
            if not download(url, path):
                print(f"    download failed: {url}", file=sys.stderr)
                continue

            photo_id = photo.get("id")
            fetched.append(
                FetchedPhoto(
                    file=path.name,
                    licence=licence,
                    attribution=str(photo.get("attribution") or ""),
                    photo_id=int(photo_id) if photo_id is not None else None,
                    observation_url=observation.get("uri"),
                )
            )
            time.sleep(COURTESY_DELAY)
    return fetched


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--per-species", type=int, default=8)
    parser.add_argument("--out", type=Path, default=Path(".eval-photos"))
    parser.add_argument(
        "--set",
        dest="evaluation_set",
        type=EvaluationSet,
        choices=list(EvaluationSet),
        default=EvaluationSet.CATALOGUE,
    )
    arguments = parser.parse_args()

    root: Path = arguments.out
    root.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, list[dict[str, Any]]] = {}

    for species_id, scientific_name in TAXA_BY_SET[arguments.evaluation_set].items():
        fetched = fetch_species(
            species_id, scientific_name, root / species_id, arguments.per_species
        )
        manifest[species_id] = [photo.as_manifest_entry() for photo in fetched]
        print(f"{species_id}: {len(fetched)} photo(s) ({scientific_name})")

    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    total = sum(len(photos) for photos in manifest.values())
    populated = sum(1 for photos in manifest.values() if photos)
    print(f"\n{total} photos across {populated} species -> {root}/")
    print("Test data only — not shipped, and not catalogue content.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
