"""Turn scientific names scraped from a book into an index only real NZ taxa survive.

A scanned book read by OCR yields plausible-looking rubbish alongside real names — a
heading like "Dandelion coffee" parses as a binomial just as readily as *Allium vineale*
does. Stubbing that list unchecked would put invented species into a safety-critical file,
so every candidate is confirmed against two independent registers before it can become an
entry:

  - **NZOR** must know the name and give it a New Zealand biostatus. That is what says the
    species is real *and* recorded here; the biostatus also supplies the origin.
  - **iNaturalist** supplies the common name and taxon page, so the entry's common name
    comes from a register rather than from OCR.

The output is an index in the shape `import_book_stubs.py` reads, so the two compose:

    python Tools/validate_candidates.py --candidates cands.json --out index.json
    python Tools/import_book_stubs.py --index index.json --citation "Knox, Johanna. …"

Each candidate needs `scientific`; `title` and `page` are carried through when present.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from enrich_catalogue import fetch_inat_taxon, fetch_nzor
from sources import COURTESY_DELAY

#: iNaturalist's placeholders for "this taxon has no vernacular name".
NO_COMMON_NAME = {"no common name", "none", "-"}
#: An image caption's position marker, not part of a heading.
CAPTION_MARKER = re.compile(
    r"\s*\((?:above|below|left|right|opposite|top|bottom|centre|center|middle)\)\s*$", re.I
)
#: The scan breaks ligatures across a space: "offi cinale", "fr uticulosa".
BROKEN_LIGATURE = re.compile(r"\w*f[ilr]\s+[a-z]{2,}")
BINOMIAL = re.compile(r"^[A-Z][a-z]+ (?:x )?[a-z][a-z-]+$")
CONNECTIVE = re.compile(r"^(?:or|and|with|see)\b", re.I)
#: Shorter than this and a heading is a fragment, not a name.
MIN_HEADING_CHARS = 4
#: Words this long or longer carry the meaning; "of", "the" and the like do not.
MIN_MATCHED_WORD = 4
#: A qualifier as short as "sea" or "red" is what separates two species, so the heading side
#: is read down to three letters. Our own side keeps the longer floor, so a book's shorter
#: form of our name ("Raspberry" for "Red raspberry") still verifies.
MIN_DISTINGUISHING_WORD = 3


def tidy_name(name: str) -> str:
    """The register's common name, trimmed, with a capital first letter.

    Deliberately no case conversion beyond that. English sentence case keeps proper nouns and
    proper adjectives — "New Zealand sow thistle", "Spanish broom" — and telling those from
    common nouns needs a dictionary, not a rule. A name in a foraging catalogue is worth more
    correct than consistent, and the editor can restyle one in a second.
    """
    trimmed = name.strip()
    return trimmed[:1].upper() + trimmed[1:] if trimmed else ""


def choose_common_name(offered: str | None, fallback: str) -> str:
    """The first real name of the two, tidied. Empty when neither is one.

    The book prints "No common name" for a few species and iNaturalist has its own
    placeholders; neither is a name, and an entry cannot be listed without one. The book's
    own heading may still carry an image caption's position marker, which is no part of a
    name and would otherwise reach both the entry's title and its id.
    """
    for name in (offered, CAPTION_MARKER.sub("", fallback)):
        if name and name.strip().lower() not in NO_COMMON_NAME:
            return tidy_name(name)
    return ""


def words_of(text: str, minimum: int = MIN_MATCHED_WORD) -> set[str]:
    return set(re.findall(rf"[A-Za-z\u00c0-\u024f]{{{minimum},}}", text.lower()))


def book_heading(title: str, common: str, scientific: str) -> str | None:
    """The book's own heading for this species, or None when it cannot be trusted.

    A citation has to point at something a reader can find under the entry they are reading.
    OCR supplies plenty that cannot: a caption fragment ("(right)"), a heading whose first
    word was lost ("Cornered garlic"), a ligature broken across a space ("Symphytum offi
    cinale"), or — worst — the heading of the species *next* to this one on the page. Each of
    those would assert something false about the book, so the citation is better without one.
    """
    cleaned = CAPTION_MARKER.sub("", title).strip(" -\u2014")
    if len(cleaned) < MIN_HEADING_CHARS or not cleaned[:1].isalpha():
        return None
    if BROKEN_LIGATURE.search(cleaned) or CONNECTIVE.match(cleaned):
        return None
    # A heading in our own genus but naming a different species is the neighbouring entry's.
    # (Plenty of English names read like binomials — "Bermuda buttercup" — so the genus has
    # to match before this can say anything.)
    genus = scientific.split()[0].casefold()
    if (
        BINOMIAL.match(cleaned)
        and cleaned.split()[0].casefold() == genus
        and cleaned.casefold() != scientific.casefold()
    ):
        return None
    heading = cleaned[:1].upper() + cleaned[1:]
    # The heading has to be this species' name, not merely adjacent to it. Sharing a word is
    # not enough: "Red clover" shares "clover" with white clover, "Cornered garlic" shares
    # "garlic" with Naples garlic, and citing either would tell a reader to look under an
    # entry about a different plant. So every distinguishing word must line up both ways —
    # nothing in the heading that our names don't have, and nothing in our name the heading
    # drops. Headings that fail are not wrong, only unverifiable, and the citation simply
    # names the book.
    ours = words_of(common, MIN_DISTINGUISHING_WORD) | words_of(scientific, MIN_DISTINGUISHING_WORD)
    if words_of(heading, MIN_DISTINGUISHING_WORD) - ours or words_of(common) - words_of(heading):
        return None
    return heading


@dataclass(frozen=True)
class Rejected:
    scientific: str
    reason: str


def accepted_name(scientific: str, record_accepted: str | None) -> str:
    """NZOR's accepted name when the queried one is a synonym, else the queried one."""
    return record_accepted.strip() if record_accepted and record_accepted.strip() else scientific


def validate(
    candidate: dict[str, Any], seen: set[str]
) -> tuple[dict[str, Any] | None, Rejected | None]:
    scientific = str(candidate["scientific"]).strip()
    nzor = fetch_nzor(scientific)
    time.sleep(COURTESY_DELAY)
    if nzor is None:
        return None, Rejected(scientific, "NZOR does not know this name")
    if not nzor.origins:
        return None, Rejected(scientific, "NZOR has no New Zealand biostatus for it")

    name = accepted_name(scientific, nzor.accepted_name)
    if name.lower() in seen:
        return None, Rejected(scientific, f"duplicate of {name}")
    seen.add(name.lower())

    taxon = fetch_inat_taxon(name)
    time.sleep(COURTESY_DELAY)
    # `fetch_inat_taxon` is a fuzzy search, so a near miss would name this entry and link its
    # photo page to a different species — exactly what this script exists to prevent.
    if taxon and taxon.scientific_name.casefold() not in {name.casefold(), scientific.casefold()}:
        taxon = None
    common = choose_common_name(
        taxon.preferred_common_name if taxon else None, str(candidate.get("title") or "")
    )
    if not common:
        return None, Rejected(scientific, "no common name from iNaturalist or the book")

    return {
        "title": common,
        "bookTitle": book_heading(str(candidate.get("title") or ""), common, name),
        "scientific": name,
        # Neither register is a source for a te reo name or a harvest season: left for the
        # book and the editor rather than guessed here.
        "maori": "",
        "season": "",
        "page": int(candidate.get("page") or 0),
        "origin": nzor.catalogue_origin,
        "moreImagesURL": taxon.taxon_page if taxon else None,
    }, None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--limit", type=int, default=0, help="stop after this many candidates")
    args = parser.parse_args(argv)

    candidates: list[dict[str, Any]] = json.loads(args.candidates.read_text())
    if args.limit:
        candidates = candidates[: args.limit]

    seen: set[str] = set()
    kept: list[dict[str, Any]] = []
    rejected: list[Rejected] = []
    for index, candidate in enumerate(candidates, start=1):
        entry, reject = validate(candidate, seen)
        if entry:
            kept.append(entry)
        elif reject:
            rejected.append(reject)
        if index % 25 == 0:
            print(f"  {index}/{len(candidates)} checked, {len(kept)} kept", file=sys.stderr)

    args.out.write_text(json.dumps(kept, ensure_ascii=False, indent=2) + "\n")
    print(f"{len(kept)} confirmed, {len(rejected)} rejected → {args.out}")
    reasons: dict[str, int] = {}
    for reject in rejected:
        reasons[reject.reason.split(" of ")[0]] = reasons.get(reject.reason.split(" of ")[0], 0) + 1
    for reason, count in sorted(reasons.items(), key=lambda pair: -pair[1]):
        print(f"  {count:4} {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
