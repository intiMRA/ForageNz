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
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Any

from sources import Licence, Source, SourceError, licensed_photos, results_of


class EvaluationSet(StrEnum):
    """Which population to sample."""

    CATALOGUE = "catalogue"
    OUT_OF_CATALOGUE = "out-of-catalogue"


CATALOGUE = Path("ForageNZ/Catalogue/species.json")


def catalogue_taxa(catalogue: Path = CATALOGUE) -> dict[str, str]:
    """Catalogue id -> scientific name, read from the catalogue itself.

    A hand-maintained copy drifted the first time the catalogue grew; the in-catalogue set is
    whatever the catalogue says. Compound names ("Urtica dioica / Urtica urens") query by their
    first part.
    """
    entries: list[dict[str, Any]] = json.loads(catalogue.read_text())
    return {
        str(entry["id"]): str(entry["scientificName"]).split("/")[0].strip() for entry in entries
    }


#: Common NZ plants deliberately NOT in the catalogue. Several are seriously toxic, which
#: is the point: photographing one must not produce a confident shortlist of edibles.
#: Hemlock used to be here; it is a catalogue entry now, and `check_disjoint` exists so that
#: kind of drift fails the run instead of quietly inflating the false-accept rate.
OUT_OF_CATALOGUE_TAXA: dict[str, str] = {
    "foxglove": "Digitalis purpurea",
    "ragwort": "Jacobaea vulgaris",
    "agapanthus": "Agapanthus praecox",
    "arum-lily": "Zantedeschia aethiopica",
    "buttercup": "Ranunculus repens",
}


def check_disjoint(in_catalogue: dict[str, str], out_of_catalogue: dict[str, str]) -> list[str]:
    """Ids or scientific names in both sets — must be empty for --openset to mean anything."""
    names = {name.lower() for name in in_catalogue.values()}
    return sorted(
        key
        for key, name in out_of_catalogue.items()
        if key in in_catalogue or name.lower() in names
    )


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

    for path, licence, photo, observation in licensed_photos(
        found, directory, species_id, wanted, size="medium"
    ):
        photo_id = photo.get("id")
        fetched.append(
            FetchedPhoto(
                file=path.name,
                licence=licence,
                attribution=str(photo.get("attribution") or ""),
                photo_id=int(photo_id) if isinstance(photo_id, int) else None,
                observation_url=observation.get("uri"),
            )
        )
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

    in_catalogue = catalogue_taxa()
    overlap = check_disjoint(in_catalogue, OUT_OF_CATALOGUE_TAXA)
    if overlap:
        print(
            f"Refusing to run: {', '.join(overlap)} is in the catalogue AND the out-of-catalogue "
            "set, so the open-set numbers would be wrong. Remove it from OUT_OF_CATALOGUE_TAXA.",
            file=sys.stderr,
        )
        return 1
    taxa = (
        in_catalogue
        if arguments.evaluation_set is EvaluationSet.CATALOGUE
        else OUT_OF_CATALOGUE_TAXA
    )

    for species_id, scientific_name in taxa.items():
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
