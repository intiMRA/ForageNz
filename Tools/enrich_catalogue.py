#!/usr/bin/env python3
"""Fill gaps in the catalogue from NZOR and iNaturalist, without ever overwriting you.

THE RULE: a field you have written is never touched. This script only fills fields that
are empty, and only fields that are matters of record rather than judgement. Everything
safety-critical — identification, warnings, lookalikes, preparation, edible parts,
harvesting guidance, sources, recipes, caution level — it will not write under any
circumstances, even if blank. Those come from your books.

It is also NOT a discovery tool. It iterates the species already in the catalogue and
looks each one up by the scientific name you gave it; it cannot add a species you have
not vetted, and a guard enforces that. No database it queries knows what is edible —
iNaturalist, NZOR and GBIF carry taxonomy, distribution and conservation status, not
edibility. Deciding something is foragable is the editorial layer, and it stays yours.

Where an external source disagrees with something you wrote, it is REPORTED and left
alone. A scientific name that has become a synonym, or an origin that contradicts NZOR's
biostatus, is a decision for you.

    python3 Tools/enrich_catalogue.py                # dry run: report only
    python3 Tools/enrich_catalogue.py --write        # apply the fills, then normalise
    python3 Tools/enrich_catalogue.py --stage-photos # download CC-licensed candidates

Photos are staged, never attached: a photo needs a caption naming the feature it shows,
which is a human judgement. Attach them in the CatalogueEditor.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from collections.abc import Iterator
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Any

from sources import (
    COURTESY_DELAY,
    NEW_ZEALAND_PLACE_ID,
    Licence,
    Source,
    SourceError,
    get_json,
    licensed_photos,
    results_of,
)

CATALOGUE = Path("ForageNZ/Catalogue/species.json")
NORMALISER = [
    "swift",
    "run",
    "--package-path",
    "Packages/ForageCatalogue",
    "catalogue-tool",
    "--normalise",
]


class Field(StrEnum):
    """Catalogue fields this script reasons about."""

    ID = "id"
    MAORI_NAME = "maoriName"
    MONTHS = "months"
    SCIENTIFIC_NAME = "scientificName"
    ORIGIN = "origin"
    MORE_IMAGES_URL = "moreImagesURL"


class Policy(StrEnum):
    """What this script may do to a field."""

    FILL_WHEN_EMPTY = "fill-when-empty"
    NEVER_WRITE = "never-write"
    REPORT_ONLY = "report-only"


# One source of truth for how each field is treated. Anything absent is never written,
# which makes the safe case the default.
#
# MAORI_NAME is NEVER_WRITE on evidence: iNaturalist's preferred_common_name is
# locale-dependent and defaults to English, and offered "Persian walnut", "King Bolete"
# and "garden nasturtium" as te reo names. `locale=mi` is far too patchy — nothing for
# kawakawa or horopito, whose te reo names ARE their common names — so candidates are
# reported as suggestions instead.
FIELD_POLICY: dict[Field, Policy] = {
    Field.MORE_IMAGES_URL: Policy.FILL_WHEN_EMPTY,
    Field.SCIENTIFIC_NAME: Policy.REPORT_ONLY,
    Field.ORIGIN: Policy.REPORT_ONLY,
    Field.MAORI_NAME: Policy.NEVER_WRITE,
    Field.MONTHS: Policy.REPORT_ONLY,
}


class NzorOrigin(StrEnum):
    """NZOR biostatus values, mapped to the catalogue's origins."""

    ENDEMIC = "Endemic"
    NON_ENDEMIC = "Non-endemic"
    INDIGENOUS = "Indigenous"
    EXOTIC = "Exotic"

    @property
    def catalogue_origin(self) -> str:
        """`Non-endemic` is still indigenous — it occurs naturally here and elsewhere."""
        if self is NzorOrigin.EXOTIC:
            return "introduced"
        return "endemic" if self is NzorOrigin.ENDEMIC else "native"


class EstablishmentMeans(StrEnum):
    """iNaturalist's establishment means for a place."""

    ENDEMIC = "endemic"
    NATIVE = "native"
    INTRODUCED = "introduced"

    @property
    def catalogue_origin(self) -> str:
        return str(self)


def origins_consistent_with(expected: str) -> set[str]:
    """Catalogue origins that do not contradict what a source says.

    Neither source separates an introduced species from a declared pest, so `pest` is
    consistent with `introduced`. A source saying `native` without claiming endemism is
    consistent with either — most sources simply don't record endemism — but a catalogue
    entry marked `endemic` when a source says the species occurs elsewhere is a real
    disagreement, and the reverse (source says endemic, catalogue says native) is only a
    missed upgrade, reported as a suggestion rather than a conflict.
    """
    if expected == "introduced":
        return {"introduced", "pest"}
    if expected == "endemic":
        return {"endemic", "native"}
    return {expected}


class FindingKind(StrEnum):
    FILLED = "filled"
    SUGGESTION = "suggestion"
    DISAGREEMENT = "disagreement"


@dataclass(frozen=True)
class Finding:
    kind: FindingKind
    species_id: str
    message: str

    @property
    def marker(self) -> str:
        markers = {
            FindingKind.FILLED: "+",
            FindingKind.SUGGESTION: "?",
            FindingKind.DISAGREEMENT: "!",
        }
        return markers[self.kind]


@dataclass(frozen=True)
class NzorRecord:
    status: str | None
    #: Present and different from the queried name means yours is a synonym.
    accepted_name: str | None
    origins: tuple[NzorOrigin, ...]

    @property
    def catalogue_origin(self) -> str | None:
        for origin in self.origins:
            if origin is not NzorOrigin.EXOTIC:
                return origin.catalogue_origin
        return self.origins[0].catalogue_origin if self.origins else None


@dataclass(frozen=True)
class InatTaxon:
    taxon_id: int
    scientific_name: str
    preferred_common_name: str | None

    @property
    def taxon_page(self) -> str:
        return f"https://inaturalist.nz/taxa/{self.taxon_id}"


@dataclass(frozen=True)
class InatDetail:
    """Place-scoped facts iNaturalist holds about a taxon in New Zealand."""

    establishment_means: EstablishmentMeans | None
    conservation_status: str | None


@dataclass(frozen=True)
class Seasonality:
    """Research-grade NZ observations per month — when people actually find it."""

    counts: dict[int, int]

    #: A month counts as part of the season at or above this share of the peak month.
    PEAK_SHARE = 0.25
    #: Below this many observations the shape is noise.
    MINIMUM_OBSERVATIONS = 30
    #: A peak spanning more than this many months says nothing a year-round entry
    #: does not already say. Perennials get photographed all year regardless of when
    #: they are worth picking.
    NARROW_ENOUGH_TO_MENTION = 7

    @property
    def total(self) -> int:
        return sum(self.counts.values())

    @property
    def is_meaningful(self) -> bool:
        return self.total >= self.MINIMUM_OBSERVATIONS

    @property
    def peak_months(self) -> tuple[int, ...]:
        if not self.counts:
            return ()
        threshold = max(self.counts.values()) * self.PEAK_SHARE
        return tuple(sorted(month for month, count in self.counts.items() if count >= threshold))


@dataclass(frozen=True)
class StagedPhoto:
    file: str
    licence: Licence
    credit: str
    source_url: str | None

    def as_manifest_entry(self) -> dict[str, str]:
        return {
            "file": self.file,
            "licence": str(self.licence),
            "credit": self.credit,
            "sourceURL": self.source_url or "",
            "caption": "",  # yours to write — the app requires it
        }


def fetch_nzor(scientific_name: str) -> NzorRecord | None:
    """NZOR's view of a name: whether it is current, and its New Zealand biostatus."""
    try:
        results = results_of(Source.NZOR_SEARCH, {"query": scientific_name})
    except SourceError as error:
        print(f"    NZOR lookup failed: {error}", file=sys.stderr)
        return None

    for result in results:
        name: dict[str, Any] = result.get("name") or {}
        if name.get("class") != "Scientific Name":
            continue

        origins: list[NzorOrigin] = []
        for status in name.get("biostatuses") or []:
            for value in status.get("origin") or []:
                try:
                    origins.append(NzorOrigin(value))
                except ValueError:
                    continue  # a biostatus vocabulary we don't model

        return NzorRecord(
            status=name.get("status"),
            accepted_name=(name.get("acceptedName") or {}).get("partialName"),
            origins=tuple(origins),
        )
    return None


def fetch_inat_taxon(scientific_name: str, locale: str | None = None) -> InatTaxon | None:
    params: dict[str, object] = {"q": scientific_name, "rank": "species", "per_page": 1}
    if locale:
        params["locale"] = locale
    try:
        results = results_of(Source.INAT_TAXA, params)
    except SourceError as error:
        print(f"    iNaturalist lookup failed: {error}", file=sys.stderr)
        return None
    if not results:
        return None

    first = results[0]
    common = str(first.get("preferred_common_name") or "").strip()
    raw_id = first.get("id")
    if not isinstance(raw_id, int):
        raise SourceError(f"iNaturalist taxon result without a numeric id: {first!r}")
    taxon_id = raw_id
    return InatTaxon(
        taxon_id=taxon_id,
        scientific_name=str(first.get("name") or scientific_name),
        preferred_common_name=common or None,
    )


def fetch_inat_detail(taxon_id: int) -> InatDetail | None:
    """Establishment means and conservation status, scoped to New Zealand."""
    try:
        results = results_of(f"{Source.INAT_TAXA}/{taxon_id}", {})
    except SourceError as error:
        print(f"    iNaturalist detail failed: {error}", file=sys.stderr)
        return None
    if not results:
        return None

    taxon = results[0]
    means: EstablishmentMeans | None = None
    for listing in taxon.get("listed_taxa") or []:
        if (listing.get("place") or {}).get("id") != NEW_ZEALAND_PLACE_ID:
            continue
        try:
            means = EstablishmentMeans(listing.get("establishment_means"))
        except ValueError:
            means = None
        break

    status = taxon.get("conservation_status") or {}
    return InatDetail(
        establishment_means=means,
        conservation_status=(status.get("status_name") or status.get("status")) or None,
    )


def fetch_seasonality(taxon_id: int) -> Seasonality | None:
    """When this species is actually observed in New Zealand."""
    try:
        payload = get_json(
            Source.INAT_HISTOGRAM,
            {
                "taxon_id": taxon_id,
                "place_id": NEW_ZEALAND_PLACE_ID,
                "date_field": "observed",
                "interval": "month_of_year",
                "quality_grade": "research",
            },
        )
    except SourceError as error:
        print(f"    seasonality lookup failed: {error}", file=sys.stderr)
        return None

    histogram = (payload.get("results") or {}).get("month_of_year") or {}
    counts = {int(month): int(count) for month, count in histogram.items() if int(count) > 0}
    return Seasonality(counts=counts)


def stage_photos(species_id: str, taxon_id: int, directory: Path, wanted: int) -> list[StagedPhoto]:
    directory.mkdir(parents=True, exist_ok=True)
    staged: list[StagedPhoto] = []
    try:
        results = results_of(
            Source.INAT_OBSERVATIONS,
            {
                "taxon_id": taxon_id,
                "quality_grade": "research",
                "photo_license": Licence.query_value(),
                "per_page": wanted * 3,
                "order_by": "votes",
            },
        )
    except SourceError as error:
        print(f"    photo search failed: {error}", file=sys.stderr)
        return staged

    for path, licence, photo, observation in licensed_photos(
        results, directory, species_id, wanted, size="large"
    ):
        staged.append(
            StagedPhoto(
                file=path.name,
                licence=licence,
                credit=str(photo.get("attribution") or ""),
                source_url=observation.get("uri"),
            )
        )
    return staged


MONTH_NAMES = (
    "-",
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
)


def describe_months(months: tuple[int, ...] | list[int]) -> str:
    return " ".join(MONTH_NAMES[month] for month in sorted(months)) or "year-round"


def inspect_seasonality(
    entry: dict[str, Any], seasonality: Seasonality | None
) -> Iterator[Finding]:
    """Compare the catalogue's season to when the species is actually observed.

    Observation counts are NOT a harvest window. For fungi the two align closely — you see
    one when it fruits — but a perennial like kawakawa is photographed year-round
    regardless of when its leaves are worth picking. Always a suggestion, never a fill.
    """
    if seasonality is None or not seasonality.is_meaningful:
        return

    species_id = str(entry[Field.ID])
    observed = seasonality.peak_months
    recorded = [int(month) for month in entry.get(Field.MONTHS) or []]

    if not recorded:
        # An all-year peak agrees with a year-round entry; reporting it is noise.
        if len(observed) <= Seasonality.NARROW_ENOUGH_TO_MENTION:
            yield Finding(
                FindingKind.SUGGESTION,
                species_id,
                f"{Field.MONTHS} is year-round; NZ observations peak "
                f"{describe_months(observed)} ({seasonality.total} records)",
            )
        return

    if not set(recorded) & set(observed):
        yield Finding(
            FindingKind.DISAGREEMENT,
            species_id,
            f"{Field.MONTHS} {describe_months(recorded)} does not overlap the observed peak "
            f"{describe_months(observed)} ({seasonality.total} records)",
        )


def inspect_entry(
    entry: dict[str, Any],
    nzor: NzorRecord | None,
    maori_candidate: InatTaxon | None,
    detail: InatDetail | None = None,
) -> Iterator[Finding]:
    """Disagreements between the catalogue and an external source. Never applied."""
    species_id = str(entry[Field.ID])
    scientific_name = str(entry.get(Field.SCIENTIFIC_NAME) or "").strip()

    if nzor:
        accepted = nzor.accepted_name
        if accepted and accepted.casefold() != scientific_name.casefold():
            yield Finding(
                FindingKind.DISAGREEMENT,
                species_id,
                f"{Field.SCIENTIFIC_NAME} '{scientific_name}' — NZOR accepts '{accepted}'",
            )

        expected = nzor.catalogue_origin
        actual = str(entry.get(Field.ORIGIN) or "")
        if expected is not None and actual not in origins_consistent_with(expected):
            yield Finding(
                FindingKind.DISAGREEMENT,
                species_id,
                f"{Field.ORIGIN} '{actual}' — NZOR biostatus says {expected} "
                f"({', '.join(str(origin) for origin in nzor.origins)})",
            )
        elif expected == "endemic" and actual == "native":
            yield Finding(
                FindingKind.SUGGESTION,
                species_id,
                f"{Field.ORIGIN} could be 'endemic' — NZOR biostatus says Endemic",
            )

    if detail:
        means = detail.establishment_means
        actual = str(entry.get(Field.ORIGIN) or "")
        if means:
            expected = means.catalogue_origin
            if actual not in origins_consistent_with(expected):
                yield Finding(
                    FindingKind.DISAGREEMENT,
                    species_id,
                    f"{Field.ORIGIN} '{actual}' — iNaturalist lists it as '{means}' in New Zealand",
                )
            elif expected == "endemic" and actual == "native":
                yield Finding(
                    FindingKind.SUGGESTION,
                    species_id,
                    f"{Field.ORIGIN} could be 'endemic' — iNaturalist lists it as endemic "
                    "in New Zealand",
                )

        if detail.conservation_status:
            yield Finding(
                FindingKind.DISAGREEMENT,
                species_id,
                f"has a conservation status ('{detail.conservation_status}') — "
                "check before presenting it as foragable",
            )

    if (
        maori_candidate
        and maori_candidate.preferred_common_name
        and not str(entry.get(Field.MAORI_NAME) or "").strip()
    ):
        yield Finding(
            FindingKind.SUGGESTION,
            species_id,
            f"{Field.MAORI_NAME}? iNaturalist (mi) offers "
            f"'{maori_candidate.preferred_common_name}'",
        )


def fill_entry(entry: dict[str, Any], taxon: InatTaxon | None) -> Iterator[Finding]:
    """Fill only empty fields, and only those declared FILL_WHEN_EMPTY.

    "Empty" means absent, null, or the empty string — NOT whitespace. The rule that this
    script never overwrites is worth keeping total: an exception for "looks blank enough"
    is one somebody has to remember, and the two failure modes are not symmetric. Not
    filling is fixed by deleting a space; overwriting loses what you wrote. A field
    holding only whitespace is reported instead, so it cannot silently block enrichment.
    """
    species_id = str(entry[Field.ID])
    for field, policy in FIELD_POLICY.items():
        if policy is not Policy.FILL_WHEN_EMPTY:
            continue

        current = entry.get(field)
        if current is not None and current != "":
            if isinstance(current, str) and not current.strip():
                yield Finding(
                    FindingKind.SUGGESTION,
                    species_id,
                    f"{field} holds only whitespace, so it is left alone — "
                    "clear it to allow filling",
                )
            continue  # yours — never touched

        value: str | None = None
        if field is Field.MORE_IMAGES_URL and taxon:
            value = taxon.taxon_page

        if value:
            entry[field] = value
            yield Finding(FindingKind.FILLED, species_id, f"{field} = {value}")


def report(findings: list[Finding], kind: FindingKind, heading: str) -> None:
    selected = [finding for finding in findings if finding.kind is kind]
    if not selected:
        return
    print(f"\n{len(selected)} {heading}")
    for finding in selected:
        print(f"  {finding.marker} {finding.species_id}: {finding.message}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--write", action="store_true", help="apply the fills (default is a dry run)"
    )
    parser.add_argument(
        "--stage-photos", action="store_true", help="download CC-licensed candidates"
    )
    parser.add_argument("--photo-dir", type=Path, default=Path(".staged-photos"))
    parser.add_argument("--photos-per-species", type=int, default=6)
    parser.add_argument("--only", help="comma-separated species ids")
    arguments = parser.parse_args()

    if not CATALOGUE.exists():
        print(f"No catalogue at {CATALOGUE} — run from the repo root.", file=sys.stderr)
        return 1

    try:
        entries: list[dict[str, Any]] = json.loads(CATALOGUE.read_text())
    except (OSError, json.JSONDecodeError) as error:
        print(f"Couldn't read {CATALOGUE}: {error}", file=sys.stderr)
        return 1
    identifiers_before = {str(entry[Field.ID]) for entry in entries}
    wanted = set(arguments.only.split(",")) if arguments.only else None

    findings: list[Finding] = []
    staged_manifest: dict[str, list[dict[str, str]]] = {}

    for entry in entries:
        species_id = str(entry[Field.ID])
        if wanted and species_id not in wanted:
            continue
        scientific_name = str(entry.get(Field.SCIENTIFIC_NAME) or "").strip()
        if not scientific_name:
            print(f"{species_id}: no scientific name yet, skipping")
            continue

        print(f"{species_id} ({scientific_name})")

        nzor = fetch_nzor(scientific_name)
        time.sleep(COURTESY_DELAY)
        taxon = fetch_inat_taxon(scientific_name)
        time.sleep(COURTESY_DELAY)
        maori_candidate = fetch_inat_taxon(scientific_name, locale="mi")
        time.sleep(COURTESY_DELAY)

        detail = fetch_inat_detail(taxon.taxon_id) if taxon else None
        time.sleep(COURTESY_DELAY)
        seasonality = fetch_seasonality(taxon.taxon_id) if taxon else None
        time.sleep(COURTESY_DELAY)

        findings.extend(inspect_entry(entry, nzor, maori_candidate, detail))
        findings.extend(inspect_seasonality(entry, seasonality))
        findings.extend(fill_entry(entry, taxon))

        if arguments.stage_photos and taxon:
            staged = stage_photos(
                species_id,
                taxon.taxon_id,
                arguments.photo_dir / species_id,
                arguments.photos_per_species,
            )
            if staged:
                staged_manifest[species_id] = [photo.as_manifest_entry() for photo in staged]
                print(f"    staged {len(staged)} photo(s)")

    # This script enriches; it never curates. Deciding a species is foragable is editorial,
    # and no source it queries knows what is edible.
    if {str(entry[Field.ID]) for entry in entries} != identifiers_before:
        print(
            "Refusing to write: the entry set changed, which this script must never do.",
            file=sys.stderr,
        )
        return 1

    print("\n" + "=" * 72)
    filled = sum(1 for finding in findings if finding.kind is FindingKind.FILLED)
    print(f"{filled} empty field(s) to fill; every existing value left untouched")
    report(findings, FindingKind.FILLED, "fill(s):")
    report(
        findings,
        FindingKind.SUGGESTION,
        "suggestion(s) — yours to accept or reject, nothing written:",
    )
    report(
        findings,
        FindingKind.DISAGREEMENT,
        "disagreement(s) — reported only, nothing changed:",
    )

    if staged_manifest:
        manifest_path = arguments.photo_dir / "manifest.json"
        manifest_path.write_text(json.dumps(staged_manifest, indent=2) + "\n")
        total = sum(len(photos) for photos in staged_manifest.values())
        print(
            f"\nstaged {total} photo(s) in {arguments.photo_dir}/ — "
            "attach and caption them in CatalogueEditor"
        )

    if not arguments.write:
        print("\nDry run. Re-run with --write to apply the fills above.")
        return 0

    CATALOGUE.write_text(json.dumps(entries, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    print(f"\nWrote {CATALOGUE}.")

    # Foundation's prettyPrinted differs from Python's (empty arrays, spacing around
    # colons) and the byte-stability test enforces its shape. Hand off to the canonical
    # formatter rather than imitating it.
    print("Normalising to the canonical format…")
    result = subprocess.run(NORMALISER, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        print(
            "  Could not run the normaliser. Run this before committing, or the\n"
            "  byte-stability test will fail:\n"
            "    (cd Packages/ForageCatalogue && swift run catalogue-tool --normalise)",
            file=sys.stderr,
        )
        return 1

    lines = result.stdout.strip().splitlines()
    print(f"  {lines[-1] if lines else '(normaliser printed nothing)'}")
    print("Then `swift run catalogue-tool --check` to confirm nothing is blocking.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
