"""Fill empty description fields from openly licensed, human-written sources — verbatim.

Nothing here composes text. A species' `identification`, `habitat` and `summary` are
copied from the matching section of a licensed source. Each prose field is an object
`{"text": …, "sources": […]}`; the short attribution goes into that field's `sources` and
the full citation into the entry's `sources`. Fields that
already have content are never touched, and drafts are the default scope.

Sources, in order of preference:
  - Wikipedia (CC BY-SA 4.0) — the article's description-like and habitat-like sections.
  - Flora of New Zealand Online, Manaaki Whenua \u2013 Landcare Research (CC BY 3.0 NZ) — the
    factsheet's Description, when Wikipedia has no description section.

Safety fields (edible parts, preparation, warnings, lookalikes) are out of scope on
purpose: neither source is a foraging text.

    python Tools/fetch_descriptions.py            # drafts only
    python Tools/fetch_descriptions.py --all      # also fill blanks on finished entries
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import date
from http import HTTPStatus
from pathlib import Path
from typing import Any

from sources import (
    CATALOGUE,
    COURTESY_DELAY,
    REQUEST_TIMEOUT,
    SSL_CONTEXT,
    USER_AGENT,
    SourceError,
    get_json,
)

WIKIPEDIA_API = "https://en.wikipedia.org/w/api.php"
WIKIPEDIA_PAGE = "https://en.wikipedia.org/wiki/"
NZFLORA_FACTSHEET = "https://www.nzflora.info/factsheet/Taxon/{name}.html"
#: Wikipedia throttles harder than the biodiversity APIs.
WIKIPEDIA_DELAY = 1.5
NZFLORA_PUBLISHER = "Flora of New Zealand Online, Manaaki Whenua \u2013 Landcare Research"

DESCRIPTION_HEADINGS = re.compile(
    r"^(description|botany|morphology|characteristics|appearance|identification)\b", re.I
)
HABITAT_HEADINGS = re.compile(r"^(distribution|habitat|ecology|range)\b", re.I)
SKIP_HEADINGS = re.compile(
    r"^(references|external links|see also|gallery|notes|further reading)\b", re.I
)


@dataclass(frozen=True)
class Passage:
    text: str
    attribution: str
    citation: str


@dataclass(frozen=True)
class Fetched:
    identification: Passage | None = None
    habitat: Passage | None = None
    summary: Passage | None = None


def split_sections(extract: str) -> list[tuple[str, str]]:
    """Wikipedia's plaintext extract into (heading, body); the lead has heading ''.

    Sub-headings (=== ... ===) stay inside their parent's body as plain lines, which keeps
    a "Description" section whole when it is split into "Leaves" and "Flowers".
    """
    sections: list[tuple[str, str]] = []
    heading = ""
    body: list[str] = []
    for line in extract.splitlines():
        match = re.fullmatch(r"\s*==\s*([^=].*?)\s*==\s*", line)
        if match:
            sections.append((heading, "\n".join(body).strip()))
            heading, body = match.group(1), []
        else:
            body.append(re.sub(r"^\s*=+\s*(.*?)\s*=+\s*$", r"\1", line))
    sections.append((heading, "\n".join(body).strip()))
    return [(h, b) for h, b in sections if b and not SKIP_HEADINGS.match(h)]


def without_table_footers(body: str) -> str:
    """Wikipedia's plaintext extract keeps table footers like "Source: USDA" as loose lines."""
    return "\n".join(line for line in body.splitlines() if not line.startswith("Source:")).strip()


def first_sentence(text: str) -> str:
    """The lead's first sentence, copied whole.

    A full stop inside a parenthesis ("(syn. …)") or after an abbreviation is not the end of
    a sentence; cutting there would publish a fragment and would credit the licensed source
    for something it did not write.
    """
    flat = text.replace("\n", " ").strip()
    for match in re.finditer(r"[.!?](\s|$)", flat):
        candidate = flat[: match.end()].strip()
        if candidate.count("(") != candidate.count(")"):
            continue
        rest = flat[match.end() :].lstrip()
        if rest[:1].islower():
            continue
        return candidate
    return flat


def pick_wikipedia(title: str, extract: str, retrieved: date) -> Fetched:
    attribution = f"Wikipedia, '{title}' (CC BY-SA 4.0)"
    url = WIKIPEDIA_PAGE + urllib.parse.quote(title.replace(" ", "_"))
    citation = (
        f"Wikipedia contributors. '{title}', Wikipedia, The Free Encyclopedia. CC BY-SA 4.0. "
        f"Retrieved {retrieved:%d/%m/%Y}. {url}"
    )
    sections = [(h, without_table_footers(b)) for h, b in split_sections(extract)]
    description = next(
        (body for heading, body in sections if DESCRIPTION_HEADINGS.match(heading)), None
    )
    habitat = next((body for heading, body in sections if HABITAT_HEADINGS.match(heading)), None)
    lead = next((body for heading, body in sections if heading == ""), None)
    return Fetched(
        identification=Passage(description, attribution, citation) if description else None,
        habitat=Passage(habitat, attribution, citation) if habitat else None,
        summary=Passage(first_sentence(lead), attribution, citation) if lead else None,
    )


#: Wikipedia answers a burst with 429; each retry waits this many seconds, then the next.
RETRY_WAITS = (5.0, 20.0, 60.0)


def get_json_patiently(url: str, params: dict[str, object]) -> dict[str, Any]:
    """`get_json`, backing off on 429 instead of giving up on the species."""
    for wait in RETRY_WAITS:
        try:
            return get_json(url, params)
        except SourceError as error:
            if error.status != HTTPStatus.TOO_MANY_REQUESTS:
                raise
            time.sleep(wait)
    return get_json(url, params)


def wikipedia_extract(scientific_name: str) -> tuple[str, str] | None:
    """(resolved title, plaintext extract) for the article on this name, following redirects."""
    payload = get_json_patiently(
        WIKIPEDIA_API,
        {
            "action": "query",
            "prop": "extracts",
            "explaintext": 1,
            "redirects": 1,
            "titles": scientific_name,
            "format": "json",
            "formatversion": 2,
        },
    )
    pages: list[dict[str, Any]] = payload.get("query", {}).get("pages", [])
    if not pages or pages[0].get("missing") or not pages[0].get("extract"):
        return None
    title = str(pages[0]["title"])
    # A redirect to a differently-named taxon (a synonym, a family) would describe the wrong thing.
    genus = scientific_name.split()[0].lower()
    if genus not in title.lower() and genus not in str(pages[0]["extract"][:400]).lower():
        return None
    return title, str(pages[0]["extract"])


def strip_html(fragment: str) -> str:
    text = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", fragment, flags=re.S)
    text = re.sub(r"</p>|<br\s*/?>", "\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\n{3,}", "\n\n", html.unescape(text)).strip()


def nzflora_description(scientific_name: str, retrieved: date) -> Passage | None:
    name = "-".join(scientific_name.split()[:2])
    url = NZFLORA_FACTSHEET.format(name=name)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(
            request, timeout=REQUEST_TIMEOUT, context=SSL_CONTEXT
        ) as response:
            page = response.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, TimeoutError) as error:
        print(f"    nzflora failed: {error}", file=sys.stderr)
        return None
    match = re.search(r'id="description-content".*?<div class="section">(.*?)</div>', page, re.S)
    if not match:
        return None
    text = strip_html(match.group(1))
    if not text:
        return None
    return Passage(
        text=text,
        attribution=f"{NZFLORA_PUBLISHER} (CC BY 3.0 NZ)",
        citation=(
            f"{NZFLORA_PUBLISHER}. '{scientific_name}' factsheet. CC BY 3.0 NZ. "
            f"Retrieved {retrieved:%d/%m/%Y}. {url}"
        ),
    )


def fetch(scientific_name: str, retrieved: date) -> Fetched:
    fetched = Fetched()
    try:
        found = wikipedia_extract(scientific_name)
    except SourceError as error:
        print(f"    Wikipedia failed: {error}", file=sys.stderr)
        found = None
    if found:
        fetched = pick_wikipedia(found[0], found[1], retrieved)
    time.sleep(WIKIPEDIA_DELAY)
    if fetched.identification is None:
        flora = nzflora_description(scientific_name, retrieved)
        if flora:
            fetched = Fetched(
                identification=flora, habitat=fetched.habitat, summary=fetched.summary
            )
        time.sleep(COURTESY_DELAY)
    return fetched


def is_blank(field: Any) -> bool:
    """A prose field is `{"text", "sources"}`; blank means no text yet."""
    return not str((field or {}).get("text") or "").strip()


def fill(entry: dict[str, Any], fetched: Fetched) -> list[str]:
    """Fill blanks only. Returns the fields written.

    A written field becomes `{"text": passage, "sources": [attribution]}`, and the citation
    added to the entry's `sources` names the fields it supplied.
    """
    written: list[str] = []
    by_citation: dict[str, list[str]] = {}
    for field, passage in (
        ("identification", fetched.identification),
        ("habitat", fetched.habitat),
        ("summary", fetched.summary),
    ):
        if passage is None or not is_blank(entry.get(field)):
            continue
        entry[field] = {"text": passage.text.strip(), "sources": [passage.attribution]}
        by_citation.setdefault(passage.citation, []).append(field)
        written.append(field)
    for citation, fields in by_citation.items():
        line = f"{describe_fields(fields)} text: {citation}"
        if line not in entry["sources"]:
            entry["sources"].append(line)
    return written


def describe_fields(fields: list[str]) -> str:
    names = [fields[0].capitalize(), *fields[1:]]
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " and " + names[-1]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    parser.add_argument(
        "--all", action="store_true", help="fill blanks on finished entries too, not only drafts"
    )
    parser.add_argument("--only", default="", help="comma-separated ids to limit the run")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    catalogue: list[dict[str, Any]] = json.loads(args.catalogue.read_text())
    only = {i for i in args.only.split(",") if i}
    today = date.today()
    filled: dict[str, list[str]] = {}
    nothing: list[str] = []
    for entry in catalogue:
        if only and entry["id"] not in only:
            continue
        if not args.all and not entry.get("draft"):
            continue
        if not any(is_blank(entry.get(f)) for f in ("identification", "habitat", "summary")):
            continue
        written = fill(entry, fetch(entry["scientificName"], today))
        if written:
            filled[entry["id"]] = written
        else:
            nothing.append(entry["id"])

    counts = {
        field: sum(field in written for written in filled.values())
        for field in ("identification", "habitat", "summary")
    }
    print(f"filled {len(filled)} entries; per field: {counts}")
    print(f"nothing found for {len(nothing)}: {', '.join(nothing) or '-'}")
    if not args.dry_run:
        args.catalogue.write_text(json.dumps(catalogue, ensure_ascii=False, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
