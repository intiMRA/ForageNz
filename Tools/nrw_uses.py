#!/usr/bin/env python3
"""Look up every catalogue species in Ngā Rauropi Whakaoranga (NRW) and list what it records.

NRW (Manaaki Whenua – Landcare Research, data CC BY 4.0) is the Māori plant-use database at
https://rauropiwhakaoranga.landcareresearch.co.nz/. Its name records split uses into fields
(food, fibre, dyes, domestic, pastime, fishingAndHunting, construction…), and its search takes
field queries such as `dyes:*` (see /search-syntax). This tool does two things:

1. **Entries** — for each catalogue entry whose sources do not yet cite NRW (or every entry with
   `--all`), search NRW for the scientific name, open the matching name record and keep its
   fields. An entry with a record is a lead to re-read: nothing here reaches a page by itself.
2. **Candidates** — every NRW name record with a fibre, dyes, domestic or pastime field, marked
   as in the catalogue or not, so species with uses for us that the catalogue lacks show up.

Pages are cached in `.nrw-cache/` (git-ignored) so a re-run costs nothing.

    python3 Tools/nrw_uses.py --out /tmp/nrw            # writes nrw.json and nrw.md there
    python3 Tools/nrw_uses.py --out /tmp/nrw --all      # also entries that already cite NRW
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import time
import urllib.parse
import subprocess
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parent.parent
CATALOGUE = REPO / "ForageNZ" / "Catalogue" / "species.json"
CACHE = REPO / ".nrw-cache"
BASE = "https://rauropiwhakaoranga.landcareresearch.co.nz"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15"

#: NRW fields that can hold a use in scope (owner 26/11/2026: fibre, dye, craft, cosmetics) or
#: context worth re-reading. Medicinal is listed only so a record's medicinal content is flagged
#: as out of scope, never used.
FIELDS = ["māorinames", "commonnames", "previousnames", "food", "fibre", "dyes", "domestic",
          "pastime", "fishingandhunting", "construction", "environment", "traditions", "notes",
          "toxins", "medicinal"]
USE_FIELDS = ["fibre", "dyes", "domestic", "pastime"]
#: Field queries that list the candidates (search-syntax field names are case-sensitive).
CANDIDATE_QUERIES = ["fibre:*", "dyes:*", "domestic:*", "pastime:*"]


def fetch(url: str) -> str:
    CACHE.mkdir(exist_ok=True)
    path = CACHE / (hashlib.sha1(url.encode()).hexdigest() + ".html")
    if path.exists():
        return path.read_text()
    # curl, not urllib: it reads the macOS keychain, which trusts this network's proxy
    # certificate; Python's bundled store does not (CERTIFICATE_VERIFY_FAILED, 27/11/2026).
    text = subprocess.run(["curl", "-sSL", "--retry", "3", "-m", "60", "-A", USER_AGENT, url],
                          check=True, capture_output=True, text=True).stdout
    path.write_text(text)
    time.sleep(0.5)
    return text


def search(query: str) -> list[tuple[str, str]]:
    """(record id, title) for every name record a search returns, in result order."""
    page = fetch(f"{BASE}/search?" + urllib.parse.urlencode({"query": query}))
    found, seen = [], set()
    for record_id, title in re.findall(r'<a href="/names/([0-9a-f-]{36})">([^<]+)</a>', page):
        if record_id not in seen:
            seen.add(record_id)
            found.append((record_id, html.unescape(title).strip()))
    return found


def text_of(fragment: str) -> str:
    fragment = re.sub(r"<(p|br|li)[^>]*>", "\n", fragment)
    fragment = html.unescape(re.sub(r"<[^>]+>", "", fragment))
    lines = [re.sub(r"\s+", " ", line).strip() for line in fragment.split("\n")]
    return "\n".join(line for line in lines if line)


def record(record_id: str) -> dict[str, Any]:
    page = fetch(f"{BASE}/names/{record_id}")
    heading = re.search(r"<h2>(.*?)</h2>", page, re.S)
    fields: dict[str, str] = {}
    for match in re.finditer(r'<div id="section-([^"]+)-content"[^>]*>(.*?)(?=<div id="section-[^"]+" data-label=|<footer|$)',
                             page, re.S):
        key = html.unescape(match.group(1)).lower()
        if key in FIELDS:
            body = text_of(match.group(2))
            if body:
                fields[key] = body
    return {"id": record_id, "url": f"{BASE}/names/{record_id}",
            "title": text_of(heading.group(1)) if heading else "", "fields": fields}


def binomial(name: str) -> str:
    """Genus and species epithet only, the way NRW titles start."""
    words = re.sub(r"[()]", "", name).split()
    return " ".join(words[:2]).lower()


def title_names(title: str) -> set[str]:
    """Binomials a record title names: 'Coriaria arborea. C. sarmentosa. Tutu.' → both."""
    names, genus = set(), None
    for first, epithet in re.findall(r"\b([A-Z][a-z]+|[A-Z]\.)\s+([a-z][a-z-]+)\b", title):
        if first.endswith("."):
            if genus:
                names.add(f"{genus} {epithet}".lower())
        else:
            genus = first
            names.add(f"{first} {epithet}".lower())
    return names


def rank(title: str, wanted: str) -> int:
    """0 for the species' own record, 1 for one naming it among others, 2 for a cultivar."""
    if "'" in title or "cultivar" in title.lower():
        return 2
    return 0 if title.lower().startswith(wanted + ".") else 1


def cites_nrw(entry: dict[str, Any]) -> bool:
    return any("rauropi" in line.lower() for line in entry.get("sources", []))


def names_of(entry: dict[str, Any]) -> list[str]:
    """The entry's binomial, then any '(syn. …)' names in its scientificName."""
    name = entry["scientificName"]
    found = [binomial(name.split("(")[0])]
    for synonym in re.findall(r"syn\.\s+([A-Z][a-z]+ [a-z-]+)", name):
        found.append(synonym.lower())
    return found


def shares_a_name(entry: dict[str, Any], title: str) -> bool:
    """True when the title carries the entry's common or Māori name ('Prumnopitys ferruginea.
    Miro.' for Pectinopitys ferruginea), so a renamed genus is not mistaken for a stranger with
    the same epithet ('Astelia solandri' for black beech, Fuscospora solandri)."""
    words = {w for w in re.split(r"[^a-zāēīōū]+", title.lower()) if len(w) > 3}
    names = f"{entry.get('commonName', '')} {entry.get('maoriName', '')}".lower()
    return any(w in words for w in re.split(r"[^a-zāēīōū]+", names) if len(w) > 3 and w not in {"tree", "plant"})


#: How a record was matched, best first. Everything but "exact" and "cited" needs a human look:
#: NRW files many plants under older names or a whole genus ('Tetragonia spp.').
MATCH_ORDER = ["cited", "exact", "synonym", "previous name", "genus record", "same epithet, other genus"]


def look_up(entry: dict[str, Any]) -> list[dict[str, Any]]:
    names = names_of(entry)
    main, genus, epithet = names[0], names[0].split()[0], names[0].split()[-1]
    hits: dict[str, tuple[int, str]] = {}

    def offer(record_id: str, how: str) -> None:
        rank_ = MATCH_ORDER.index(how)
        if record_id not in hits or rank_ < hits[record_id][0]:
            hits[record_id] = (rank_, how)

    for line in entry.get("sources", []):
        for record_id in re.findall(r"rauropiwhakaoranga\.landcareresearch\.co\.nz/names/([0-9a-f-]{36})", line):
            title = record(record_id)["title"]
            # A source line can cite another plant's record (a lookalike, a relative).
            if any(n in title_names(title) for n in names) or title.lower().startswith(f"{genus} spp"):
                offer(record_id, "cited")
    queries = [f'"{n}"' for n in names] + [genus, epithet]
    for query in queries:
        for record_id, title in search(query):
            named = title_names(title)
            if main in named:
                offer(record_id, "exact" if rank(title, main) == 0 else "synonym")
            elif any(n in named for n in names[1:]):
                offer(record_id, "synonym")
            elif title.lower().startswith(f"{genus} spp"):
                offer(record_id, "genus record")
            elif any(n.split()[-1] == epithet for n in named) and shares_a_name(entry, title):
                offer(record_id, "same epithet, other genus")
    for record_id, _ in search(f'previousNames:"{main}"'):
        offer(record_id, "previous name")
    found = []
    for record_id in sorted(hits, key=lambda record_id: hits[record_id][0]):
        item = record(record_id)
        item["matchedBy"] = hits[record_id][1]
        if item["matchedBy"] == "previous name" and main not in item["fields"].get("previousnames", "").lower():
            continue
        found.append(item)
    # Keep every record that names the species; fall back to the best looser match only.
    close = [item for item in found if item["matchedBy"] in ("cited", "exact", "synonym", "previous name")]
    return close or found[:1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--all", action="store_true", help="also look up entries that already cite NRW")
    args = parser.parse_args()
    species = json.loads(CATALOGUE.read_text())
    by_binomial = {binomial(e["scientificName"]): e["id"] for e in species}

    entries = []
    for entry in species:
        if cites_nrw(entry) and not args.all:
            continue
        found = look_up(entry)
        entries.append({"entry": entry["id"], "scientificName": entry["scientificName"],
                        "group": entry["group"], "draft": entry.get("draft", False),
                        "plannedUses": entry.get("plannedUses", []),
                        "usesWritten": [use["kind"] for use in entry.get("uses", [])],
                        "citesNRW": cites_nrw(entry), "records": found})

    # Records matched to an entry under an older name ('Macropiper excelsum') count as in it.
    matched: dict[str, set[str]] = {}
    for item in entries:
        for found in item["records"]:
            if found["matchedBy"] != "genus record":
                matched.setdefault(found["id"], set()).add(item["entry"])
    candidates: dict[str, dict[str, Any]] = {}
    for query in CANDIDATE_QUERIES:
        for record_id, title in search(query):
            if record_id not in candidates:
                found = record(record_id)
                names = sorted(title_names(found["title"] or title))
                found["inCatalogue"] = sorted({by_binomial[n] for n in names if n in by_binomial}
                                              | matched.get(record_id, set()))
                candidates[record_id] = found

    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "nrw.json").write_text(json.dumps({"entries": entries, "candidates": list(candidates.values())},
                                                  ensure_ascii=False, indent=1))
    lines = ["# NRW lookup", "", f"Retrieved {time.strftime('%d/%m/%Y')}.", "",
             "## Entries with an NRW record", ""]
    for item in entries:
        for found in item["records"]:
            uses = [f for f in USE_FIELDS if f in found["fields"]]
            lines.append(f"- `{item['entry']}` ({item['scientificName']}) → {found['title']} {found['url']}"
                         f" [{found['matchedBy']}] — fields: {', '.join(found['fields'])}"
                         f"{' — USES: ' + ', '.join(uses) if uses else ''}")
    missing = [item["entry"] for item in entries if not item["records"]]
    lines += ["", f"## Entries with no NRW record ({len(missing)})", "", ", ".join(missing), "",
              "## NRW records with fibre, dyes, domestic or pastime fields", ""]
    for found in sorted(candidates.values(), key=lambda c: c["title"]):
        uses = [f for f in USE_FIELDS if f in found["fields"]]
        where = ", ".join(f"`{i}`" for i in found["inCatalogue"]) or "NOT IN CATALOGUE"
        lines.append(f"- {found['title']} — {', '.join(uses)} — {where} — {found['url']}")
    (args.out / "nrw.md").write_text("\n".join(lines) + "\n")
    print(f"{len(entries)} entries looked up, {sum(1 for i in entries if i['records'])} with a record; "
          f"{len(candidates)} use records, {sum(1 for c in candidates.values() if not c['inCatalogue'])} not in the catalogue")


if __name__ == "__main__":
    main()
