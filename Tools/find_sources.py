"""Find a checkable reference for every entry that has none, and verify it before citing it.

A `sources` line is a promise that someone can go and look. So nothing here is written from
a guessed URL: each candidate is fetched, and it becomes a citation only if the page answers
and names the species. Registers tried, in order of how much they say about a species:

  - **NZPCN** (New Zealand Plant Conservation Network) — a factsheet per vascular plant,
    native or naturalised, with description, habitat and threats.
  - **NZOR** — the name record itself: current name, authority, New Zealand biostatus.

Landcare's fungal databases are not among them: Biota of New Zealand renders its results in
the browser, so a fetch returns the same empty shell for a real species and an invented one,
and Virtual Mycota's pages are keyed by opaque numbers with no search endpoint. The mushrooms
have to be sourced by hand.

None of these is a foraging text, so none verifies that something is *edible*. They verify
that the species is real, is recorded here, and is described by an institution you can check.
Edibility stays editorial.

A name record is weaker still: it says the name exists, nothing about the plant. Filling
`sources` with one would flip `isVerified` and take the entry off the pending list, claiming
a check nobody made — so NZOR is reported and not written unless you ask for it.

    python Tools/find_sources.py                 # report what it can find
    python Tools/find_sources.py --write
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

from sources import (
    CATALOGUE,
    COURTESY_DELAY,
    REQUEST_TIMEOUT,
    SSL_CONTEXT,
    USER_AGENT,
    Source,
    SourceError,
    get_json,
    write_catalogue,
)

NZPCN_FACTSHEET = "https://www.nzpcn.org.nz/flora/species/{slug}/"
NZOR_NAME_PAGE = "https://www.nzor.org.nz/names/{name_id}"

#: Names an entry may be listed under elsewhere. The catalogue keeps the name it prefers;
#: a register may only know the synonym, and a citation under that is still checkable.
SYNONYMS = {
    "Acca sellowiana": ["Feijoa sellowiana"],
    "Lysimachia arvensis": ["Anagallis arvensis"],
    "Psidium cattleyanum": ["Psidium cattleianum"],
}


@dataclass(frozen=True)
class Reference:
    citation: str
    url: str


def fetch_page(url: str) -> str | None:
    """The page's text, or None if it does not answer."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT, context=SSL_CONTEXT) as r:
            text: str = r.read().decode("utf-8", errors="replace")
            return text
    except (urllib.error.URLError, TimeoutError):
        return None


#: Whatever a page puts between the words of a name — a tag, a space, an italic close.
BETWEEN_WORDS = r"(?:<[^>]{0,80}>|[^A-Za-z<]){0,8}"


def mentions(page: str, name: str) -> bool:
    """Whether the page actually names the species, ignoring any markup between the words."""
    words = [re.escape(word) for word in name.split() if len(word) > 2]
    return bool(words) and re.search(BETWEEN_WORDS.join(words), page, re.I) is not None


def slugs_for(name: str) -> list[tuple[str, str]]:
    """(name, slug) for the entry's own name and any name a register may file it under."""
    candidates = [name, *SYNONYMS.get(name, [])]
    return [
        (candidate, re.sub(r"[^a-z0-9]+", "-", candidate.lower()).strip("-"))
        for candidate in candidates
    ]


def nzpcn_reference(name: str, retrieved: date) -> Reference | None:
    for candidate, slug in slugs_for(name):
        url = NZPCN_FACTSHEET.format(slug=slug)
        page = fetch_page(url)
        time.sleep(COURTESY_DELAY)
        # The page has to name the species it was asked for — under a synonym it will carry
        # that synonym, not ours, so it is checked against the name that built the URL.
        if page and mentions(page, candidate.split(" spp")[0]):
            return Reference(
                f"New Zealand Plant Conservation Network. '{candidate}' fact sheet. "
                f"Retrieved {retrieved:%d/%m/%Y}. {url}",
                url,
            )
    return None


def nzor_reference(name: str, retrieved: date) -> Reference | None:
    """The NZOR name record: what the species is called here, and that it is recorded here."""
    try:
        results = get_json(Source.NZOR_SEARCH, {"query": name}).get("results") or []
    except SourceError:
        return None
    time.sleep(COURTESY_DELAY)
    for result in results:
        record: dict[str, Any] = result.get("name") or {}
        if record.get("class") != "Scientific Name":
            continue
        name_id = record.get("nameId")
        partial = str(record.get("partialName") or "")
        if not name_id or partial.casefold() != name.casefold():
            continue
        url = NZOR_NAME_PAGE.format(name_id=name_id)
        return Reference(
            f"New Zealand Organisms Register. Name record for '{partial}' "
            f"({record.get('status', 'unknown')} name). Retrieved {retrieved:%d/%m/%Y}. {url}",
            url,
        )
    return None


def species_name(entry: dict[str, Any]) -> str:
    """The one name to look up for an entry.

    A register page covers a single species, so an entry naming two ("Prunus domestica /
    Prunus cerasifera") is looked up under the first, and a group ("Lactarius spp.") under its
    genus. A parenthesised aside is a note about the name, not part of it.
    """
    first = str(entry["scientificName"]).split(" / ")[0]
    return re.sub(r"\s*\(.*\)|\s+spp?\.$", "", first).strip()


def references_for(entry: dict[str, Any], retrieved: date) -> list[Reference]:
    """Everything that answers for this entry, most informative first."""
    name = species_name(entry)
    if not name:
        return []
    reference = nzpcn_reference(name, retrieved)
    return [reference] if reference else []


def name_record_for(entry: dict[str, Any], retrieved: date) -> Reference | None:
    name = species_name(entry)
    return nzor_reference(name, retrieved) if name else None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    parser.add_argument("--only", default="", help="comma-separated ids")
    parser.add_argument("--write", action="store_true", help="add the citations found")
    parser.add_argument(
        "--name-records",
        action="store_true",
        help="also cite NZOR name records, which say the name exists and nothing more",
    )
    args = parser.parse_args(argv)

    catalogue: list[dict[str, Any]] = json.loads(args.catalogue.read_text())
    only = {i for i in args.only.split(",") if i}
    today = date.today()

    found_for: dict[str, list[Reference]] = {}
    for entry in catalogue:
        if only and entry["id"] not in only:
            continue
        if not only and entry["sources"]:
            continue
        references = references_for(entry, today)
        if args.name_records:
            record = name_record_for(entry, today)
            if record:
                references.append(record)
        if references:
            found_for[entry["id"]] = references
            if args.write:
                entry["sources"].extend(
                    r.citation for r in references if r.citation not in entry["sources"]
                )
        print(f"{entry['id']:26} {len(references)} found")
        for reference in references:
            print(f"    {reference.url}")

    if args.write:
        write_catalogue(catalogue, args.catalogue)
    print(f"\n{len(found_for)} entries can be cited")
    return 0


if __name__ == "__main__":
    sys.exit(main())
