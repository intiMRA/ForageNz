#!/usr/bin/env python3
"""Write the one HTML report on the catalogue: every entry, grouped, with what it still owes.

Entries are filed by their app group (greens, herbs, fruit, fungi, seaweed, nuts), then by
species group inside it — the bamboos, the passionfruit, the milkcaps. A species group is a
connected component over two kinds of edge:

  * same genus — the first word of ``scientificName``;
  * a lookalike card between two entries that are both in the catalogue.

Those are the groups where one research session fills several entries at once. The report
opens with every group that still has a draft — the ones to pick up next, most drafts first —
and inside each app group the groups with drafts come before the finished ones. Entries joined
to nothing are listed last in their app group.

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
    "dock": "Docks and sheep sorrel",
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


def file_by_group(entries: list[Entry]) -> dict[str, dict[str, Any]]:
    """App group → its species groups (ranked) and its unjoined entries.

    A species group that spans app groups (hemlock is greens, wild fennel is herbs) is split,
    so each app group shows its own members; the lookalike counts still see the whole group.
    """
    by_id = {e["id"]: e for e in entries}
    filed: dict[str, dict[str, Any]] = {key: {"clusters": [], "loose": []} for key, _ in GROUPS}
    filed["next"] = {"clusters": [], "loose": []}
    for members in components(entries):
        whole = describe(members, by_id)
        if len(members) > 1 and whole["drafts"]:
            filed["next"]["clusters"].append(whole)
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
"""


def esc(text: object) -> str:
    return html.escape(str(text))


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
        "<tr>"
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
        "together. It opens with the groups that still have a draft, most drafts first. "
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
    ]
    out.append('<div class="totals">')
    for value, label in totals:
        out.append(f'<div class="total"><b>{value}</b><span>{esc(label)}</span></div>')
    out.append("</div><nav>")
    out.append('<a href="#next">Pick up next</a>')
    for key, label in GROUPS:
        count = sum(1 for e in entries if e["group"] == key)
        out.append(f'<a href="#{key}">{esc(label)} · {count}</a>')
    out.append("</nav>")

    labels = dict(GROUPS)
    picks = filed["next"]["clusters"]
    out.append(
        f'<h2 class="group" id="next">Pick up next<small>{len(picks)} species groups '
        "with a draft, most drafts first</small></h2>"
    )
    out.append('<section class="cluster"><div class="scroll"><table><thead><tr>')
    headers = ["Species group", "App group", "Drafts", "No photo", "Owe text", "Lookalike pairs"]
    for header in headers:
        out.append(f"<th>{header}</th>")
    out.append("</tr></thead><tbody>")
    for c in picks:
        drafts = ", ".join(r["commonName"] for r in c["rows"] if r["draft"])
        out.append(
            "<tr>"
            f'<td><a href="#{c["anchor"]}"><b>{esc(c["name"])}</b></a><br>'
            f'<span class="dim">{esc(drafts)}</span></td>'
            f"<td>{esc(' / '.join(labels[k] for k in c['apps']))}</td>"
            f'<td><span class="miss">{c["drafts"]}</span> of {c["size"]}</td>'
            f"<td>{c['photoless'] or '—'}</td>"
            f"<td>{c['owed'] or '—'}</td>"
            f"<td>{c['linked']}/{c['possible']}</td>"
            "</tr>"
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
