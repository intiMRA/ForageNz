#!/usr/bin/env python3
"""Fill gaps in the catalogue from NZOR and iNaturalist, without ever overwriting you.

THE RULE: a field you have written is never touched. This script only fills fields that
are empty, and only fields that are matters of record rather than judgement. Everything
safety-critical — identification, warnings, lookalikes, preparation, edible parts,
harvesting guidance, sources, recipes, caution level — it will not write under any
circumstances, even if blank. Those come from your books.

Where an external source disagrees with something you wrote, it is REPORTED and left
alone. A scientific name that has become a synonym, or an origin that contradicts NZOR's
biostatus, is a decision for you.

    python3 Tools/enrich_catalogue.py                # dry run: report only
    python3 Tools/enrich_catalogue.py --write        # apply the fills
    python3 Tools/enrich_catalogue.py --stage-photos # download CC-licensed candidates

Photos are staged, never attached: a photo needs a caption naming the feature it shows,
which is a human judgement. Attach them in the CatalogueEditor.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

CATALOGUE = pathlib.Path("ForageNZ/Catalogue/species.json")
USER_AGENT = "ForageNZ/1.0 (catalogue enrichment; contact via repo)"

NZOR_SEARCH = "https://data.nzor.org.nz/names/search"
INAT_TAXA = "https://api.inaturalist.org/v1/taxa"
INAT_OBSERVATIONS = "https://api.inaturalist.org/v1/observations"
ACCEPTED_LICENCES = ("cc0", "cc-by")

# Only ever filled when empty, and only because they are matters of record.
#
# `maoriName` is deliberately NOT here. iNaturalist's preferred_common_name is
# locale-dependent and defaults to English, so it happily offers "Persian walnut" and
# "King Bolete" as te reo names; `locale=mi` is mostly empty, returning nothing for
# kawakawa or horopito whose te reo names ARE their common names. Any candidate it does
# find is reported as a suggestion for you to accept or reject.
FILLABLE = ("moreImagesURL",)

# Never written, blank or not. Judgement, or safety-critical, or both.
PROTECTED = (
    "identification", "preparation", "edibleParts", "warnings", "lookalikes",
    "harvestEthics", "sources", "recipes", "caution", "summary", "habitat",
    "months", "category", "id", "commonName", "photos", "maoriName",
)

# Disagreements are surfaced, never applied.
REPORT_ONLY = ("scientificName", "origin")


def get_json(url: str, params: dict) -> dict:
    request = urllib.request.Request(
        f"{url}?{urllib.parse.urlencode(params)}",
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def nzor_record(scientific_name: str) -> dict | None:
    """NZOR's view of a scientific name: whether it is current, and its NZ biostatus."""
    try:
        results = get_json(NZOR_SEARCH, {"query": scientific_name}).get("results") or []
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"    NZOR lookup failed: {error}", file=sys.stderr)
        return None

    for result in results:
        name = result.get("name") or {}
        if name.get("class") != "Scientific Name":
            continue

        accepted = (name.get("acceptedName") or {}).get("partialName")
        origins: list[str] = []
        for status in name.get("biostatuses") or []:
            origins.extend(status.get("origin") or [])

        return {
            "partialName": name.get("partialName"),
            "status": name.get("status"),
            # Present and different means the name you have is a synonym.
            "acceptedName": accepted,
            "origins": origins,
        }
    return None


def inat_maori_name(scientific_name: str) -> str | None:
    """A te reo candidate, if iNaturalist has one under the Māori locale."""
    try:
        results = get_json(
            INAT_TAXA,
            {"q": scientific_name, "rank": "species", "per_page": 1, "locale": "mi"},
        ).get("results") or []
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None
    if not results:
        return None
    return (results[0].get("preferred_common_name") or "").strip() or None


def inat_taxon(scientific_name: str) -> dict | None:
    try:
        results = get_json(
            INAT_TAXA, {"q": scientific_name, "rank": "species", "per_page": 1}
        ).get("results") or []
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"    iNaturalist lookup failed: {error}", file=sys.stderr)
        return None
    return results[0] if results else None


def nzor_origin_class(origins: list[str]) -> str | None:
    """NZOR origin -> the catalogue's native/introduced split.

    "Non-endemic" still means indigenous — it occurs naturally here and elsewhere. Only
    "Exotic" implies introduced. NZOR cannot tell an introduced species from a declared
    pest, so a `pest` entry is treated as consistent with Exotic.
    """
    if any(origin in ("Endemic", "Non-endemic", "Indigenous") for origin in origins):
        return "native"
    if any(origin == "Exotic" for origin in origins):
        return "introduced"
    return None


def stage_photos(species_id: str, taxon_id: int, directory: pathlib.Path, wanted: int) -> list[dict]:
    directory.mkdir(parents=True, exist_ok=True)
    staged: list[dict] = []
    try:
        results = get_json(
            INAT_OBSERVATIONS,
            {
                "taxon_id": taxon_id,
                "quality_grade": "research",
                "photo_license": ",".join(ACCEPTED_LICENCES),
                "per_page": wanted * 3,
                "order_by": "votes",
            },
        ).get("results") or []
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"    photo search failed: {error}", file=sys.stderr)
        return staged

    for observation in results:
        if len(staged) >= wanted:
            break
        for photo in observation.get("photos") or []:
            if len(staged) >= wanted:
                break
            if photo.get("license_code") not in ACCEPTED_LICENCES:
                continue
            url = (photo.get("url") or "").replace("square.", "large.")
            if not url:
                continue

            path = directory / f"{species_id}-{len(staged) + 1}.jpg"
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    path.write_bytes(response.read())
            except (urllib.error.URLError, TimeoutError) as error:
                print(f"    download failed: {error}", file=sys.stderr)
                continue

            staged.append({
                "file": path.name,
                "licence": photo.get("license_code"),
                "credit": photo.get("attribution") or "",
                "sourceURL": observation.get("uri"),
                "caption": "",  # yours to write — the app requires it
            })
            time.sleep(0.4)
    return staged


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="apply fills (default is a dry run)")
    parser.add_argument("--stage-photos", action="store_true")
    parser.add_argument("--photo-dir", default=".staged-photos")
    parser.add_argument("--photos-per-species", type=int, default=6)
    parser.add_argument("--only", help="comma-separated species ids")
    arguments = parser.parse_args()

    if not CATALOGUE.exists():
        print(f"No catalogue at {CATALOGUE} — run from the repo root.", file=sys.stderr)
        return 1

    entries = json.loads(CATALOGUE.read_text())
    wanted = set(arguments.only.split(",")) if arguments.only else None

    filled: list[str] = []
    kept: list[str] = []
    disagreements: list[str] = []
    suggestions: list[str] = []
    staged_manifest: dict[str, list[dict]] = {}

    for entry in entries:
        if wanted and entry["id"] not in wanted:
            continue
        scientific_name = (entry.get("scientificName") or "").strip()
        if not scientific_name:
            print(f"{entry['id']}: no scientific name yet, skipping")
            continue

        print(f"{entry['id']} ({scientific_name})")

        # NZOR: is the name current, and does the origin agree?
        record = nzor_record(scientific_name)
        if record:
            accepted = record.get("acceptedName")
            if accepted and accepted.lower() != scientific_name.lower():
                disagreements.append(
                    f"{entry['id']}: scientificName '{scientific_name}' — NZOR accepts '{accepted}'"
                )
            expected = nzor_origin_class(record.get("origins") or [])
            actual = entry.get("origin")
            if expected and actual:
                consistent = expected == actual or (expected == "introduced" and actual == "pest")
                if not consistent:
                    disagreements.append(
                        f"{entry['id']}: origin '{actual}' — NZOR biostatus says {expected} "
                        f"({', '.join(record['origins'])})"
                    )
        time.sleep(0.3)

        taxon = inat_taxon(scientific_name)
        time.sleep(0.3)

        # Te reo suggestion only — never written. See the note on FILLABLE.
        if not (entry.get("maoriName") or "").strip():
            suggestion = inat_maori_name(scientific_name)
            if suggestion:
                suggestions.append(f"{entry['id']}: maoriName? iNaturalist (mi) offers '{suggestion}'")
            time.sleep(0.3)

        # Fill only what is empty.
        for field in FILLABLE:
            existing = (entry.get(field) or "").strip() if isinstance(entry.get(field), str) else entry.get(field)
            if existing:
                kept.append(f"{entry['id']}.{field}")
                continue

            value = None
            if field == "moreImagesURL" and taxon and taxon.get("id"):
                value = f"https://inaturalist.nz/taxa/{taxon['id']}"

            if value:
                entry[field] = value
                filled.append(f"{entry['id']}.{field} = {value}")

        if arguments.stage_photos and taxon and taxon.get("id"):
            staged = stage_photos(
                entry["id"], taxon["id"],
                pathlib.Path(arguments.photo_dir) / entry["id"],
                arguments.photos_per_species,
            )
            if staged:
                staged_manifest[entry["id"]] = staged
                print(f"    staged {len(staged)} photo(s)")

    print("\n" + "=" * 72)
    print(f"would fill {len(filled)} empty field(s); left {len(kept)} existing value(s) untouched")
    for line in filled:
        print(f"  + {line}")
    if suggestions:
        print(f"\n{len(suggestions)} suggestion(s) — yours to accept or reject, nothing written:")
        for line in suggestions:
            print(f"  ? {line}")
    if disagreements:
        print(f"\n{len(disagreements)} disagreement(s) — reported only, nothing changed:")
        for line in disagreements:
            print(f"  ! {line}")

    if staged_manifest:
        directory = pathlib.Path(arguments.photo_dir)
        (directory / "manifest.json").write_text(json.dumps(staged_manifest, indent=2) + "\n")
        total = sum(len(v) for v in staged_manifest.values())
        print(f"\nstaged {total} photo(s) in {directory}/ — attach and caption them in CatalogueEditor")

    if not arguments.write:
        print("\nDry run. Re-run with --write to apply the fills above.")
        return 0

    CATALOGUE.write_text(json.dumps(entries, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    print(f"\nWrote {CATALOGUE}.")

    # Foundation's prettyPrinted differs from Python's in ways not worth reproducing here
    # (empty arrays, spacing around colons), and the byte-stability test enforces its
    # shape. Hand off to the canonical formatter rather than imitating it.
    print("Normalising to the canonical format…")
    result = subprocess.run(
        ["swift", "run", "--package-path", "Packages/ForageCatalogue", "catalogue-tool", "--normalise"],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        print(f"  {result.stdout.strip().splitlines()[-1]}")
    else:
        print(
            "  Could not run the normaliser. Run this before committing, or the byte-stability\n"
            "  test will fail:\n"
            "    (cd Packages/ForageCatalogue && swift run catalogue-tool --normalise)",
            file=sys.stderr,
        )
        return 1

    print("Then `swift run catalogue-tool --check` to confirm nothing is blocking.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
