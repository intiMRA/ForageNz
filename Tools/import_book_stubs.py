"""Create draft catalogue entries from an index of a field guide's species entries.

Only facts that are not authorship come across: the entry title as the common name, the
scientific and Māori names, and a season parsed from month and season words. Every field
that would need writing — summary, identification, habitat, edible parts, preparation,
warnings, lookalikes — is left empty, and the entry is marked `draft` so the app never
lists it. `fetch_descriptions.py` fills the description fields from openly licensed text;
the safety fields are yours.

The index file is not part of the repo (it holds fragments of a copyrighted book). Build it
from your own copy and pass its path. Each record needs `title`, `scientific`, `maori`,
`season` and `page`.

    python Tools/import_book_stubs.py --index /path/to/index.json --skip-pages 421,699 --dry-run
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from enrich_catalogue import fetch_nzor
from sources import CATALOGUE, COURTESY_DELAY, write_catalogue

#: Default citation, overridable with --citation. The book's own heading for the species is
#: appended when the index carries one, never the common name we chose for the entry.
BOOK_CITATION = "Langlands, Peter. Foraging New Zealand (Penguin Random House NZ, 2024)"


def cite(base: str, heading: str | None) -> str:
    """The source line: the book, plus the entry a reader should turn to when we know it."""
    return f"{base}, '{heading}' entry." if heading else f"{base}."


MONTHS = {
    "january": 1,
    "february": 2,
    "march": 3,
    "april": 4,
    "may": 5,
    "june": 6,
    "july": 7,
    "august": 8,
    "september": 9,
    "october": 10,
    "november": 11,
    "december": 12,
}
# Southern-hemisphere seasons.
SEASONS = {
    "spring": (9, 10, 11),
    "summer": (12, 1, 2),
    "autumn": (3, 4, 5),
    "winter": (6, 7, 8),
}
YEAR_ROUND = re.compile(r"year[- ]round|all year|throughout the year|any time of (the )?year", re.I)
QUALIFIER = r"(?:(?:late|early|mid)[- ]?)?"
MONTH = r"\b(" + "|".join(MONTHS) + r")\b"
RANGE = re.compile(
    QUALIFIER + MONTH + r"\s+(?:to|until|through|\u2013|-)\s+" + QUALIFIER + MONTH, re.I
)


def blank() -> dict[str, Any]:
    """A prose field with nothing written yet: `{"text", "sources"}`, so a credit can sit
    beside the exact paragraph it applies to. A fresh dict each time — never shared."""
    return {"text": "", "sources": []}


def slugify(title: str) -> str:
    """`Buck's-horn plantain` → `bucks-horn-plantain`. Apostrophes and macrons fold away.

    Must not start with a digit — `SpeciesID` case names cannot.
    """
    ascii_title = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode()
    slug = re.sub(r"[^a-z0-9]+", "-", re.sub(r"['\u2019]", "", ascii_title.lower())).strip("-")
    return slug if slug and not slug[0].isdigit() else f"species-{slug}"


def months_in_range(start: int, end: int) -> list[int]:
    months = [start]
    while months[-1] != end:
        months.append(months[-1] % 12 + 1)
    return months


def named_months(text: str) -> list[int]:
    """Months named in `text`, expanding ranges and season words. Empty if none."""
    months: list[int] = []
    for start, end in RANGE.findall(text):
        months.extend(months_in_range(MONTHS[start.lower()], MONTHS[end.lower()]))
    if not months:
        for word in re.findall(r"[A-Za-z]+", text):
            lowered = word.lower()
            if lowered in MONTHS:
                months.append(MONTHS[lowered])
            elif lowered in SEASONS:
                months.extend(SEASONS[lowered])
    return sorted(set(months))


def parse_months(season: str) -> list[int] | None:
    """Months named in a seasonality sentence. Empty list = year-round; None = could not tell.

    A stated peak wins over a longer main season, matching how the catalogue uses `months`.
    Unparseable text returns None so the caller can flag it rather than silently claiming
    year-round availability.
    """
    text = season.strip()
    if not text:
        return None
    peak = re.search(r"peak[^.]*", text, re.I)
    if peak:
        found = named_months(peak.group(0))
        if found:
            return found
    found = named_months(text)
    if found:
        return found
    if YEAR_ROUND.search(text):
        return []
    return None


FRUIT_WORDS = (
    "berry",
    "berries",
    "plum",
    "apple",
    "grape",
    "fruit",
    "cherry",
    "fig",
    "passion",
    "guava",
    "rose",
    "haw",
)
NUT_WORDS = ("nut", "acorn", "chestnut", "seed")
HERB_WORDS = (
    "mint",
    "thyme",
    "oregano",
    "fennel",
    "sage",
    "horopito",
    "pepper",
    "kawakawa",
    "mānuka",
    "kānuka",
    "bay",
)


def guess_category(title: str, page: int, seaweed_from: int, fungi_from: int) -> str:
    """A first guess from the book's chapter order and the title — review it in the editor."""
    if fungi_from and page >= fungi_from:
        return "fungi"
    if seaweed_from and page >= seaweed_from:
        return "seaweed"
    lowered = title.lower()

    def mentions(words: tuple[str, ...]) -> bool:
        # Suffix match: "barberry" and "spearmint" count, "pineappleweed" and "hawkweed" do not.
        return any(re.search(rf"{word}(s|es)?\b", lowered) for word in words)

    # Herbs before fruit: "apple mint" is a herb.
    if mentions(HERB_WORDS):
        return "herbs"
    if mentions(NUT_WORDS):
        return "nuts"
    if mentions(FRUIT_WORDS):
        return "fruit"
    return "greens"


def first_scientific_name(text: str) -> str:
    """`Sonchus asper, sonchus oleraceus` → `Sonchus asper`; drops trailing prose.

    A parenthesised aside ("(formerly …)", "(and other species)") is an editorial note about
    the name, not part of it.
    """
    head = re.split(r"[,;(]| There |(?<=\.)\s", text.strip(), maxsplit=1)[0].strip()
    parts = head.split()
    return " ".join(parts[:3]) if len(parts) > 3 else head


@dataclass(frozen=True)
class Stub:
    entry: dict[str, Any]
    season_unparsed: bool
    origin_unknown: bool


def make_stub(
    record: dict[str, Any],
    origin: str | None,
    seaweed_from: int,
    fungi_from: int,
    citation: str = BOOK_CITATION,
) -> Stub:
    title = str(record["title"]).replace("\u2019", "'")
    heading = record.get("bookTitle") or None
    months = parse_months(str(record.get("season") or ""))
    maori = str(record.get("maori") or "").strip()
    entry: dict[str, Any] = {
        "id": slugify(title),
        "commonName": title,
        "maoriName": maori or None,
        "scientificName": first_scientific_name(str(record["scientific"])),
        "group": guess_category(title, int(record["page"]), seaweed_from, fungi_from),
        "origin": origin or "introduced",
        # Edible according to the book, but nothing here yet says how — never "straightforward".
        "caution": "careRequired",
        "months": months or [],
        "summary": blank(),
        "habitat": blank(),
        "identification": blank(),
        "edibleParts": blank(),
        "preparation": blank(),
        "lookalikes": [],
        "warnings": [],
        "harvestEthics": None,
        "sources": [cite(citation, heading)],
        "recipes": [],
        "photos": [],
        "moreImagesURL": record.get("moreImagesURL"),
        "draft": True,
    }
    entry = {key: value for key, value in entry.items() if value is not None}
    return Stub(entry=entry, season_unparsed=months is None, origin_unknown=origin is None)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    parser.add_argument(
        "--skip-pages", default="", help="comma-separated index pages already in the catalogue"
    )
    # No defaults: one book's chapter boundaries are meaningless in another's page numbers.
    # 0 disables the guess, leaving the group to the title alone.
    parser.add_argument(
        "--seaweed-from",
        type=int,
        required=True,
        help="first index page of the seaweed chapter, 0 if none",
    )
    parser.add_argument(
        "--fungi-from",
        type=int,
        required=True,
        help="first index page of the fungi chapter, 0 if none",
    )
    parser.add_argument("--no-nzor", action="store_true", help="skip the origin lookup (offline)")
    parser.add_argument(
        "--citation",
        default=BOOK_CITATION,
        help="the book; its heading is appended as \", 'Heading' entry.\" when the index has one",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    records: list[dict[str, Any]] = json.loads(args.index.read_text())
    catalogue: list[dict[str, Any]] = json.loads(args.catalogue.read_text())
    skip = {int(page) for page in args.skip_pages.split(",") if page.strip()}
    existing_ids = {entry["id"] for entry in catalogue}
    existing_names = {entry["scientificName"].lower() for entry in catalogue}

    added: list[Stub] = []
    skipped: list[str] = []
    for record in records:
        if int(record["page"]) in skip:
            continue
        scientific = first_scientific_name(str(record["scientific"]))
        candidate_id = slugify(str(record["title"]).replace("\u2019", "'"))
        if candidate_id in existing_ids or scientific.lower() in existing_names:
            skipped.append(candidate_id)
            continue
        # A validated index already carries NZOR's answer; only ask again when it does not.
        origin: str | None = record.get("origin")
        if origin is None and not args.no_nzor:
            nzor = fetch_nzor(scientific)
            origin = nzor.catalogue_origin if nzor else None
            time.sleep(COURTESY_DELAY)
        stub = make_stub(record, origin, args.seaweed_from, args.fungi_from, args.citation)
        existing_ids.add(stub.entry["id"])
        existing_names.add(stub.entry["scientificName"].lower())
        added.append(stub)

    print(
        f"{len(added)} stubs, {len(skipped)} skipped as already present: "
        f"{', '.join(skipped) or '-'}"
    )
    print(
        f"season unparsed ({sum(s.season_unparsed for s in added)}): "
        + ", ".join(s.entry["id"] for s in added if s.season_unparsed)
    )
    print(
        f"origin unknown, defaulted to introduced ({sum(s.origin_unknown for s in added)}): "
        + ", ".join(s.entry["id"] for s in added if s.origin_unknown)
    )
    if args.dry_run:
        return 0
    catalogue.extend(stub.entry for stub in added)
    write_catalogue(catalogue, args.catalogue)
    print(
        f"wrote {len(catalogue)} entries to {args.catalogue}; run catalogue-tool --normalise next"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
