#!/usr/bin/env python3
"""Write the one HTML report on the catalogue: every entry, grouped, with what it still owes.

Entries are filed by their app group (greens, herbs, fruit, fungi, seaweed, nuts), then by
species group inside it — the bamboos, the passionfruit, the milkcaps. A species group is a
connected component over two kinds of edge:

  * same genus — the first word of ``scientificName``;
  * a lookalike card between two entries that are both in the catalogue.

Those are the groups where one research session fills several entries at once. The report
opens with every draft batched by plant family (``BATCHES``) — the ones to pick up next, most
drafts first — and inside each app group the groups with drafts come before the finished
ones. Entries joined to nothing are listed last in their app group.

Per entry the report shows its state, caution, photos, months, the prose fields still empty,
its lookalike cards (and whether each opens a draft), its habitat tags with the words in its
own habitat prose that support them, and every ``OWED`` line in its sources — the text only
a person may write.

    python3 Tools/catalogue_report.py [--out docs/catalogue.html]
"""

from __future__ import annotations

import argparse
import collections
import html
import json
import pathlib
import re
from typing import Any

from classify_habitats import evidence

REPO = pathlib.Path(__file__).resolve().parent.parent
SPECIES = REPO / "ForageNZ" / "Catalogue" / "species.json"

Entry = dict[str, Any]

# App order and labels, from `ForageGroup` (ForageNZ/Catalogue/Model/ForageGroup.swift).
GROUPS = [
    ("greens", "Greens & leaves"),
    ("herbs", "Herbs & flavour"),
    ("fruit", "Fruit & berries"),
    ("fungi", "Fungi"),
    ("seaweed", "Seaweed"),
    ("nuts", "Nuts & seeds"),
]

# Fields a filled-in entry is expected to carry. `photos` and `months` are checked
# separately because they are lists, not {text, sources} blocks.
PROSE_FIELDS = ["summary", "identification", "habitat", "edibleParts", "preparation"]

# A `sources` line marking text only a person may write: the owner's warning, harvest
# ethics, a season no source gives. Upper case is the convention.
OWED = re.compile(r"\bOWED\b")

MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# Species-group names where the members' common names do not share a head word. Keyed by
# any one member's id, so a name survives the group gaining or losing other members.
NAMES = {
    "hemlock": "Carrot family and watercress",
    "bermuda-buttercup": "Wood sorrels and clovers",
    "liberty-cap": "Psilocybes and pouch fungi",
    "black-cherry": "Plums and cherries",
    "karamu": "Coprosmas",
    "dandelion": "Dandelion and its lookalikes",
    "blackberry": "Brambles",
    "death-cap": "Field mushroom and death cap",
    "onion-weed": "Garlics, onion weed and snowflake",
    "banana-passionfruit": "Passionfruit",
    "ongaonga": "Nettles",
    "scented-geraniums": "Scented geraniums",
    "puha": "Sow thistles",
    "apple-mint": "Mints",
    "black-nightshade": "Nightshades and fat hen",
    "bracken": "Ferns",
    "chickweed": "Chickweed and its lookalikes",
    "clustered-dock": "Docks and sheep sorrel",
    "european-barberry": "Barberries",
    "herb-robert": "Cranesbills",
    "slippery-jack": "Slippery jacks",
    "porcini": "Porcini and bitter bolete",
    "blackcurrant": "Currants",
    "bog-yellow-cress": "Yellow cresses",
    "chalciporus-aurantiacus": "Peppery boletes",
    "chilean-sea-fig": "Sea fig and ice plant",
    "cow-parsley": "Cow parsley and chervil",
    "garden-orache": "Saltbush and orache",
    "hedge-mustard": "Rocket and hedge mustard",
    "tutu": "Elder and tutu",
    "german-chamomile": "Chamomile and pineappleweed",
    "harakeke": "Flax",
    "hawthorn": "Hawthorn and medlar",
    "lowland-horopito": "Horopito",
    "kiokio": "Kiokio and rereti",
    "rosehip": "Roses",
    "sea-grapes": "Sea grapes and sea rimu",
    "sweet-violet": "Violets",
    "cabbage-tree": "Cabbage trees",
    "native-ice-plant": "Ice plants",
    "sea-lettuce": "Sea lettuces",
    "bluefoot-bolete": "Bluefoot and riverine boletes",
    "sticky-mouse-ear-chickweed": "Mouse-ear chickweeds",
}

# The "Pick up next" table batches species groups (and lone drafts) by plant family, so one
# session covers several groups that share a Flora treatment, keys and lookalikes. Small
# families join their nearest relatives (fuchsias with the myrtles, hops with the roses) or a
# coarser lineage where families are tiny: fungi by order, conifers, ferns, seaweeds by colour.
# Keyed by genus, the first word of `scientificName`; a genus missing here gets its own batch.
BATCHES = {
    "Daisy family (Asteraceae)": "Achillea Anthemis Arctium Bellis Calendula Chamaemelum Crepis "
    "Erigeron Hypochaeris Lactuca Lapsana Leontodon Leucanthemum Matricaria Mycelis Pilosella "
    "Scorzoneroides Silybum Sonchus Taraxacum Tragopogon",
    "Mustard family (Brassicaceae)": "Barbarea Brassica Cakile Capsella Cardamine Diplotaxis "
    "Lepidium Lobularia Lunaria Matthiola Nasturtium Raphanus Rorippa Sisymbrium",
    "Carrot family and lemonwood (Apiales)": "Angelica Anthriscus Apium Conium Daucus Foeniculum "
    "Gingidia Helosciadium Pastinaca Petroselinum Pittosporum Smyrnium",
    "Mint, plantain and olive families (Lamiales)": "Cymbalaria Digitalis Glechoma Jasminum Lamium "
    "Lavandula Melissa Mentha Olea Origanum Plantago Prunella Stachys Thymus Verbascum Veronica",
    "Rose family and hops (Rosales)": "Chaenomeles Crataegus Cydonia Eriobotrya Fragaria Humulus "
    "Prunus Pyrus Rosa Rubus Sanguisorba Sorbus Urtica",
    "Pea family (Fabaceae)": "Acacia Cytisus Genista Lathyrus Robinia Spartium Trifolium Ulex "
    "Vicia Wisteria",
    "Succulents and saltworts (Caryophyllales)": "Amaranthus Atriplex Carpobrotus Chenopodium "
    "Disphyma Opuntia Portulaca Salicornia Suaeda Tetragonia",
    "Pinks and knotweeds (Caryophyllales)": "Cerastium Dianthus Persicaria Reynoutria Rumex "
    "Silene Stellaria",
    "Myrtles and fuchsias (Myrtales)": "Acca Fuchsia Kunzea Leptospermum Metrosideros Psidium "
    "Syzygium",
    "Heath family (Ericaceae)": "Arbutus Gaultheria Leptecophylla Styphelia",
    "Nightshades, honeysuckles and comfrey": "Convolvulus Leycesteria Lonicera Lycium Physalis "
    "Solanum Symphytum",
    "Lilies, flaxes and irises (Asparagales)": "Allium Arthropodium Asparagus Cordyline Hosta "
    "Leucojum Phormium Romulea",
    "Grasses, bamboos and raupō (Poales)": "Avena Briza Himalayacalamus Phyllostachys Pseudosasa "
    "Typha",
    "Other monocots": "Alisma Freycinetia Monstera Ripogonum Tradescantia",
    "Violets and linseed (Malpighiales)": "Euphorbia Linum Passiflora Viola",
    "Currants and pennywort (Saxifragales)": "Ribes Umbilicus",
    "Nut trees and sumac": "Aesculus Castanea Juglans Quercus Rhus",
    "Other trees and climbers": "Eschscholzia Magnolia Pseudowintera Sicyos Tilia",
    "Conifers": "Chamaecyparis Cryptomeria Dacrycarpus Dacrydium Larix Pinus Podocarpus "
    "Prumnopitys Pseudotsuga Taxus",
    "Ferns": "Asplenium Blechnum Cyathea Lecanopteris Pteridium",
    "Brown seaweeds": "Durvillaea Ecklonia Hormosira Macrocystis Splachnidium Undaria",
    "Green and red seaweeds": "Agarophyton Caulerpa Chaetomorpha Codium Pyropia Ulva",
    "Boletes (Boletales)": "Boletus Chalciporus Leccinum Suillus Xerocomellus",
    "Gilled mushrooms (Agaricales)": "Agaricus Amanita Armillaria Calvatia Chlorophyllum "
    "Clavogaster Clitocybe Coprinus Cyclocybe Flammulina Galerina Marasmius Panaeolus Pleurotus "
    "Psilocybe Stropharia Volvariella",
    "Other fungi and lichens": "Auricularia Cladonia Hericium Lactarius Morchella Trametes",
}
BATCH_OF = {genus: batch for batch, genera in BATCHES.items() for genus in genera.split()}


def prose(entry: Entry, field: str) -> str:
    value = entry.get(field)
    if isinstance(value, dict):
        return str(value.get("text") or "").strip()
    return value.strip() if isinstance(value, str) else ""


def owed(entry: Entry) -> list[str]:
    return [line for line in entry.get("sources") or [] if OWED.search(line)]


def components(entries: list[Entry]) -> list[list[Entry]]:
    """Every entry in exactly one component; singletons included."""
    by_id = {e["id"]: e for e in entries}
    parent = {i: i for i in by_id}

    def find(x: str) -> str:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: str, b: str) -> None:
        a, b = find(a), find(b)
        if a != b:
            parent[a] = b

    genus: dict[str, list[str]] = collections.defaultdict(list)
    for entry in entries:
        name = entry.get("scientificName") or ""
        if name.strip():
            genus[name.split()[0]].append(entry["id"])
    for members in genus.values():
        for other in members[1:]:
            union(members[0], other)
    for entry in entries:
        for card in entry.get("lookalikes") or []:
            if card.get("entry") in by_id:
                union(entry["id"], card["entry"])

    groups: dict[str, list[Entry]] = collections.defaultdict(list)
    for entry in entries:
        groups[find(entry["id"])].append(entry)
    return list(groups.values())


def head_word(common_name: str) -> str:
    name = re.sub(r"\(.*?\)", "", common_name.split("/")[0]).strip()
    return name.split()[-1].lower() if name else ""


def name_of(members: list[Entry]) -> str:
    for entry in members:
        if entry["id"] in NAMES:
            return NAMES[entry["id"]]
    heads = collections.Counter(head_word(e["commonName"]) for e in members)
    word, count = heads.most_common(1)[0]
    if word and count * 2 >= len(members):
        if word.endswith(("s", "fruit", "flax", "horopito")):
            plural = word
        elif word.endswith(("ch", "sh", "x")):
            plural = word + "es"
        else:
            plural = word + "s"
        return plural[:1].upper() + plural[1:]
    return " and ".join(sorted(e["commonName"] for e in members)[:2])


def row(entry: Entry, members: set[str], by_id: dict[str, Entry]) -> dict[str, Any]:
    missing = [f for f in PROSE_FIELDS if not prose(entry, f)]
    if not entry.get("months"):
        missing.append("months")
    cards = []
    for card in entry.get("lookalikes") or []:
        target = by_id.get(card.get("entry", ""))
        cards.append(
            {
                "name": target["commonName"] if target else card.get("name", card.get("entry")),
                "risk": card.get("risk", ""),
                "state": "missing" if not target else ("draft" if target.get("draft") else ""),
                "sibling": card.get("entry") in members,
            }
        )
    tags = entry.get("habitats") or []
    found = evidence(prose(entry, "habitat"))
    return {
        "id": entry["id"],
        "commonName": entry["commonName"],
        "scientificName": entry.get("scientificName", ""),
        "draft": bool(entry.get("draft")),
        "caution": entry.get("caution", ""),
        "photos": len(entry.get("photos") or []),
        "months": entry.get("months") or [],
        "missing": missing,
        "cards": cards,
        "habitats": [(tag, found.get(tag, [])) for tag in tags],
        "owed": owed(entry),
    }


def describe(members: list[Entry], by_id: dict[str, Entry]) -> dict[str, Any]:
    ids = {e["id"] for e in members}
    size = len(members)
    linked = sum(
        1
        for e in members
        for card in e.get("lookalikes") or []
        if card.get("entry") in ids and card.get("entry") != e["id"]
    )
    possible = size * (size - 1)
    rows = [row(e, ids, by_id) for e in sorted(members, key=lambda e: e["commonName"].lower())]
    drafts = sum(1 for r in rows if r["draft"])
    photoless = sum(1 for r in rows if r["photos"] == 0)
    gaps = sum(len(r["missing"]) + len(r["owed"]) for r in rows)
    return {
        "anchor": "g-" + min(e["id"] for e in members),
        "apps": [key for key, _ in GROUPS if any(e["group"] == key for e in members)],
        "name": name_of(members),
        "genera": sorted({(e.get("scientificName") or "?").split()[0] for e in members}),
        "size": size,
        "drafts": drafts,
        "photoless": photoless,
        "owed": sum(1 for r in rows if r["owed"]),
        "linked": linked,
        "possible": possible,
        "rows": rows,
        # How much one shared research session could close: large *and* mostly empty first.
        "score": gaps + photoless * 2 + (possible - linked) * 0.5 + size,
    }


def genus_of(entry: Entry) -> str:
    name = (entry.get("scientificName") or "").strip()
    return name.split()[0] if name else "?"


def batch_drafts(entries: list[Entry]) -> list[dict[str, Any]]:
    """Every draft in one batch, with the species groups it brings along, most drafts first.

    A species group goes whole into the batch most of its drafts' genera belong to.
    """
    by_id = {e["id"]: e for e in entries}
    batches: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    for members in components(entries):
        drafts = [e for e in members if e.get("draft")]
        if not drafts:
            continue
        votes = collections.Counter(BATCH_OF.get(genus_of(e), genus_of(e)) for e in drafts)
        batches[votes.most_common(1)[0][0]].append(describe(members, by_id))
    out: list[dict[str, Any]] = []
    for name, groups in batches.items():
        groups.sort(key=lambda c: (-c["drafts"], c["name"]))
        rows = [r for c in groups for r in c["rows"]]
        out.append(
            {
                "name": name,
                "anchor": "b-" + re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-"),
                "groups": groups,
                "apps": [
                    key for key, _ in GROUPS if any(by_id[r["id"]]["group"] == key for r in rows)
                ],
                "size": len(rows),
                "drafts": sum(1 for r in rows if r["draft"]),
                "photoless": sum(1 for r in rows if r["photos"] == 0),
                "owed": sum(1 for r in rows if r["owed"]),
            }
        )
    out.sort(key=lambda b: (-b["drafts"], -b["size"], b["name"]))
    return out


def file_by_group(entries: list[Entry]) -> dict[str, dict[str, Any]]:
    """App group → its species groups (ranked) and its unjoined entries.

    A species group that spans app groups (hemlock is greens, wild fennel is herbs) is split,
    so each app group shows its own members; the lookalike counts still see the whole group.
    """
    by_id = {e["id"]: e for e in entries}
    filed: dict[str, dict[str, Any]] = {key: {"clusters": [], "loose": []} for key, _ in GROUPS}
    for members in components(entries):
        whole = describe(members, by_id)
        for key, _ in GROUPS:
            part = [e for e in members if e["group"] == key]
            if not part:
                continue
            if len(members) == 1:
                filed[key]["loose"].append(whole["rows"][0])
                continue
            ids = {e["id"] for e in part}
            piece = dict(whole, rows=[r for r in whole["rows"] if r["id"] in ids])
            piece["drafts"] = sum(1 for r in piece["rows"] if r["draft"])
            piece["photoless"] = sum(1 for r in piece["rows"] if r["photos"] == 0)
            piece["owed"] = sum(1 for r in piece["rows"] if r["owed"])
            piece["shown"] = len(part)
            # Only the first app group showing a split group carries its anchor.
            piece["anchor"] = whole["anchor"] if key == whole["apps"][0] else ""
            filed[key]["clusters"].append(piece)
    for group in filed.values():
        group["clusters"].sort(
            key=lambda c: (c["drafts"] == 0, -c["drafts"], -c["score"], -c["size"], c["name"])
        )
        group["loose"].sort(key=lambda r: r["commonName"].lower())
    return filed


CSS = """
:root {
  color-scheme: light dark;
  --bg: #faf8f4; --fg: #1d1c19; --muted: #6b675f; --line: #ded8cd;
  --card: #fffdf9; --accent: #3f6b43; --warn: #9a5b12; --bad: #9c2f2a;
  --chip: #efe9dd;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #15171a; --fg: #ecebe7; --muted: #9d9a93; --line: #2e3238;
    --card: #1c1f23; --accent: #8fc096; --warn: #e0a35c; --bad: #e98079;
    --chip: #272b30;
  }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg);
  font: 15px/1.5 ui-sans-serif, -apple-system, "Segoe UI", sans-serif; }
.wrap { max-width: 1120px; margin: 0 auto; padding: 32px 20px 80px; }
h1 { font-size: 26px; margin: 0 0 6px; letter-spacing: -0.01em; }
.lede { color: var(--muted); margin: 0 0 24px; max-width: 75ch; }
.totals { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 20px; }
.total { background: var(--card); border: 1px solid var(--line); border-radius: 10px;
  padding: 10px 14px; }
.total b { display: block; font-size: 20px; }
.total span { color: var(--muted); font-size: 12px; text-transform: uppercase;
  letter-spacing: 0.06em; }
nav { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 28px; }
nav a { background: var(--chip); color: var(--fg); border-radius: 999px; padding: 4px 12px;
  font-size: 13px; text-decoration: none; }
h2.group { font-size: 21px; margin: 36px 0 12px; padding-top: 8px;
  border-top: 2px solid var(--line); }
h2.group small { color: var(--muted); font-weight: 400; font-size: 14px; margin-left: 8px; }
.cluster { background: var(--card); border: 1px solid var(--line); border-radius: 12px;
  margin-bottom: 18px; overflow: hidden; }
.head { display: flex; flex-wrap: wrap; align-items: baseline; gap: 10px;
  padding: 14px 16px; border-bottom: 1px solid var(--line); }
.head h3 { font-size: 17px; margin: 0; }
.head .genera { color: var(--muted); font-style: italic; font-size: 13px; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; margin-left: auto; }
.chip { background: var(--chip); border-radius: 999px; padding: 2px 9px; font-size: 12px;
  color: var(--muted); white-space: nowrap; }
.chip.on { color: var(--warn); }
.chip.bad { color: var(--bad); }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; min-width: 860px; }
th, td { text-align: left; padding: 8px 14px; border-bottom: 1px solid var(--line);
  vertical-align: top; font-size: 13px; }
th { color: var(--muted); font-weight: 600; font-size: 11px; text-transform: uppercase;
  letter-spacing: 0.06em; }
tbody tr:last-child td { border-bottom: 0; }
.sci { color: var(--muted); font-style: italic; }
.ok { color: var(--accent); }
.no { color: var(--bad); }
.miss { color: var(--warn); }
.dim { color: var(--muted); }
ul.list { list-style: none; margin: 0; padding: 0; }
ul.list li { margin: 0 0 4px; }
details summary { cursor: pointer; color: var(--warn); }
details ul { margin: 6px 0 0; padding-left: 16px; }
details li { margin-bottom: 6px; }
code { font: 12px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace; color: var(--muted); }
details.recipes { overflow: visible; }
details.recipes > summary { color: var(--fg); padding: 12px 16px; font-size: 15px;
  display: flex; flex-wrap: wrap; align-items: baseline; gap: 8px; }
details.recipes[open] > summary { border-bottom: 1px solid var(--line); }
.recipe { padding: 16px 18px 18px; border-bottom: 1px solid var(--line); max-width: 860px; }
.recipe:last-child { border-bottom: 0; }
.recipe h4 { font-size: 17px; margin: 0 0 4px; }
.recipe h5 { font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em;
  color: var(--muted); margin: 0 0 6px; }
.recipe h6 { font-size: 13px; margin: 10px 0 2px; color: var(--accent); }
.recipe .yield { color: var(--accent); font-weight: 600; font-size: 13px; margin: 0 0 6px; }
.recipe .source { font-size: 13px; margin: 8px 0 0; }
.recipe .source a::before { content: "🌐 "; }
.recipe .note { color: var(--muted); font-style: italic; font-size: 13px; margin: 6px 0 10px;
  max-width: 75ch; }
.recipe-body { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 2fr);
  gap: 8px 28px; margin-top: 10px; }
.recipe-body > :only-child { grid-column: 1 / -1; }
.ingredients ul { margin: 0; padding-left: 18px; }
.ingredients li { margin-bottom: 4px; font-size: 14px; }
.ingredients .aside { color: var(--muted); font-size: 13px; margin: 8px 0 0; }
.method ol { margin: 0; padding-left: 22px; }
.method li { margin-bottom: 8px; font-size: 14px; max-width: 70ch; }
.method li::marker { color: var(--accent); font-weight: 600; }
@media (max-width: 640px) { .recipe-body { grid-template-columns: 1fr; } }
"""


def esc(text: object) -> str:
    return html.escape(str(text))


# --- Recipes ---------------------------------------------------------------------------
#
# A recipe's method is stored as one paragraph of prose (`Recipe.method`). The report lays
# it out as a recipe card by reading that prose, never by changing it: sentences that open
# with a source line ("Written for …", "The author's …") become notes, "Serves 4" / "Makes
# one jar" become the yield, a list sentence before the first instruction becomes the
# ingredients ("Filling: …" starts a named group), and every other sentence is a numbered
# step. Every word of the method appears in the card exactly once.

SENTENCE = re.compile(r"(?<=[.!?])\s+(?=[A-Z0-9(½¼¾“\"])")
NOTE = re.compile(
    r"^(Written for|From (?!day)|The author|The source|The recipe|Metric|Millilitres|"
    r"Of his lists|He |She |Adapted|Converted|Built|Made from|Made with|Recorded|The amounts|"
    r"The quantities|Keeps|It keeps|They keep|"
    r"Ready (?:after|in)|Good (?:on|with|as))"
)
YIELD = re.compile(r"^(Serves|Makes|Feeds|Fills)\b")
FOR_N = re.compile(r"^For (?:\d+|one|two|three|four|five|six|eight|ten)\b[^:.;]{0,30}:\s*")
LABEL = re.compile(r"^(?:For the )?([A-Z]?[a-z]+(?: [a-z]+)?(?: \([^()]*\))?):\s+(.*)$", re.S)
YOU_NEED = re.compile(r"^You(?:'ll| will)? need\s+")
# Words that make a sentence an instruction or a remark rather than a list of things.
VERBISH = re.compile(
    r"\b(is|are|was|were|until|then|so|can|should|will|keeps?|need|needs|leave|use|uses|"
    r"must|warns?|says?)\b"
)
QUANTITY = re.compile(
    r"^(\d|½|¼|¾|⅓|a |an |the |some |about |half |one |two |three |four |five |six |"
    r"several |plenty |enough |equal |extra |more |another |plus |optional)",
    re.I,
)
# Sentence openers that make it an instruction, never a list: "Blanch 12 dock leaves, …".
IMPERATIVE = set(
    "add bake beat blanch blend blitz boil bring brown brush butter chill chop clean combine "
    "cook cool cover cream crumble crush cut dilute dip dissolve divide drain dress drink "
    "drizzle drop fill finish flatten fold fry garnish gather grate grease grind halve heat "
    "infuse keep knead ladle lay layer leave let lift line make mash melt mix muddle pack peel "
    "pick pour prepare press pulse purée put refrigerate rest return rinse roast roll rub run "
    "sauté scatter scoop score seal season serve shake shape sieve simmer slice soak soften "
    "spoon spread sprinkle squeeze steam steep sterilise stir store strain strip sweat sweeten "
    "take taste tear tip toast top toss trim turn twist uncover use warm wash whip whisk wilt wrap "
    "finely roughly lightly gently thinly".split()
)
GROUP_LABEL = re.compile(r"^for (?:the )?([a-z]+(?: [a-z]+)?),\s*(.*)$", re.S)
# A caution or aside wherever it sits in the sentence: "…; the author warns not to …".
REMARK = re.compile(r"\b(the author|he|she) (warns|notes|says)\b")
PARENS = re.compile(r"\([^()]*\)")
# Openers of a descriptor that belongs to the item before it: "…, peeled and cored".
TRAILER = re.compile(r"^(\w+ed|\w+ly|stems?|with|without|peel|seeds?|skin|or|at|in|for|such)\b")
# Imperatives that are also ingredient words ("peel and all", "butter"), so they only
# mark an instruction at the very start of a sentence.
NOUN_TOO = {"peel", "top", "butter", "line", "season", "score", "rest", "dress", "brown", "tip"}


def sentences(method: str) -> list[str]:
    return [s.strip() for s in SENTENCE.split(method.strip()) if s.strip()]


def top_level_split(text: str, sep: str) -> list[str]:
    """Split on `sep` outside parentheses."""
    parts, depth, cur, i = [], 0, "", 0
    while i < len(text):
        ch = text[i]
        depth += ch == "("
        depth -= ch == ")"
        if depth == 0 and text.startswith(sep, i):
            parts.append(cur)
            cur, i = "", i + len(sep)
            continue
        cur += ch
        i += 1
    parts.append(cur)
    return [p.strip() for p in parts if p.strip()]


def is_trailer(part: str) -> bool:
    """ "peeled and cored", "finely chopped", "soaked in the hot water" — but not "sliced
    day-old white bread", a new item that opens with a participle."""
    if not TRAILER.match(part):
        return False
    if not re.match(r"\w+ed\b", part):
        return True
    return len(part.split()) <= 3 or bool(
        re.search(r"\b(or|in|for|into|to|with|until|lengthways|from|on)\b", part)
    )


def comma_items(text: str) -> list[str]:
    items: list[str] = []
    parts = [
        piece
        for part in top_level_split(text, ",")
        for piece in re.split(
            r"\s+—\s+plus\s+", part
        )  # "… one and a half times — plus 3 tbsp sugar"
    ]
    for part in parts:
        if items and is_trailer(part):
            items[-1] += ", " + part
        else:
            items.append(part)
    # "…, 60 ml parmesan and, if you like, 300 g tofu": the aside goes with the next item.
    for i in range(len(items) - 2, -1, -1):
        if re.match(r"if \w+( \w+)?$", items[i]):
            items[i : i + 2] = [items[i] + ", " + items[i + 1]]
            if i:
                items[i - 1] = re.sub(r" and$", "", items[i - 1])
    # "… a handful of wild garlic and a little dulse": split the last item at its final
    # "and" when what follows is a new quantity, not "salt and pepper".
    if items:
        head, sep, tail = items[-1].rpartition(" and ")
        if sep and head and QUANTITY.match(tail):
            items[-1:] = [head, tail]
    return items


def ingredient_groups(label: str | None, text: str) -> list[tuple[str | None, list[str]]]:
    """A list sentence as named groups of items. Two or more semicolons separate items
    ("2 cloves garlic, minced; olive oil; …"); a single one separates comma lists, and
    "for the seasoning, …" after it starts a group of its own."""
    text = text.rstrip(".")
    parts = top_level_split(text, ";")
    groups: list[tuple[str | None, list[str]]] = [(label, [])]
    for part in parts:
        if m := GROUP_LABEL.match(part):
            groups.append((m.group(1).capitalize(), []))
            part = m.group(2)
        for piece in re.split(r"\s+—\s+then\s+|^then\s+", part):
            if not piece:
                continue
            split = comma_items(piece)
            listed = sum(bool(QUANTITY.match(i)) for i in split)
            groups[-1][1].extend(
                split if len(parts) <= 2 or listed * 2 >= len(split) > 2 else [piece]
            )
    clean = lambda item: re.sub(r"^(and|plus) ", "", item).strip()
    return [(name, [clean(i) for i in items if clean(i)]) for name, items in groups if items]


def opens_with_instruction(text: str) -> bool:
    words = [w.rstrip(",:").lower() for w in text.split(" ", 2)]
    # "Carefully twist …", "Half fill a jar …"
    if len(words) > 1 and (words[0].endswith("ly") or words[0] in ("half", "first", "then")):
        if words[1] in IMPERATIVE or words[1] == "fill":
            return True
    return words[0] in IMPERATIVE


def split_aside(text: str) -> tuple[str, str | None]:
    """ "Equal parts sorrel, sugar and water; the author usually uses 250 ml of each." —
    a list, then a remark about it after its one semicolon."""
    parts = top_level_split(text, ";")
    if (
        len(parts) == 2
        and VERBISH.search(parts[1])
        and not VERBISH.search(PARENS.sub("", parts[0]))
    ):
        return parts[0], parts[1][:1].upper() + parts[1][1:]
    return text, None


def is_ingredient_list(text: str) -> bool:
    if opens_with_instruction(text):
        return False
    if text.count(";") >= 2:
        return True
    # "In a large saucepan, bring the sugar …", "The night before, soak …"
    for part in top_level_split(text, ",")[1:]:
        verb = part.split(" ", 1)[0].lower()
        if verb in IMPERATIVE and verb not in NOUN_TOO and not verb.endswith("ly"):
            return False
    if VERBISH.search(PARENS.sub("", text)):
        return False
    lists = text.count(";") + len(top_level_split(text, ",")) - 1
    if lists >= 2:
        return True
    # "400 g dried pasta and 5 ml salt for the water."
    return bool(QUANTITY.match(text)) and (lists >= 1 or len(comma_items(text.rstrip("."))) >= 2)


def parse_recipe(method: str) -> dict[str, Any]:
    card: dict[str, Any] = {
        "lede": [],
        "yield": [],
        "groups": [],
        "asides": [],
        "steps": [],
        "notes": [],
    }
    for sentence in sentences(method):
        started = bool(card["steps"])
        if NOTE.match(sentence) or REMARK.search(sentence):
            card["notes" if started else "lede"].append(sentence)
            continue
        if m := FOR_N.match(sentence):
            card["yield"].append(sentence[: m.end()].rstrip(": "))
            sentence = sentence[m.end() :]
            sentence = sentence[:1].upper() + sentence[1:]
        if YIELD.match(sentence) and len(sentence) < 80:
            card["yield"].append(sentence.rstrip("."))
            continue
        label, body = None, sentence
        if m := LABEL.match(sentence):
            label, body = m.group(1), m.group(2)
        if m := YOU_NEED.match(body):
            body = body[m.end() :]
        listed, aside = split_aside(body)
        # After the first step only an unmistakable list still counts: "First infuse the
        # vodka …. 75 ml sake, 15 ml gin, 15 ml of the vodka …"
        strong = sum(bool(QUANTITY.match(i)) for i in comma_items(listed.rstrip("."))) >= 3
        if (not started or strong) and is_ingredient_list(listed):
            card["groups"].extend(ingredient_groups(label, listed))
            if aside:
                card["asides"].append(aside)
        else:
            card["steps"].append((label, body))
    return card


def render_recipe(recipe: dict[str, str]) -> str:
    out = ['<article class="recipe">', f"<h4>{esc(recipe['title'])}</h4>"]
    if not recipe["method"].strip():
        out.append('<p class="dim">No method written yet.</p>' + source_link(recipe) + "</article>")
        return "".join(out)
    card = parse_recipe(recipe["method"])
    if card["yield"]:
        out.append(f'<p class="yield">{esc(" · ".join(card["yield"]))}</p>')
    if card["lede"]:
        out.append(f'<p class="note">{esc(" ".join(card["lede"]))}</p>')
    out.append('<div class="recipe-body">')
    if card["groups"]:
        out.append('<div class="ingredients"><h5>Ingredients</h5>')
        for label, items in card["groups"]:
            if label:
                out.append(f"<h6>{esc(label)}</h6>")
            out.append("<ul>" + "".join(f"<li>{esc(i)}</li>" for i in items) + "</ul>")
        for aside in card["asides"]:
            out.append(f'<p class="aside">{esc(aside)}</p>')
        out.append("</div>")
    if card["steps"]:
        out.append('<div class="method"><h5>Method</h5><ol>')
        for label, text in card["steps"]:
            lead = f"<b>{esc(label)}:</b> " if label else ""
            out.append(f"<li>{lead}{esc(text)}</li>")
        out.append("</ol></div>")
    out.append("</div>")
    if card["notes"]:
        out.append(f'<p class="note">{esc(" ".join(card["notes"]))}</p>')
    out.append(source_link(recipe))
    out.append("</article>")
    return "".join(out)


def source_link(recipe: dict[str, str]) -> str:
    url = recipe.get("sourceURL")
    if not url:
        return '<p class="dim">No source link yet.</p>'
    return f'<p class="source"><a href="{esc(url)}">View source recipe</a></p>'


def render_recipes(entries: list[Entry]) -> list[str]:
    cooked = sorted((e for e in entries if e.get("recipes")), key=lambda e: e["commonName"])
    total = sum(len(e["recipes"]) for e in cooked)
    out = [
        f'<h2 class="group" id="recipes">Recipes<small>{total} recipes on {len(cooked)} '
        "entries</small></h2>"
    ]
    for e in cooked:
        count = len(e["recipes"])
        out.append(f'<details class="cluster recipes" id="recipes-{esc(e["id"])}"><summary>')
        out.append(
            f'<b>{esc(e["commonName"])}</b> <span class="sci">{esc(e["scientificName"])}</span>'
            f' <span class="chip">{count} recipe{"s" if count != 1 else ""}</span></summary>'
        )
        out.extend(render_recipe(r) for r in e["recipes"])
        out.append("</details>")
    return out


def months_text(months: list[int]) -> str:
    if not months:
        return '<span class="dim">year-round / unknown</span>'
    if len(months) == 12:
        return "all year"
    return esc(", ".join(MONTHS[m - 1] for m in months))


def render_row(r: dict[str, Any]) -> str:
    state = '<span class="miss">draft</span>' if r["draft"] else '<span class="ok">shipped</span>'
    photos = (
        f'<span class="ok">{r["photos"]}</span>' if r["photos"] else '<span class="no">0</span>'
    )
    missing = (
        f'<span class="miss">{esc(", ".join(r["missing"]))}</span>'
        if r["missing"]
        else '<span class="ok">complete</span>'
    )
    if r["owed"]:
        items = "".join(f"<li>{esc(line)}</li>" for line in r["owed"])
        missing += (
            f"<details><summary>{len(r['owed'])} owed to a person</summary>"
            f"<ul>{items}</ul></details>"
        )
    cards = []
    for c in r["cards"]:
        flag = {
            "draft": ' <span class="miss">(draft)</span>',
            "missing": ' <span class="no">(no page)</span>',
        }.get(c["state"], "")
        cards.append(f'<li>{esc(c["name"])} <span class="dim">· {esc(c["risk"])}</span>{flag}</li>')
    card_cell = f'<ul class="list">{"".join(cards)}</ul>' if cards else '<span class="dim">—</span>'
    tags = []
    for tag, words in r["habitats"]:
        why = (
            f' <span class="dim">← {esc(", ".join(words))}</span>'
            if words
            else ' <span class="miss">(not in its habitat prose)</span>'
        )
        tags.append(f"<li>{esc(tag)}{why}</li>")
    tag_cell = f'<ul class="list">{"".join(tags)}</ul>' if tags else '<span class="dim">—</span>'
    return (
        f'<tr id="e-{esc(r["id"])}">'
        f"<td><b>{esc(r['commonName'])}</b><br>"
        f'<span class="sci">{esc(r["scientificName"])}</span><br>'
        f"<code>{esc(r['id'])}</code></td>"
        f'<td>{state}<br><span class="dim">{esc(r["caution"])}</span></td>'
        f"<td>{photos}</td>"
        f"<td>{months_text(r['months'])}</td>"
        f"<td>{missing}</td>"
        f"<td>{card_cell}</td>"
        f"<td>{tag_cell}</td>"
        "</tr>"
    )


def render_table(rows: list[dict[str, Any]]) -> list[str]:
    out = ['<div class="scroll"><table><thead><tr>']
    for header in ["Entry", "State", "Photos", "Months", "Missing", "Lookalikes", "Habitats"]:
        out.append(f"<th>{header}</th>")
    out.append("</tr></thead><tbody>")
    out.extend(render_row(r) for r in rows)
    out.append("</tbody></table></div>")
    return out


def render(entries: list[Entry]) -> str:
    filed = file_by_group(entries)
    out = [
        "<title>Catalogue report</title>",
        f"<style>{CSS}</style>",
        '<div class="wrap">',
        "<h1>Catalogue report</h1>",
        '<p class="lede">Every entry, filed by its app group and then by species group — '
        "entries sharing a genus or a lookalike card, the ones one research session fills "
        "together. It opens with every draft batched by plant family, most drafts first. "
        "A habitat tag is followed by the words in that entry's own habitat prose that "
        "support it. Generated by "
        "<code>Tools/catalogue_report.py</code>; do not edit by hand.</p>",
    ]
    totals = [
        (len(entries), "entries"),
        (sum(1 for e in entries if not e.get("draft")), "shipped"),
        (sum(1 for e in entries if e.get("draft")), "draft"),
        (sum(1 for e in entries if not e.get("photos")), "with no photo"),
        (sum(1 for e in entries if owed(e)), "owe a person's text"),
        (sum(len(e.get("recipes", [])) for e in entries), "recipes"),
    ]
    out.append('<div class="totals">')
    for value, label in totals:
        out.append(f'<div class="total"><b>{value}</b><span>{esc(label)}</span></div>')
    out.append("</div><nav>")
    out.append('<a href="#next">Pick up next</a>')
    for key, label in GROUPS:
        count = sum(1 for e in entries if e["group"] == key)
        out.append(f'<a href="#{key}">{esc(label)} · {count}</a>')
    out.append('<a href="#recipes">Recipes</a>')
    out.append("</nav>")

    labels = dict(GROUPS)
    picks = batch_drafts(entries)
    out.append(
        f'<h2 class="group" id="next">Pick up next<small>{len(picks)} batches by plant family, '
        "most drafts first</small></h2>"
    )
    out.append('<nav>')
    for b in picks:
        out.append(f'<a href="#{b["anchor"]}">{esc(b["name"])} · {b["drafts"]}</a>')
    out.append("</nav>")
    for b in picks:
        out.append(f'<section class="cluster" id="{b["anchor"]}"><div class="head">')
        out.append(f"<h3>{esc(b['name'])}</h3>")
        out.append(f'<span class="genera">{esc(" / ".join(labels[k] for k in b["apps"]))}</span>')
        out.append('<div class="chips">')
        out.append(f'<span class="chip on">{b["drafts"]} of {b["size"]} draft</span>')
        if b["photoless"]:
            out.append(f'<span class="chip bad">{b["photoless"]} no photo</span>')
        if b["owed"]:
            out.append(f'<span class="chip on">{b["owed"]} owe text</span>')
        out.append("</div></div>")
        out.append('<div class="scroll"><table><thead><tr>')
        for header in ["Species group", "Draft", "Photos", "Missing"]:
            out.append(f"<th>{header}</th>")
        out.append("</tr></thead><tbody>")
        for c in b["groups"]:
            drafts = [r for r in c["rows"] if r["draft"]]
            group = (
                f'<a href="#{c["anchor"]}"><b>{esc(c["name"])}</b></a><br>'
                f'<span class="dim">{c["drafts"]} of {c["size"]} draft</span>'
                if c["size"] > 1
                else '<span class="dim">—</span>'
            )
            for i, r in enumerate(drafts):
                first = f'<td rowspan="{len(drafts)}">{group}</td>' if i == 0 else ""
                photos = (
                    f'<span class="ok">{r["photos"]}</span>'
                    if r["photos"]
                    else '<span class="no">0</span>'
                )
                gaps = r["missing"] + (["owed text"] if r["owed"] else [])
                missing = (
                    f'<span class="miss">{esc(", ".join(gaps))}</span>'
                    if gaps
                    else '<span class="ok">complete</span>'
                )
                out.append(
                    f"<tr>{first}"
                    f'<td><a href="#e-{esc(r["id"])}"><b>{esc(r["commonName"])}</b></a><br>'
                    f'<span class="sci">{esc(r["scientificName"])}</span></td>'
                    f"<td>{photos}</td><td>{missing}</td></tr>"
                )
        out.append("</tbody></table></div></section>")

    for key, label in GROUPS:
        group = filed[key]
        count = sum(1 for e in entries if e["group"] == key)
        out.append(f'<h2 class="group" id="{key}">{esc(label)}<small>{count} entries</small></h2>')
        for c in group["clusters"]:
            anchor = f' id="{c["anchor"]}"' if c["anchor"] else ""
            out.append(f'<section class="cluster"{anchor}><div class="head">')
            out.append(f"<h3>{esc(c['name'])}</h3>")
            out.append(f'<span class="genera">{esc(" / ".join(c["genera"]))}</span>')
            out.append('<div class="chips">')
            size = (
                f"{c['shown']} of {c['size']} entries"
                if c["shown"] != c["size"]
                else (f"{c['size']} entries")
            )
            out.append(f'<span class="chip">{esc(size)}</span>')
            if c["drafts"]:
                out.append(f'<span class="chip on">{c["drafts"]} draft</span>')
            if c["photoless"]:
                out.append(f'<span class="chip bad">{c["photoless"]} no photo</span>')
            if c["owed"]:
                out.append(f'<span class="chip on">{c["owed"]} owe text</span>')
            out.append(f'<span class="chip">lookalike pairs {c["linked"]}/{c["possible"]}</span>')
            out.append("</div></div>")
            out.extend(render_table(c["rows"]))
            out.append("</section>")
        if group["loose"]:
            out.append('<section class="cluster"><div class="head">')
            out.append("<h3>Not in a species group</h3>")
            out.append('<div class="chips">')
            out.append(f'<span class="chip">{len(group["loose"])} entries</span>')
            out.append("</div></div>")
            out.extend(render_table(group["loose"]))
            out.append("</section>")

    out.extend(render_recipes(entries))
    out.append("</div>")
    return "\n".join(out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(REPO / "docs" / "catalogue.html"))
    args = parser.parse_args()

    entries: list[Entry] = json.loads(SPECIES.read_text())
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(entries))
    print(f"{len(entries)} entries → {out}")


if __name__ == "__main__":
    main()
