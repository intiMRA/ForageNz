#!/usr/bin/env python3
"""List the symbiotic partners Global Biotic Interactions records for every catalogue species.

For each entry the script asks GloBI (https://www.globalbioticinteractions.org) for every
interaction it holds, keeps only the symbiotic kinds (root partners, hosts, parasites,
epiphytes, pathogens) and writes one HTML table to look through. A partner that
is itself a catalogue species is marked, and so is a pair the catalogue already links in
`associations`, so the table shows which partnerships could become new "Grows with" links.

The table is for finding a useful species by what it grows with ("look under oak for porcini"),
so it lists only useful entries (anything not marked do-not-eat, and do-not-eat entries with a
non-food use in docs/plans/useful-plants.md), and keeps only partners that help find one:
- for a fungus, the plants it grows under or on (GBIF kingdom Plantae), and useful catalogue species;
- for a plant or seaweed, useful catalogue species only. Their other GloBI partners are rusts,
  moulds, insects and pollinators, none of which leads anyone to the plant.
A pair of two plants is dropped when its only record is a disease (GloBI holds virus records
misfiled that way).

Partners are kept only when they are named to species and GBIF (https://www.gbif.org) has at
least one occurrence of that species in New Zealand (`--min-nz` raises the bar). Each partner
name is matched to a GBIF species strictly (no fuzzy guesses), and New Zealand presence comes
from one GBIF query counting occurrences per species for the whole country.

GloBI is a lead, not a source: its records are aggregated from many datasets of uneven
quality and none is limited to New Zealand. A link still needs a New Zealand record naming
the species (see docs/plans/species-associations.md).

Responses and GBIF name matches are cached in `.globi-cache/`, so a second run only fetches
what is missing.

The same leads are also written as data (`--leads`, docs/association-leads.json) for the
catalogue report, which splits the linking work into batches.

    .venv/bin/python Tools/globi_symbioses.py [--out docs/globi-symbioses.html] [--leads docs/association-leads.json] [--refresh] [--min-nz N]
"""

from __future__ import annotations

import argparse
import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from sources import CATALOGUE, COURTESY_DELAY, SourceError, get_json

REPO = Path(__file__).resolve().parent.parent
USEFUL_PLANTS = REPO / "docs" / "plans" / "useful-plants.md"
LEADS = REPO / "docs" / "association-leads.json"
API = "https://api.globalbioticinteractions.org/interaction"
WEB = "https://www.globalbioticinteractions.org/"
FIELDS = "source_taxon_name,interaction_type,target_taxon_name"
LIMIT = 4096
WORKERS = 4
GBIF_WORKERS = 8

Entry = dict[str, Any]

# GloBI interaction types that are a living partnership, with the plain words the table shows.
# Feeding, pollination, visiting, co-occurrence and the unspecified `interactsWith` are left
# out: none of them says one species depends on the other. So are `symbiontOf`, `mutualistOf`
# and `commensalistOf`: GloBI's records of them are mostly environmental DNA surveys
# (GlobalFungi) with no study or place, such as slippery jack 'symbiont of' heather, and they
# name no host to look under (owner, 23/11/2026).
SYMBIOTIC = {
    "ectomycorrhizalHostOf": "root partner (it is the host)",
    "hasEctomycorrhizalHost": "root partner (it is the fungus)",
    "arbuscularMycorrhizalHostOf": "arbuscular root partner (it is the host)",
    "hasArbuscularMycorrhizalHost": "arbuscular root partner (it is the fungus)",
    "hostOf": "host of",
    "hasHost": "lives on",
    "parasiteOf": "parasite of",
    "hasParasite": "has parasite",
    "endoparasiteOf": "endoparasite of",
    "hasEndoparasite": "has endoparasite",
    "ectoparasiteOf": "ectoparasite of",
    "hasEctoparasite": "has ectoparasite",
    "rootparasiteOf": "root parasite of",
    "hemiparasiteOf": "hemiparasite of",
    "pathogenOf": "pathogen of",
    "hasPathogen": "has pathogen",
    "epiphyteOf": "epiphyte on",
    "hasEpiphyte": "has epiphyte",
}


# Kinds read from the host's side: the species asked about is the tree or plant, the partner
# lives on it. A fungus partner of a fungus can be either way round, so these only matter for
# a fungus whose partner is a plant, where they would mean the plant lives on the fungus.
HOST_SIDE = {
    "ectomycorrhizalHostOf",
    "arbuscularMycorrhizalHostOf",
    "hostOf",
    "hasParasite",
    "hasEndoparasite",
    "hasEctoparasite",
    "hasPathogen",
    "hasEpiphyte",
}
DISEASE = {"pathogenOf", "hasPathogen"}
FUNGI = "fungi"
#: GBIF kingdoms a fungus can be looked for under or on.
FINDABLE_KINGDOMS = {"Plantae"}


@dataclass
class Partner:
    """One species a catalogue entry is recorded with, and every symbiotic way it is."""

    name: str
    #: GloBI interaction type → number of records.
    kinds: dict[str, int]
    partner_id: str | None
    linked: bool
    #: GBIF occurrences in New Zealand; `None` until checked, 0 when the name is not a species.
    nz_records: int | None = None
    #: GBIF species key, when the name matched one.
    gbif_key: int | None = None

    @property
    def records(self) -> int:
        return sum(self.kinds.values())


@dataclass
class SpeciesRow:
    """A catalogue entry and its partners."""

    entry: Entry
    #: The name GloBI was asked for, which the record links reuse.
    query: str
    partners: list[Partner]


HYBRID_MARKS = {"×", "x"}


def binomial(scientific_name: str) -> tuple[str, str, bool]:
    """Genus, epithet and whether it is a hybrid, from the first of several names.

    'agg.', subspecies and varieties are dropped, and the hybrid sign is taken off however it
    is written ("Mentha ×piperita", "Viola × wittrockiana", GloBI's "Mentha x piperita").
    """
    first = scientific_name.split("/")[0].strip()
    first = re.sub(r"\s+agg\.?$", "", first)
    words = first.split()
    hybrid = False
    kept = []
    for word in words:
        if word in HYBRID_MARKS:
            hybrid = True
            continue
        if word.startswith("×"):
            hybrid = True
            word = word[1:]
        kept.append(word)
    genus = kept[0] if kept else ""
    epithet = kept[1] if len(kept) > 1 else ""
    return genus, epithet, hybrid


def name_key(scientific_name: str) -> str:
    """'genus epithet', lower-cased and without any hybrid sign: how names are matched."""
    genus, epithet, _ = binomial(scientific_name)
    return f"{genus} {epithet}".strip().lower()


def query_names(scientific_name: str) -> list[str]:
    """The names to ask GloBI for. A hybrid is asked for as GloBI writes hybrids
    ("Mentha x piperita") and without the sign, because the common one varies:
    "Mentha x piperita" has records and "Mentha piperita" few, "Prunus domestica" the reverse.
    """
    genus, epithet, hybrid = binomial(scientific_name)
    plain = f"{genus} {epithet}".strip()
    return [f"{genus} x {epithet}", plain] if hybrid and epithet else [plain]


def catalogue_names(entries: list[Entry]) -> dict[str, str]:
    """Name key → entry id, for every name an entry carries."""
    names: dict[str, str] = {}
    for entry in entries:
        for name in entry.get("scientificName", "").split("/"):
            if name.strip():
                names[name_key(name)] = entry["id"]
    return names


def useful_ids(entries: list[Entry], uses_text: str) -> set[str]:
    """Entries worth finding: every one not marked do-not-eat, and a do-not-eat one with a
    non-food use (dye, fibre and so on) recorded by its id in useful-plants.md."""
    noted = set(re.findall(r"`([a-z0-9-]+)`", uses_text))
    return {entry["id"] for entry in entries if entry.get("caution") != "doNotEat" or entry["id"] in noted}


def findable(entry: Entry, partner: Partner, useful: set[str], groups: dict[str, str], kingdom: str | None) -> bool:
    """Whether a partner helps find this (useful) entry. See the module docstring for the rules."""
    if partner.partner_id:
        if partner.partner_id not in useful:
            return False
        both_plants = entry["group"] != FUNGI and groups[partner.partner_id] != FUNGI
        return not (both_plants and partner.kinds.keys() <= DISEASE)
    return (
        entry["group"] == FUNGI
        and kingdom in FINDABLE_KINGDOMS
        and bool(partner.kinds.keys() - HOST_SIDE)
    )


def symbiotic_rows(payload: dict[str, Any]) -> list[tuple[str, str]]:
    """(interaction type, partner name) for each symbiotic record in a GloBI response.

    GloBI answers a `sourceTaxon` query from the queried species' side in both directions, so
    the type already reads "this species <type> partner".
    """
    columns = payload.get("columns") or []
    try:
        kind_at = columns.index("interaction_type")
        partner_at = columns.index("target_taxon_name")
    except ValueError:
        return []
    rows = []
    for record in payload.get("data") or []:
        kind, partner = record[kind_at], record[partner_at]
        if kind in SYMBIOTIC and isinstance(partner, str) and partner.strip():
            rows.append((kind, partner.strip()))
    return rows


def partners_of(entry: Entry, payload: dict[str, Any], names: dict[str, str]) -> list[Partner]:
    """One `Partner` per species named in the symbiotic records, merged across spellings and
    subspecies (their name key), catalogue species first, then most-recorded first.

    A partner named only to genus or above ("Pinus", "Conifer") is dropped: a link needs a species.
    """
    by_key: dict[str, Partner] = {}
    spellings: dict[str, dict[str, int]] = {}
    linked = {link["entry"] for link in entry.get("associations") or []}
    for kind, raw in symbiotic_rows(payload):
        key = name_key(raw)
        genus, epithet, _ = binomial(raw)
        if not epithet or not genus[:1].isupper() or epithet.rstrip(".") in {"sp", "spp", "cf", "aff"}:
            continue
        partner_id = names.get(key)
        if partner_id == entry["id"]:
            continue
        partner = by_key.setdefault(key, Partner(raw, {}, partner_id, partner_id in linked))
        partner.kinds[kind] = partner.kinds.get(kind, 0) + 1
        counts = spellings.setdefault(key, {})
        counts[raw] = counts.get(raw, 0) + 1
    for key, partner in by_key.items():
        partner.name = max(spellings[key].items(), key=lambda item: item[1])[0]
    return sorted(by_key.values(), key=lambda p: (p.partner_id is None, -p.records, p.name))


def fetch(name: str, cache: Path, refresh: bool) -> dict[str, Any]:
    """Every GloBI interaction for one name, page by page, from the cache when it has them."""
    path = cache / f"{name.replace(' ', '_')}.json"
    if path.exists() and not refresh:
        return json.loads(path.read_text())
    columns: list[str] = []
    data: list[list[Any]] = []
    while True:
        page = get_json(
            API,
            {
                "sourceTaxon": name,
                "interactionType": "interactsWith",
                "limit": LIMIT,
                "offset": len(data),
                "fields": FIELDS,
            },
        )
        time.sleep(COURTESY_DELAY)
        columns = page.get("columns") or columns
        records = page.get("data") or []
        data.extend(records)
        if len(records) < LIMIT:
            break
    payload = {"columns": columns, "data": data}
    path.write_text(json.dumps(payload))
    return payload


def fetch_species(scientific_name: str, cache: Path, refresh: bool) -> tuple[str, dict[str, Any]]:
    """The query name with the most records, and its interactions."""
    fetched = [(name, fetch(name, cache, refresh)) for name in query_names(scientific_name)]
    return max(fetched, key=lambda item: len(item[1].get("data") or []))


GBIF = "https://api.gbif.org/v1"
SPECIES_RANKS = {"SPECIES", "SUBSPECIES", "VARIETY", "FORM"}


def nz_species_counts() -> dict[int, int]:
    """GBIF species key → occurrences recorded in New Zealand, for every species with any.

    One facet query: GBIF counts occurrences per species for the whole country.
    """
    payload = get_json(
        f"{GBIF}/occurrence/search",
        {"country": "NZ", "facet": "speciesKey", "facetLimit": 1_000_000, "limit": 0},
    )
    facets = payload.get("facets") or [{}]
    return {int(count["name"]): count["count"] for count in facets[0].get("counts", [])}


def gbif_species_key(name: str, cache: dict[str, int | None]) -> int | None:
    """The accepted GBIF species key for a name, or `None` when GBIF cannot match it to a
    species (no match, or only to a genus or above). Strict matching: no fuzzy guesses."""
    if name in cache:
        return cache[name]
    match = get_json(f"{GBIF}/species/match", {"name": name, "strict": "true"})
    key = match.get("speciesKey") if match.get("rank") in SPECIES_RANKS else None
    cache[name] = key
    return key


def gbif_kingdom(key: int, cache: dict[str, str | None]) -> str | None:
    """The GBIF kingdom of a species key ("Plantae", "Fungi", "Animalia" …), cached by key."""
    if str(key) in cache:
        return cache[str(key)]
    kingdom = get_json(f"{GBIF}/species/{key}", {}).get("kingdom")
    cache[str(key)] = kingdom
    return kingdom


def globi_link(species: str, partner: str) -> str:
    query = urllib.parse.urlencode(
        {"interactionType": "interactsWith", "sourceTaxon": species, "targetTaxon": partner}
    )
    return f"{WEB}?{query}"


BIOTA = "https://biotanz.landcareresearch.co.nz"
#: Biota answers "Not Found" to a request without a browser user agent.
BIOTA_AGENT = "Mozilla/5.0"
NZ = "New Zealand"
#: GloBI kinds that make a fungus a root partner: it needs a particular living tree, so each
#: of its hosts is worth a link however many it has (fly agaric under oak, beech and birch).
ROOT_PARTNER = {
    "ectomycorrhizalHostOf", "hasEctomycorrhizalHost", "arbuscularMycorrhizalHostOf",
    "hasArbuscularMycorrhizalHost",
}
#: A fungus with no root-partner record that GloBI records on more New Zealand plants than this
#: lives on whatever wood it finds, like turkey tail: a generalist, which gets no link (owner,
#: 16/11/2026: only what needs a specific other species). A few parasite records do not change that.
GENERALIST_HOSTS = 3


def get_page(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": BIOTA_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as error:
        raise SourceError(str(error), status=error.code) from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise SourceError(str(error)) from error


def cell_text(cell: str) -> str:
    """A table cell's visible text, without the pop-up of record links Biota puts in name cells."""
    cell = re.sub(r'(?s)<div id="link-view.*', "", cell)
    return html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", cell))).strip()


def biota_record_ids(name: str, page: str) -> list[str]:
    """Every Biota record named exactly this species, from a Biota search page. A plant can
    have more than one (duplicate name records), each with its own associations."""
    ids = []
    for record, text in re.findall(r'href="/scientific-names/([0-9a-f-]{36})">(.*?)</a>', page, flags=re.S):
        italics = re.findall(r"<i>(.*?)</i>", text, flags=re.S)
        # One italic name only: a second is a variety or subspecies of the species.
        if len(italics) == 1 and name_key(cell_text(italics[0])) == name_key(name) and record not in ids:
            ids.append(record)
    return ids


#: Biota's column headings → the keys a row is read into. Columns come and go between pages
#: (Country and Substrate are missing where no row has them).
BIOTA_COLUMNS = {
    "Association type": "type",
    "Associated organism (recorded name)": "recorded",
    "Associated organism (current name)": "current",
    "Country": "country",
    "Reference": "reference",
}


def biota_associations(page: str) -> list[dict[str, str]]:
    """Every row of a Biota associations table: type, the partner's recorded and current names,
    country ('' when the page has no Country column) and reference."""
    head = page[page.find("<thead"):page.find("</thead>")]
    columns = [cell_text(th) for th in re.findall(r"(?s)<th[^>]*>(.*?)</th>", head)]
    body = page[page.find("<tbody"):page.find("</tbody>")] if "<tbody" in page else ""
    rows = []
    for row in re.findall(r"(?s)<tr>(.*?)</tr>", body):
        cells = [cell_text(cell) for cell in re.findall(r"(?s)<td[^>]*>(.*?)</td>", row)]
        found = {key: "" for key in BIOTA_COLUMNS.values()}
        for heading, cell in zip(columns, cells):
            if heading in BIOTA_COLUMNS:
                found[BIOTA_COLUMNS[heading]] = cell
        rows.append(found)
    return rows


def new_zealand_partners(rows: list[dict[str, str]]) -> dict[str, dict[str, Any]]:
    """Name key → Biota's New Zealand evidence for each partner named to species.

    A row counts when its country is New Zealand (a PDD or other collection record) or when it
    has no country but cites a reference: Biota's literature rows (Gadgil's Fungi on Trees and
    Shrubs in New Zealand, NZ ecological papers) leave the country blank. Genus-only names never
    count, under either the recorded or the current name.
    """
    found: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not (row["country"] == NZ or (not row["country"] and row["reference"])):
            continue
        keys = {
            name_key(name) for name in (row["recorded"], row["current"])
            if len(name.split()) >= 2 and re.match(r"[a-z×]", name.split()[1])
        }
        for key in keys:
            item = found.setdefault(key, {"types": set(), "records": 0})
            item["types"].add(row["type"])
            item["records"] += 1
    return found


def fetch_biota(name: str, cache: Path, refresh: bool) -> list[dict[str, str]]:
    """Biota's association rows for one species, from the cache when it has them; [] when
    Biota has no record by that name."""
    path = cache / "biota" / f"{name.replace(' ', '_')}.json"
    if path.exists() and not refresh:
        return json.loads(path.read_text())
    search = get_page(f"{BIOTA}/search?{urllib.parse.urlencode({'query': name})}")
    rows = []
    for record in biota_record_ids(name, search):
        rows += biota_associations(get_page(f"{BIOTA}/scientific-names/{record}/associations"))
        time.sleep(COURTESY_DELAY)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows))
    return rows


def is_generalist(row: SpeciesRow) -> bool:
    if row.entry.get("group") != FUNGI:
        return False
    if any(kind in ROOT_PARTNER for partner in row.partners for kind in partner.kinds):
        return False
    return len(row.partners) > GENERALIST_HOSTS


def leads(rows: list[SpeciesRow], biota: dict[str, dict[str, dict[str, Any]]] | None = None) -> dict[str, Any]:
    """The table as data for the catalogue report's "Link next" section.

    GloBI is the source of the leads (owner, 23/11/2026: a specialised database; Biota may simply
    not have caught up). Every partnership a row keeps is a lead, except a generalist fungus's
    (`is_generalist`), which keeps none either side. Each lead carries GloBI's words and record
    count, each side's GBIF New Zealand occurrence count (`nz`) to rank the common ones first, and
    `biota`: how many Biota of New Zealand records name the pair (from `new_zealand_partners`,
    either side), a head start for the research each lead still needs, never a filter.

    `pairs`: two catalogue species not yet linked, once whichever side recorded them.
    `hosts`: for each fungus, the New Zealand plants outside the catalogue it is recorded with
    (a link to one of them needs an entry first), most New Zealand occurrences first.
    """
    biota = biota or {}
    pairs: dict[tuple[str, str], dict[str, Any]] = {}
    hosts: dict[str, list[dict[str, Any]]] = {}
    generalists = {row.entry["id"] for row in rows if is_generalist(row)}
    for row in rows:
        own = row.entry["id"]
        if own in generalists:
            continue
        for partner in row.partners:
            if partner.partner_id in generalists:
                continue
            words = sorted({SYMBIOTIC[kind] for kind in partner.kinds})
            evidence = biota.get(own, {}).get(name_key(partner.name)) or biota.get(partner.partner_id or "", {}).get(
                name_key(row.entry.get("scientificName", ""))
            )
            in_biota = evidence["records"] if evidence else 0
            if partner.partner_id:
                if partner.linked:
                    continue
                a, b = sorted([own, partner.partner_id])
                pair = pairs.setdefault((a, b), {"a": a, "b": b, "kinds": {}, "records": {}, "nz": {}, "biota": 0})
                pair["kinds"][own] = words
                pair["records"][own] = partner.records
                pair["nz"][partner.partner_id] = partner.nz_records or 0
                pair["biota"] = max(pair["biota"], in_biota)
            else:
                hosts.setdefault(own, []).append(
                    {"name": partner.name, "kinds": words, "nz": partner.nz_records or 0, "records": partner.records, "biota": in_biota}
                )
    return {
        "pairs": [pairs[key] for key in sorted(pairs)],
        "hosts": {
            own: sorted(found, key=lambda h: (-h["nz"], h["name"])) for own, found in sorted(hosts.items())
        },
    }


def render(
    rows: list[SpeciesRow],
    names_by_id: dict[str, str],
    failed: list[str],
    no_records: list[str],
    species_count: int,
    min_nz: int,
) -> str:
    """One table row per catalogue species, its partners listed as "partner: how" chips."""
    esc = html.escape
    body = []
    for row in rows:
        entry = row.entry
        chips = []
        for partner in row.partners:
            label = names_by_id[partner.partner_id] if partner.partner_id else partner.name
            how = ", ".join(SYMBIOTIC[kind] for kind in sorted(partner.kinds, key=lambda k: -partner.kinds[k]))
            mark = ' <span class="ok">✓ linked</span>' if partner.linked else ""
            name_html = f"<b>{esc(label)}</b>" if partner.partner_id else f"<i>{esc(label)}</i>"
            title = (
                f"{partner.name} · {partner.records} GloBI record(s) · "
                f"{partner.nz_records} GBIF occurrence(s) in New Zealand"
            )
            chips.append(
                f'<li data-kinds="{esc(" ".join(partner.kinds))}" '
                f'data-catalogue="{"yes" if partner.partner_id else "no"}" '
                f'data-linked="{"yes" if partner.linked else "no"}">'
                f'<a href="{esc(globi_link(row.query, partner.name))}" title="{esc(title)}">{name_html}</a>: '
                f"{esc(how)}{mark}</li>"
            )
        body.append(
            f'<tr><td><b>{esc(entry["commonName"])}</b><br><i>{esc(entry["scientificName"])}</i>'
            f'<br><span class="dim">{esc(entry["id"])} · {esc(entry["group"])}</span></td>'
            f'<td><ul class="partners">{"".join(chips)}</ul></td></tr>'
        )
    kinds = "".join(
        f'<option value="{esc(kind)}">{esc(label)}</option>' for kind, label in SYMBIOTIC.items()
    )
    failures = (
        f'<p class="warn">Not reached for {len(failed)}: {esc(", ".join(failed))}. Re-run to retry them.</p>'
        if failed
        else ""
    )
    empty = (
        f'<p class="dim">No GloBI records at all for {len(no_records)} species (it may know them '
        f'under another name): {esc(", ".join(sorted(no_records)))}.</p>'
        if no_records
        else ""
    )
    pairs = sum(len(row.partners) for row in rows)
    return f"""<!doctype html>
<meta charset="utf-8">
<title>GloBI symbioses</title>
<style>
body {{ font: 14px -apple-system, system-ui, sans-serif; margin: 16px; color: #222; }}
table {{ border-collapse: collapse; width: 100%; }}
th, td {{ border-bottom: 1px solid #ddd; padding: 6px 8px; text-align: left; vertical-align: top; }}
td:first-child {{ width: 16em; }}
th {{ position: sticky; top: 0; background: #f6f6f6; }}
ul.partners {{ list-style: none; margin: 0; padding: 0; columns: 3 20em; column-gap: 24px; }}
ul.partners li {{ break-inside: avoid; padding: 1px 0; }}
a {{ color: inherit; text-decoration: none; }}
a:hover {{ text-decoration: underline; }}
.dim {{ color: #888; font-size: 12px; }}
.ok {{ color: #2a7a2a; font-size: 12px; }}
.warn {{ color: #b00020; }}
.controls {{ display: flex; flex-wrap: wrap; gap: 12px; margin: 12px 0; align-items: center; }}
</style>
<h1>GloBI symbioses</h1>
<p>What to look under or on to find a useful catalogue species: symbiotic partners recorded in
Global Biotic Interactions, kept when they help find one (for a fungus, the plants it grows under
or on; for a plant or seaweed, the useful catalogue species that grow with it). Of the
{species_count} catalogue species, only useful ones are listed (not do-not-eat, or with a
non-food use), and only partners named to species that GBIF has at least {min_nz} occurrence(s)
of in New Zealand: {pairs} partners across {len(rows)} species. <b>Bold</b> partners are catalogue
species. Each partner links to its records on GloBI; hover for counts. GloBI is worldwide and
aggregated, and a GBIF occurrence can be a garden plant or a border interception, so a pair is a
lead to check, not a New Zealand record of the partnership.</p>
{failures}
{empty}
<div class="controls">
<input id="q" type="search" placeholder="Filter by name" size="30">
<select id="kind"><option value="">Every kind</option>{kinds}</select>
<label><input id="catalogue" type="checkbox"> Only catalogue partners</label>
<label><input id="unlinked" type="checkbox"> Hide partners already linked</label>
<span id="shown" class="dim"></span>
</div>
<table>
<thead><tr><th>Species</th><th>Partners</th></tr></thead>
<tbody>
{"".join(body)}
</tbody>
</table>
<script>
const rows = [...document.querySelectorAll("tbody tr")];
const q = document.getElementById("q"), kind = document.getElementById("kind");
const catalogue = document.getElementById("catalogue"), unlinked = document.getElementById("unlinked");
function apply() {{
  const text = q.value.trim().toLowerCase();
  let shownRows = 0, shownPartners = 0;
  for (const row of rows) {{
    const speciesMatches = row.cells[0].textContent.toLowerCase().includes(text);
    let visible = 0;
    for (const chip of row.querySelectorAll("li")) {{
      const show = (!kind.value || chip.dataset.kinds.split(" ").includes(kind.value))
        && (!catalogue.checked || chip.dataset.catalogue === "yes")
        && (!unlinked.checked || chip.dataset.linked === "no")
        && (!text || speciesMatches || chip.textContent.toLowerCase().includes(text));
      chip.hidden = !show;
      if (show) visible++;
    }}
    row.hidden = visible === 0;
    if (visible) {{ shownRows++; shownPartners += visible; }}
  }}
  document.getElementById("shown").textContent = shownRows + " species · " + shownPartners + " partners shown";
}}
for (const control of [q, kind, catalogue, unlinked]) control.addEventListener("input", apply);
apply();
</script>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--out", type=Path, default=REPO / "docs" / "globi-symbioses.html")
    parser.add_argument("--leads", type=Path, default=LEADS, help="the same leads as JSON, for the catalogue report")
    parser.add_argument("--cache", type=Path, default=REPO / ".globi-cache")
    parser.add_argument("--refresh", action="store_true", help="ignore the cache and fetch again")
    parser.add_argument(
        "--min-nz", type=int, default=1, help="GBIF New Zealand occurrences a partner needs (default 1)"
    )
    args = parser.parse_args()

    entries: list[Entry] = json.loads(CATALOGUE.read_text())
    names = catalogue_names(entries)
    useful = useful_ids(entries, USEFUL_PLANTS.read_text())
    groups = {entry["id"]: entry["group"] for entry in entries}
    names_by_id = {entry["id"]: entry["commonName"] for entry in entries}
    args.cache.mkdir(parents=True, exist_ok=True)

    def one(entry: Entry) -> tuple[Entry, tuple[str, dict[str, Any]] | None]:
        try:
            return entry, fetch_species(entry["scientificName"], args.cache, args.refresh)
        except SourceError:
            return entry, None

    rows: list[SpeciesRow] = []
    failed: list[str] = []
    no_records: list[str] = []
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        for entry, fetched in pool.map(one, entries):
            if fetched is None:
                failed.append(entry["id"])
                continue
            query, payload = fetched
            if not payload["data"]:
                no_records.append(entry["id"])
            if entry["id"] in useful:
                rows.append(SpeciesRow(entry, query, partners_of(entry, payload, names)))

    # New Zealand presence: every species GBIF has a New Zealand occurrence of, in one query,
    # then each partner name matched to its GBIF species (cached, since there are tens of thousands).
    nz_counts = nz_species_counts()
    match_cache_path = args.cache / "gbif-species-keys.json"
    match_cache: dict[str, int | None] = (
        json.loads(match_cache_path.read_text()) if match_cache_path.exists() and not args.refresh else {}
    )
    unmatched = sorted({p.name for row in rows for p in row.partners} - match_cache.keys())

    def match(name: str) -> None:
        try:
            gbif_species_key(name, match_cache)
        except SourceError:
            pass  # left out of the cache, so the next run asks again

    with ThreadPoolExecutor(max_workers=GBIF_WORKERS) as pool:
        for done, _ in enumerate(pool.map(match, unmatched), start=1):
            if done % 2000 == 0:
                match_cache_path.write_text(json.dumps(match_cache))
                print(f"  matched {done}/{len(unmatched)} partner names in GBIF")
    match_cache_path.write_text(json.dumps(match_cache))

    unchecked = 0
    for row in rows:
        for partner in row.partners:
            if partner.name not in match_cache:
                unchecked += 1
            key = match_cache.get(partner.name)
            partner.gbif_key = key
            partner.nz_records = nz_counts.get(key, 0) if key else 0
        row.partners = [p for p in row.partners if (p.nz_records or 0) >= args.min_nz]

    # Kingdoms, only where they decide anything: a fungus's partners outside the catalogue.
    kingdom_cache_path = args.cache / "gbif-kingdoms.json"
    kingdom_cache: dict[str, str | None] = (
        json.loads(kingdom_cache_path.read_text()) if kingdom_cache_path.exists() and not args.refresh else {}
    )
    wanted = sorted({
        p.gbif_key for row in rows if row.entry["group"] == FUNGI
        for p in row.partners if not p.partner_id and p.gbif_key and str(p.gbif_key) not in kingdom_cache
    })

    def classify(key: int) -> None:
        try:
            gbif_kingdom(key, kingdom_cache)
        except SourceError:
            pass  # left out of the cache, so the next run asks again

    with ThreadPoolExecutor(max_workers=GBIF_WORKERS) as pool:
        list(pool.map(classify, wanted))
    kingdom_cache_path.write_text(json.dumps(kingdom_cache))

    for row in rows:
        for partner in row.partners:
            if not partner.partner_id and row.entry["group"] == FUNGI and str(partner.gbif_key) not in kingdom_cache:
                unchecked += 1
        row.partners = [
            p for p in row.partners
            if findable(row.entry, p, useful, groups, kingdom_cache.get(str(p.gbif_key)))
        ]
    shown = [row for row in rows if row.partners]

    args.out.write_text(render(shown, names_by_id, failed, no_records, len(entries), args.min_nz))
    # Biota of New Zealand, for every species a lead could name (the rows' own entries and their
    # catalogue partners), to show which leads it already records. A failed fetch leaves that
    # species out of the cache, so a re-run asks again.
    sci_by_id = {entry["id"]: entry["scientificName"] for entry in entries}
    wanted_ids = sorted({row.entry["id"] for row in shown} | {p.partner_id for row in shown for p in row.partners if p.partner_id})
    biota: dict[str, dict[str, dict[str, Any]]] = {}
    biota_failed: list[str] = []

    def read_biota(entry_id: str) -> None:
        try:
            biota[entry_id] = new_zealand_partners(fetch_biota(query_names(sci_by_id[entry_id])[-1], args.cache, args.refresh))
        except SourceError:
            biota_failed.append(entry_id)

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        list(pool.map(read_biota, wanted_ids))
    found = leads(shown, biota)
    args.leads.write_text(json.dumps(found, indent=1, ensure_ascii=False) + "\n")
    partners = sum(len(row.partners) for row in shown)
    in_catalogue = sum(1 for row in shown for p in row.partners if p.partner_id)
    unlinked = sum(1 for row in shown for p in row.partners if p.partner_id and not p.linked)
    print(
        f"{len(entries)} species searched ({len(useful)} useful) · {len(shown)} with partners that help find them · {partners} partners "
        f"({in_catalogue} catalogue species, {unlinked} not linked) · {len(no_records)} with no GloBI "
        f"records · {len(failed)} failed · {unchecked} partner names GBIF could not be asked about · "
        f"{len(found['pairs'])} lead pairs and {sum(len(h) for h in found['hosts'].values())} lead hosts "
        f"({len(biota_failed)} Biota fetches failed) "
        f"→ {args.out}"
    )


if __name__ == "__main__":
    main()
