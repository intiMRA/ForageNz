#!/usr/bin/env python3
"""Write the one HTML report on the catalogue: every entry, grouped, with what it still owes.

Entries are filed by their app group (greens, herbs, fruit, fungi, seaweed, nuts), then by
species group inside it — the bamboos, the passionfruit, the milkcaps. A species group is a
connected component over two kinds of edge:

  * same genus — the first word of ``scientificName``;
  * a lookalike card between two entries that are both in the catalogue.

Those are the groups where one research session fills several entries at once. Inside each
app group the groups with drafts come before the finished ones. Entries joined to nothing are
listed last in their app group.

Per entry the report shows its state, caution, photos, months, the prose fields still empty,
its lookalike cards (and whether each opens a draft), its "grows with" partners (flagging any
the partner's entry does not link back), its habitat tags with the words in its
own habitat prose that support them, and every ``OWED`` line in its sources — the text only
a person may write.

While any lead is open, the report opens with "Link next": the "grows with" partnerships a link can be made from, from
``docs/association-leads.json`` (written by ``Tools/globi_symbioses.py``, which keeps a GloBI
GloBI's specific partnership records, generalists left out, with Biota of New Zealand's record
count beside each as a head start), split into batches by the kind of fungus (``LINK_BATCHES``), one row per fungus.
Pairs the associations plan already declined are left out of the page (owner 23/11/2026),
counted in a chip, and so are the hosts of a fungus declined with every tree.
Host plants with no wild New Zealand presence (``NOT_IN_NZ_HOSTS``) are dropped from the leads.

    python3 Tools/catalogue_report.py [--out docs/catalogue.html] [--leads docs/association-leads.json]
"""

from __future__ import annotations

import argparse
import collections
import html
import json
import pathlib
import re
import urllib.parse
from typing import Any

from classify_habitats import evidence

REPO = pathlib.Path(__file__).resolve().parent.parent
SPECIES = REPO / "ForageNZ" / "Catalogue" / "species.json"
LEADS = REPO / "docs" / "association-leads.json"

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
    "pineappleweed": "Chamomile and pineappleweed",
    "harakeke": "Flax",
    "hawthorn": "Hawthorn and medlar",
    "lowland-horopito": "Horopito",
    "kiokio": "Kiokio and rereti",
    "rosehip": "Roses",
    "sea-grapes": "Sea grapes and sea rimu",
    "sweet-violet": "Violets",
    "cabbage-tree": "Cabbage trees",
    "native-ice-plant": "Ice plants",
    "bluefoot-bolete": "Bluefoot and riverine boletes",
    "sticky-mouse-ear-chickweed": "Mouse-ear chickweeds",
}

# "Link next" batches: fungus genus → batch, in the order they are worked. A pair with no fungus
# goes in PLANT_BATCH, a genus not listed in its own batch named after it.
LINK_BATCHES = {
    "Boletes and suillus": (
        "Boletus Leccinum Xerocomellus Chalciporus Suillus",
        "Root partners. Each pair needs a New Zealand record naming the host species "
        "(Biota PDD host records read through the current name, Virtual Mycota).",
    ),
    "Milkcaps, amanitas and webcaps": (
        "Lactarius Amanita Cortinarius Russula",
        "Root partners. Each pair needs a New Zealand record naming the host species "
        "(Biota PDD host records read through the current name, Virtual Mycota).",
    ),
    "Wood-rotters and tree parasites": (
        "Armillaria Flammulina Trametes Auricularia Pleurotus Cyclocybe",
        "Owner scope 16/11: a link only when the fungus needs one particular tree; a "
        "generalist on any dead wood gets none.",
    ),
    "Ground and litter mushrooms": (
        "Agaricus Marasmius Calvatia Coprinus Stropharia Morchella Psilocybe Chlorophyllum Clitocybe",
        "Grassland, compost and litter fungi.",
    ),
}
LINK_BATCH_OF = {
    genus: batch for batch, (genera, _) in LINK_BATCHES.items() for genus in genera.split()
}
PLANT_BATCH = "Plants on plants"
PLANT_NOTE = "Epiphytes and climbers recorded on one host."

# Pairs docs/plans/species-associations.md already declined (23/11/2026), with its reason.
DECLINED = {
    frozenset(pair): reason
    for reason, pairs in {
        "genus-only record ('Quercus sp.')": [
            ("oakbug-milkcap", "english-oak"), ("oakbug-milkcap", "holm-oak")
        ],
        "no NZ record for chestnut": [("porcini", "sweet-chestnut")],
        "genus-only record": [
            ("death-cap", "manuka"), ("death-cap", "kanuka"),
            ("fly-agaric", "larch"), ("fly-agaric", "manuka"),
        ],
        "one photo record": [("olive-oyster", "silver-beech")],
        "no species-level NZ record": [("skirt-webcap", "black-beech")],
        "single record outside its beech habitat": [
            ("umere-milkcap", "kanuka"), ("tawai-milkcap", "totara")
        ],
        # GloBI leads checked against Biota NZ PDD host records 23/11/2026.
        "no NZ record naming this tree": [
            ("slippery-jack", "black-walnut"), ("slippery-jack", "common-pear"),
            ("slippery-jack", "douglas-fir"), ("slippery-jack", "english-oak"),
            ("slippery-jack", "european-beech"), ("slippery-jack", "japanese-walnut"),
            ("slippery-jack", "plantain"), ("slippery-jack", "silver-birch"),
            ("birch-bolete", "black-cherry"), ("birch-bolete", "english-oak"),
            ("larch-bolete", "monterey-pine"), ("larch-bolete", "european-beech"),
            ("western-painted-suillus", "monterey-pine"),
            ("fly-agaric", "black-walnut"), ("fly-agaric", "japanese-walnut"),
            ("fly-agaric", "strawberry-tree"), ("fly-agaric", "sweet-chestnut"),
            ("oakbug-milkcap", "european-beech"), ("oakbug-milkcap", "silver-birch"),
            ("saffron-milk-cap", "black-locust-tree"), ("saffron-milk-cap", "douglas-fir"),
            ("slimy-milkcap", "european-beech"), ("slimy-milkcap", "silver-birch"),
        ],
        "genus-only record ('Pinus')": [("porcini", "monterey-pine")],
        "no NZ record; one GloBI 'symbiontOf' record with no study or place": [
            ("slippery-jack", "heather")
        ],
        "a decomposer; GloBI's untraced root-partner row has no study and no other source (owner 24/11/2026: research)": [
            ("shaggy-inkcap", "norway-spruce")
        ],
        "a decomposer; GloBI's one 'hasHost' row has no study, and no root or dead-wood kind fits (owner 24/11/2026: no honest kind, decline)": [
            ("shaggy-inkcap", "greek-fir")
        ],
        "a needle-litter decomposer, not a root or dead-wood partner (owner 24/11/2026: decline)": [
            ("shaggy-parasol", "norway-spruce")
        ],
        "a decomposer of litter or woodchips, not a root or dead-wood partner; one GloBI row (24/11/2026 rule: no honest kind, decline)": [
            ("shaggy-inkcap", "black-locust-tree"), ("psilocybe-aucklandiae", "monterey-pine")
        ],
        "an epiphyte or epiphytic seedling on the tree, not a root, parasite or dead-wood partner; one GloBI row (no honest kind, decline)": [
            ("hounds-tongue-fern", "matai"), ("karamu", "totara"), ("lemonwood", "totara")
        ],
        "two plants with no root, parasite or dead-wood kind between them; one GloBI row (no honest kind, decline)": [
            ("scotch-broom", "aleppo-pine"), ("scotch-broom", "austrian-pine"), ("scotch-broom", "corsican-pine"),
            ("scotch-broom", "maritime-pine"), ("scotch-broom", "scots-pine")
        ],
        "probably a parasite of other fungi (Cooper), not a beech partner": [
            ("chalciporus-aurantiacus", "silver-beech"), ("chalciporus-aurantiacus", "hard-beech")
        ],
    }.items()
    for pair in pairs
}
# GloBI host leads declined for one fungus, by the host's GloBI name: the host has no entry and
# needs none for this fungus. The plan says why.
DECLINED_HOSTS = {
    ("shaggy-inkcap", "Dittrichia graveolens"): "an untraced root-partner record for a decomposer (owner 24/11/2026: decline)",
    ("shaggy-inkcap", "Lolium perenne"): "a GloBI host row with no study for a grassland decomposer; no honest partnership kind (owner 24/11/2026: skip)",
    ("birch-bolete", "Avenella flexuosa subsp. flexuosa"): "a grass is not a bolete root partner; GloBI row with no study, no Biota record (owner 24/11/2026: skip)",
}
# Fungi declined with every tree, and why.
DECLINED_WITH_TREES = {"peppery-bolete": "treated as a parasite of fly agaric, not a tree partner"}
# GloBI host plants with no wild New Zealand presence (iNaturalist NZ, Flora, Biota herbarium checked),
# dropped from the leads on the owner's word (23/11/2026: "if dont exist in nz drop"). The plan says why.
NOT_IN_NZ_HOSTS = {
    "Pinus densiflora": "Biota: cultivated; one naturalised sheet (NZFRI 27531), 0 wild iNaturalist NZ",
    "Pinus thunbergii": "Biota: cultivated; wild only at Muriwai and Whangarei Heads (owner 23/11/2026: drop)",
    "Pinus ayacahuite": "Biota: cultivated; one naturalised tree (NZFRI 27621), 0 wild iNaturalist NZ",
    "Pinus hartwegii": "Biota: cultivated; all 17 NZ herbarium sheets planted, 0 wild iNaturalist NZ",
    "Pinus edulis": "Biota: cultivated; all 15 NZ herbarium sheets planted, 1 captive iNaturalist NZ",
    "Pinus lambertiana": "Biota: cultivated; all 15 NZ herbarium sheets planted, 0 iNaturalist NZ",
    "Pinus tabuliformis": "Biota: cultivated; all 14 NZ herbarium sheets planted, 3 captive iNaturalist NZ",
    "Pinus jeffreyi": "Biota: cultivated; wild only in the Mackenzie Basin (CHR 658228, 658229), 3 captive iNaturalist NZ",
    "Pinus kesiya": "Biota: cultivated; all 12 NZ herbarium sheets planted, 1 botanic-garden iNaturalist NZ",
    "Pinus resinosa": "Biota: cultivated; all 12 NZ herbarium sheets planted, 0 iNaturalist NZ",
    "Pinus koraiensis": "Biota: cultivated; all 10 NZ herbarium sheets planted, 2 captive iNaturalist NZ",
    "Tsuga canadensis": "not on NZ Flora Online; all 9 NZ herbarium sheets planted, 2 captive iNaturalist NZ (owner 24/11/2026: drop)",
    "Pinus pumila": "not on NZ Flora Online; one nursery display-garden sheet, 0 iNaturalist NZ (owner 24/11/2026: drop)",
    "Tilia cordata": "Biota: cultivated; 49 iNaturalist NZ are street/park trees, 13 sheets planted (owner 24/11/2026: drop)",
    "Carpinus betulus": "Biota: cultivated; 17 iNaturalist NZ are hedges/street trees, 17 sheets planted (owner 24/11/2026: drop)",
    "Agrostis canina": "not in NZ Flora Online; 0 iNaturalist NZ, old sheet names are native Agrostis (owner 24/11/2026: drop)",
    "Populus tremuloides": "Biota: cultivated; 1 iNaturalist NZ (ID disputed), 5 sheets, none called wild (owner 24/11/2026: drop)",
    "Lophozonia cunninghamii": "Biota: cultivated; 2 iNaturalist NZ (parent-only seedlings, zoo), 17 sheets planted (owner 24/11/2026: drop)",
    "Corymbia ficifolia": "Biota: casual; all iNaturalist NZ and sheets ornamental/plantation, none self-sown (owner 24/11/2026: drop)",
    "Metrosideros collina": "Biota: casual; 3 iNaturalist NZ all planted/garden, every herbarium sheet cultivated (owner 24/11/2026: drop)",
    "Betula papyrifera": "Biota: casual, one 1968 sheet; 3 iNaturalist NZ all needing ID, rest planted (owner 24/11/2026: drop)",
    "Acer saccharum": "Biota: cultivated; 0 iNaturalist NZ, 7 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Abies lasiocarpa": "Biota: cultivated; 0 iNaturalist NZ, 5 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Betula alleghaniensis": "Biota: cultivated; 0 iNaturalist NZ, 5 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Alnus rhombifolia": "Biota: cultivated; 2 iNaturalist NZ, 4 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Betula ermanii": "Biota: cultivated; 0 iNaturalist NZ, 2 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Betula lenta": "Biota: cultivated; 0 iNaturalist NZ, 2 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Betula nana": "Biota: no biostatus row; 0 iNaturalist NZ, 1 herbarium sheet, none wild (owner 24/11/2026: drop)",
    "Quercus mongolica": "Biota: cultivated; 0 iNaturalist NZ, 2 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Quercus petraea": "Biota: cultivated; 0 iNaturalist NZ, 15 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Quercus agrifolia": "Biota: cultivated; 0 iNaturalist NZ, 6 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Abies sachalinensis": "Biota: no biostatus row; 0 iNaturalist NZ, 1 herbarium sheet, none wild (owner 24/11/2026: drop)",
    "Abies amabilis": "Biota: cultivated; 0 iNaturalist NZ, 9 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Nothofagus dombeyi": "not on NZ Flora Online (only N. antarctica); 1 garden-tree iNaturalist NZ, all 21 sheets cultivated (owner rule 24/11/2026: drop)",
    "Picea glauca": "Biota: cultivated; 0 iNaturalist NZ, 13 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Picea pungens": "Biota: cultivated; 4 iNaturalist NZ, 10 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Picea engelmannii": "Biota: cultivated; 0 iNaturalist NZ, 9 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Carya ovata": "Biota: cultivated; 0 iNaturalist NZ, 11 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Carya laciniosa": "Biota: no biostatus row; 0 iNaturalist NZ, 1 herbarium sheet, none wild (owner 24/11/2026: drop)",
    "Pinus clausa": "Biota: no biostatus row; 0 iNaturalist NZ, 1 herbarium sheet, none wild (owner 24/11/2026: drop)",
    "Pinus massoniana": "Biota: cultivated; 0 iNaturalist NZ, 10 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Castanea dentata": "Biota: no biostatus row; 0 iNaturalist NZ, 2 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Tilia tomentosa": "Biota: cultivated; 1 iNaturalist NZ, 24 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Larix gmelinii": "Biota: cultivated; 0 iNaturalist NZ, 10 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Larix laricina": "Biota: no biostatus row; 0 iNaturalist NZ, 1 herbarium sheet, none wild (owner 24/11/2026: drop)",
    "Acer sterculiaceum subsp. franchetii": "Biota: no biostatus row; 0 iNaturalist NZ, 2 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Callitropsis nootkatensis": "Biota: cultivated; 0 iNaturalist NZ, 18 herbarium sheets, none wild (owner 24/11/2026: drop)",
    "Populus cathayana": "Biota: no biostatus row; 0 iNaturalist NZ, 1 herbarium sheet, none wild (owner 24/11/2026: drop)",
    "Fagus grandifolia": "Biota: cultivated; 1 iNaturalist NZ, 1 herbarium sheet, none wild (owner 24/11/2026: drop)",
}
# Most links a cell shows, the commonest in New Zealand (GBIF occurrences) first; the rest are counted.
LINKS_SHOWN = 10
# GloBI host names that are catalogue entries under an older name. Biota's 'Nothofagus solandri'
# records split between black and mountain beech, so that name stands for both, and 'Salix
# babylonica' stands for weeping willow, whose New Zealand plants are S. ×pendulina (Glenny 2022).
HOST_ALIASES = {
    "Eucalyptus pauciflora subsp. pauciflora": ["snow-gum"],
    "Nothofagus fusca": ["red-beech"],
    "Nothofagus truncata": ["hard-beech"],
    "Nothofagus menziesii": ["silver-beech"],
    "Nothofagus cliffortioides": ["mountain-beech"],
    "Nothofagus solandri": ["black-beech", "mountain-beech"],
    "Macropiper excelsum": ["kawakawa"],
    "Podocarpus hallii": ["halls-totara"],
    "Psidium cattleianum": ["cherry-guava"],
    "Salix babylonica": ["weeping-willow"],
}


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


# The kind the partner's entry must carry for the same partnership — `AssociationKind.reverse`.
REVERSE_KIND = {
    "mycorrhizalPartner": "mycorrhizalPartner",
    "parasiteOf": "hostOf",
    "hostOf": "parasiteOf",
    "growsOnDeadWoodOf": "deadWoodHostOf",
    "deadWoodHostOf": "growsOnDeadWoodOf",
}


def has_reverse(entry: Entry, link: dict[str, str], by_id: dict[str, Entry]) -> bool:
    """Whether the partner's entry links back to ``entry`` with the reverse kind."""
    partner = by_id.get(link.get("entry", ""))
    if partner is None:
        return False
    wanted = REVERSE_KIND.get(link.get("kind", ""))
    return any(
        back.get("entry") == entry["id"] and back.get("kind") == wanted
        for back in partner.get("associations") or []
    )


def row(entry: Entry, members: set[str], by_id: dict[str, Entry]) -> dict[str, Any]:
    missing = [f for f in PROSE_FIELDS if not prose(entry, f)]
    # Months are the harvest window of the eaten part, so a doNotEat entry has none to give.
    if not entry.get("months") and entry.get("caution") != "doNotEat":
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
    partners = []
    for link in entry.get("associations") or []:
        target = by_id.get(link.get("entry", ""))
        partners.append(
            {
                "name": target["commonName"] if target else link.get("entry"),
                "kind": link.get("kind", ""),
                "state": "missing" if not target else ("draft" if target.get("draft") else ""),
                "oneWay": not has_reverse(entry, link, by_id),
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
        "partners": partners,
        "habitats": [(tag, found.get(tag, [])) for tag in tags],
        "uses": [
            {
                "kind": use.get("kind", ""),
                "recipes": len(use.get("recipes") or []),
                "months": use.get("months") or [],
            }
            for use in entry.get("uses") or []
        ],
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


def capped_list(items: list[str], total: int) -> str:
    """At most LINKS_SHOWN list items, with a count of the ones left out."""
    if not items:
        return '<span class="dim">—</span>'
    more = f'<span class="dim">and {total - len(items)} more</span>' if total > len(items) else ""
    return f'<ul class="list">{"".join(items)}</ul>{more}'


def inaturalist_url(entry: Entry | None, name: str) -> str:
    """The entry's own iNaturalist taxon page when it has one, else an iNaturalist taxon search."""
    url = (entry or {}).get("moreImagesURL") or ""
    if "inaturalist.org/taxa/" in url or "inaturalist.nz/taxa/" in url:
        return url
    name = re.sub(r"\s*\(.*?\)", "", name).strip()
    return "https://www.inaturalist.org/taxa/search?" + urllib.parse.urlencode({"q": name})


def partners_sheet(row: dict[str, Any], open_pairs: list[dict[str, Any]]) -> str:
    """A <dialog> table of every open partner of one row, commonest in New Zealand first."""
    e = row["entry"]
    lines = [
        (p.get("nz", 0), p["entry"]["commonName"], p["entry"].get("scientificName", ""), p["entry"], p)
        for p in open_pairs
    ] + [(h["nz"], "", h["name"], None, h) for h in row["hosts"]]
    lines.sort(key=lambda line: (-line[0], (line[1] or line[2]).lower()))
    body = []
    for nz, common, sci, entry, item in lines:
        name = (
            f'<a href="#e-{esc(entry["id"])}">{esc(common)}</a>' if entry else '<span class="dim">no entry</span>'
        )
        records = item["records"]
        body.append(
            f"<tr><td>{name}</td><td class=\"sci\">{esc(sci)}</td>"
            f"<td>{esc(', '.join(item['kinds']))}</td><td>{records}</td><td>{item.get('biota', 0) or '—'}</td><td>{nz}</td>"
            f'<td><a href="{esc(inaturalist_url(entry, sci))}" target="_blank" rel="noopener">iNaturalist</a></td></tr>'
        )
    return (
        f'<dialog class="partners" id="more-{esc(e["id"])}"><div class="bar">'
        f"<h3>{esc(e['commonName'])} · symbiosis partners</h3>"
        f'<span class="dim">{len(lines)} in GloBI, commonest in NZ first</span>'
        '<form method="dialog"><button class="more">Close</button></form></div>'
        "<table><thead><tr><th>Catalogue entry</th><th>Scientific name</th>"
        f"<th>GloBI relationship (from {esc(e['commonName'])})</th><th>Records</th><th>Biota NZ records</th>"
        "<th>GBIF NZ occurrences</th><th>Species page</th></tr></thead>"
        f"<tbody>{''.join(body)}</tbody></table></dialog>"
    )


def declined(fungus: str, partner: Entry) -> str | None:
    """Why the associations plan declined this pair, or `None` when it is still open."""
    reason = DECLINED.get(frozenset((fungus, partner["id"])))
    if reason is None and partner["group"] != "fungi":
        reason = DECLINED_WITH_TREES.get(fungus)
    return reason


#: Rank words GloBI keeps in infraspecific names and the catalogue drops, writing names as
#: iNaturalist does (owner, 23/11/2026): GloBI's "Pinus nigra subsp. laricio" is the
#: catalogue's "Pinus nigra laricio".
RANK_WORDS = frozenset({"subsp.", "ssp.", "var.", "f."})


def plain_name(name: str) -> str:
    """A scientific name without rank words, for matching names across sources."""
    return " ".join(word for word in name.split() if word not in RANK_WORDS)


def link_batches(entries: list[Entry], leads: dict[str, Any]) -> list[dict[str, Any]]:
    """The GloBI leads still to research, split into batches of one row per fungus.

    A pair the catalogue has linked since the leads were written, or naming an entry that no
    longer exists, is left out; a declined one stays, marked with the plan's reason.
    """
    by_id = {e["id"]: e for e in entries}
    by_sci = {plain_name(e.get("scientificName") or ""): e["id"] for e in entries}
    rows: dict[str, dict[str, Any]] = {}

    def row_for(subject: str) -> dict[str, Any]:
        return rows.setdefault(subject, {"entry": by_id[subject], "pairs": [], "hosts": []})

    for pair in leads.get("pairs", []):
        a, b = by_id.get(pair["a"]), by_id.get(pair["b"])
        if a is None or b is None:
            continue
        if any(link["entry"] in (a["id"], b["id"]) for e in (a, b) for link in e.get("associations") or []):
            continue
        fungi = [e for e in (a, b) if e["group"] == "fungi"]
        subject = fungi[0] if fungi else a
        partner = b if subject is a else a
        row_for(subject["id"])["pairs"].append(
            {
                "entry": partner,
                "kinds": pair["kinds"].get(subject["id"]) or pair["kinds"].get(partner["id"], []),
                "records": max(pair["records"].values(), default=0),
                "biota": pair.get("biota", 0),
                "nz": (pair.get("nz") or {}).get(partner["id"], 0),
                "declined": declined(subject["id"], partner),
            }
        )
    for fungus, hosts in leads.get("hosts", {}).items():
        if fungus not in by_id:
            continue
        row = row_for(fungus)
        linked = {link["entry"] for link in by_id[fungus].get("associations") or []}
        for host in hosts:
            for alias in HOST_ALIASES.get(host["name"], []):
                if alias in by_id and alias not in linked and all(p["entry"]["id"] != alias for p in row["pairs"]):
                    row["pairs"].append(
                        {
                            "entry": by_id[alias],
                            "kinds": host["kinds"],
                            "records": host["records"],
                            "biota": host.get("biota", 0),
                            "nz": host["nz"],
                            "declined": declined(fungus, by_id[alias]),
                        }
                    )
        row["hosts"] = (
            []
            if fungus in DECLINED_WITH_TREES
            else [
                {**h, "linked": by_sci.get(plain_name(h["name"])) in linked}
                for h in hosts
                if h["name"] not in HOST_ALIASES and h["name"] not in NOT_IN_NZ_HOSTS
                and (fungus, h["name"]) not in DECLINED_HOSTS
                and not (plain_name(h["name"]) in by_sci and declined(fungus, by_id[by_sci[plain_name(h["name"])]]))
            ]
        )

    def batch_of(entry: Entry) -> str:
        if entry["group"] != "fungi":
            return PLANT_BATCH
        genus = genus_of(entry)
        return LINK_BATCH_OF.get(genus, genus)

    batches: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    for r in rows.values():
        r["pairs"].sort(
            key=lambda p: (p["declined"] is not None, -p.get("nz", 0), -p["records"], p["entry"]["commonName"].lower())
        )
        r["open"] = sum(1 for p in r["pairs"] if not p["declined"])
        batches[batch_of(r["entry"])].append(r)
    order = list(LINK_BATCHES) + [PLANT_BATCH]
    out = []
    for name in sorted(batches, key=lambda n: (order.index(n) if n in order else len(order), n)):
        members = sorted(batches[name], key=lambda r: (-r["open"], -len(r["hosts"]), r["entry"]["commonName"].lower()))
        out.append(
            {
                "name": name,
                "anchor": "l-" + re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-"),
                "note": LINK_BATCHES[name][1] if name in LINK_BATCHES else (PLANT_NOTE if name == PLANT_BATCH else ""),
                "rows": members,
                "open": sum(r["open"] for r in members),
                "declined": sum(len(r["pairs"]) - r["open"] for r in members),
                "hosts": sum(len(r["hosts"]) for r in members),
            }
        )
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
button.more { margin-top: 6px; background: var(--chip); color: var(--accent); border: 0;
  border-radius: 999px; padding: 3px 11px; font: inherit; font-size: 12px; cursor: pointer; }
dialog.partners { width: min(980px, 96vw); max-height: 88vh; padding: 0; border: 1px solid var(--line);
  border-radius: 14px; background: var(--card); color: var(--fg); }
dialog.partners::backdrop { background: rgb(0 0 0 / 0.45); }
dialog.partners .bar { position: sticky; top: 0; display: flex; align-items: baseline; gap: 10px;
  padding: 14px 16px; background: var(--card); border-bottom: 1px solid var(--line); }
dialog.partners .bar h3 { margin: 0; font-size: 17px; }
dialog.partners .bar form { margin-left: auto; }
dialog.partners table { min-width: 0; }
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
    partners = []
    for p in r["partners"]:
        flag = {
            "draft": ' <span class="miss">(draft)</span>',
            "missing": ' <span class="no">(no page)</span>',
        }.get(p["state"], "")
        if p["oneWay"]:
            flag += ' <span class="no">(no link back)</span>'
        partners.append(f'<li>{esc(p["name"])} <span class="dim">· {esc(p["kind"])}</span>{flag}</li>')
    partner_cell = (
        f'<span class="dim">{len(partners)} link{"" if len(partners) == 1 else "s"}</span>'
        f'<ul class="list">{"".join(partners)}</ul>'
        if partners
        else '<span class="dim">—</span>'
    )
    tags = []
    for tag, words in r["habitats"]:
        why = (
            f' <span class="dim">← {esc(", ".join(words))}</span>'
            if words
            else ' <span class="miss">(not in its habitat prose)</span>'
        )
        tags.append(f"<li>{esc(tag)}{why}</li>")
    tag_cell = f'<ul class="list">{"".join(tags)}</ul>' if tags else '<span class="dim">—</span>'
    # Non-food uses (docs/plans/useful-plants.md): kind, harvest window, recipe count.
    uses = []
    for u in r.get("uses", []):
        count = u["recipes"]
        recipes = f" · {count} recipe{'' if count == 1 else 's'}" if count else ""
        uses.append(f'<li>{esc(u["kind"])} <span class="dim">· {months_text(u["months"])}{recipes}</span></li>')
    use_cell = f'<ul class="list">{"".join(uses)}</ul>' if uses else '<span class="dim">—</span>'
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
        f"<td>{partner_cell}</td>"
        f"<td>{tag_cell}</td>"
        f"<td>{use_cell}</td>"
        "</tr>"
    )


def render_table(rows: list[dict[str, Any]]) -> list[str]:
    out = ['<div class="scroll"><table><thead><tr>']
    for header in ["Entry", "State", "Photos", "Months", "Missing", "Lookalikes", "Grows with", "Habitats", "Other uses"]:
        out.append(f"<th>{header}</th>")
    out.append("</tr></thead><tbody>")
    out.extend(render_row(r) for r in rows)
    out.append("</tbody></table></div>")
    return out


#: Marks a lead the catalogue has since linked.
TICK = ' <span class="ok" title="linked">✓</span>'


def render_links(batches: list[dict[str, Any]]) -> list[str]:
    pairs = sum(b["open"] for b in batches)
    out = [
        f'<h2 class="group" id="links">Link next<small>{pairs} "grows with" pairs to research, '
        f"in {len(batches)} batches by kind of fungus</small></h2>",
        '<p class="lede">GloBI records of a specific partnership (root partner, host, parasite, epiphyte, '
        "pathogen) between two catalogue species, or between a fungus and a New Zealand plant the catalogue "
        "has no entry for yet. Co-occurrence ('symbiont', 'mutualist', 'commensal') records and generalist "
        "wood-rotters are left out. 'Biota NZ' counts the Biota of New Zealand records that already name "
        "the pair, a head start for the research each lead needs "
        "(<code>docs/plans/species-associations.md</code>). Generated from "
        "<code>docs/association-leads.json</code>; re-run <code>Tools/globi_symbioses.py</code> to refresh.</p>",
        "<nav>",
    ]
    for b in batches:
        out.append(f'<a href="#{b["anchor"]}">{esc(b["name"])} · {b["open"]}</a>')
    out.append("</nav>")
    for b in batches:
        out.append(f'<section class="cluster" id="{b["anchor"]}"><div class="head">')
        out.append(f"<h3>{esc(b['name'])}</h3>")
        out.append(f'<span class="genera">{esc(b["note"])}</span>')
        out.append('<div class="chips">')
        out.append(f'<span class="chip on">{b["open"]} pairs open</span>')
        if b["declined"]:
            out.append(f'<span class="chip">{b["declined"]} declined (see the plan)</span>')
        if b["hosts"]:
            out.append(f'<span class="chip">{b["hosts"]} NZ plants with no entry</span>')
        out.append("</div></div>")
        out.append('<div class="scroll"><table><thead><tr>')
        for header in ["Species", "Catalogue partners not linked", "NZ plants with no entry"]:
            out.append(f"<th>{header}</th>")
        out.append("</tr></thead><tbody>")
        for r in b["rows"]:
            e = r["entry"]
            open_pairs = [p for p in r["pairs"] if not p["declined"]]
            if not open_pairs and not r["hosts"]:
                continue
            items = []
            for p in open_pairs[:LINKS_SHOWN]:
                line = (
                    f'<a href="#e-{esc(p["entry"]["id"])}">{esc(p["entry"]["commonName"])}</a> '
                    f'<span class="dim">· {esc(", ".join(p["kinds"]))} · {p["records"]} '
                    f'record{"" if p["records"] == 1 else "s"} · {p.get("nz", 0)} NZ'
                    f'{" · Biota NZ ×" + str(p["biota"]) if p.get("biota") else ""}</span>'
                )
                items.append(f"<li>{line}</li>")
            pair_cell = capped_list(items, len(open_pairs))
            hosts = [
                f'<li>{esc(h["name"])}{TICK if h.get("linked") else ""} <span class="dim">· {h["nz"]} NZ'
                f'{" · Biota NZ ×" + str(h["biota"]) if h.get("biota") else ""}</span></li>'
                for h in r["hosts"][:LINKS_SHOWN]
            ]
            host_cell = capped_list(hosts, len(r["hosts"]))
            more = ""
            if len(open_pairs) > LINKS_SHOWN or len(r["hosts"]) > LINKS_SHOWN:
                more = (
                    f'<br><button class="more" onclick="document.getElementById(\'more-{esc(e["id"])}\').showModal()">'
                    f"More symbiosis partners</button>{partners_sheet(r, open_pairs)}"
                )
            linked = len(e.get("associations") or [])
            out.append(
                f'<tr><td><a href="#e-{esc(e["id"])}"><b>{esc(e["commonName"])}</b></a><br>'
                f'<span class="sci">{esc(e.get("scientificName", ""))}</span><br>'
                f'<span class="dim">{linked} link{"" if linked == 1 else "s"}</span>{more}</td>'
                f"<td>{pair_cell}</td><td>{host_cell}</td></tr>"
            )
        out.append("</tbody></table></div></section>")
    return out


def open_leads(batches: list[dict[str, Any]]) -> bool:
    """Whether any lead is still to research: an open pair, or a host the fungus is not linked to."""
    return any(r["open"] or any(not h["linked"] for h in r["hosts"]) for b in batches for r in b["rows"])


def render(entries: list[Entry], leads: dict[str, Any] | None = None) -> str:
    filed = file_by_group(entries)
    # With every lead linked or declined the section has nothing to say, so it is left out
    # (owner 25/11/2026: "if so you can delete the link next section").
    batches = link_batches(entries, leads) if leads else []
    show_links = open_leads(batches)
    out = [
        "<title>Catalogue report</title>",
        f"<style>{CSS}</style>",
        '<div class="wrap">',
        "<h1>Catalogue report</h1>",
        '<p class="lede">Every entry, filed by its app group and then by species group — '
        "entries sharing a genus or a lookalike card, the ones one research session fills "
        "together. "
        + ('It opens with the "grows with" links still to research, batched by kind of fungus. ' if show_links else "")
        + "A habitat tag is followed by the words in that entry's own habitat prose that "
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
    if show_links:
        out.append('<a href="#links">Link next</a>')
    for key, label in GROUPS:
        count = sum(1 for e in entries if e["group"] == key)
        out.append(f'<a href="#{key}">{esc(label)} · {count}</a>')
    out.append('<a href="#recipes">Recipes</a>')
    out.append("</nav>")

    if show_links:
        out.extend(render_links(batches))

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
    parser.add_argument("--leads", default=str(LEADS), help="GloBI leads for the Link next section")
    args = parser.parse_args()

    entries: list[Entry] = json.loads(SPECIES.read_text())
    leads_path = pathlib.Path(args.leads)
    leads = json.loads(leads_path.read_text()) if leads_path.exists() else None
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(entries, leads))
    print(f"{len(entries)} entries → {out}")


if __name__ == "__main__":
    main()
