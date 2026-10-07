#!/usr/bin/env python3
"""Find clusters of very similar catalogue entries and write an HTML report.

A cluster is a connected component over two kinds of edge:

  * same genus — the first word of ``scientificName``;
  * a lookalike link between two entries that are both in the catalogue.

Those are the groups where one research session fills several entries at once
(the five bamboos, the Passiflora genus, the four Avena oats), so the report
ranks them by how much work is still outstanding inside each one.

    python3 Tools/similar_groups.py [--out docs/similar-groups.html]
"""

from __future__ import annotations

import argparse
import collections
import html
import json
import pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
SPECIES = REPO / "ForageNZ" / "Catalogue" / "species.json"

# Fields a filled-in entry is expected to carry. `photos` and `months` are
# checked separately because they are lists, not {text, sources} blocks.
PROSE_FIELDS = ["summary", "identification", "habitat", "edibleParts", "preparation"]


def prose(entry: dict, field: str) -> str:
    value = entry.get(field)
    if isinstance(value, dict):
        return (value.get("text") or "").strip()
    return value.strip() if isinstance(value, str) else ""


def clusters(entries: list[dict]) -> list[list[dict]]:
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

    genus = collections.defaultdict(list)
    for entry in entries:
        name = entry.get("scientificName") or ""
        if name.strip():
            genus[name.split()[0]].append(entry["id"])
    for members in genus.values():
        for other in members[1:]:
            union(members[0], other)

    for entry in entries:
        for lookalike in entry.get("lookalikes", []):
            target = lookalike.get("entry")
            if target in by_id:
                union(entry["id"], target)

    grouped = collections.defaultdict(list)
    for entry in entries:
        grouped[find(entry["id"])].append(entry)
    return [g for g in grouped.values() if len(g) > 1]


def describe(group: list[dict]) -> dict:
    ids = {e["id"] for e in group}
    size = len(group)

    # Directed lookalike pairs inside the group that are actually written.
    linked = sum(
        1
        for e in group
        for la in e.get("lookalikes", [])
        if la.get("entry") in ids and la.get("entry") != e["id"]
    )
    possible = size * (size - 1)

    rows = []
    for entry in sorted(group, key=lambda e: e["commonName"].lower()):
        missing = [f for f in PROSE_FIELDS if not prose(entry, f)]
        if not entry.get("months"):
            missing.append("months")
        rows.append(
            {
                "id": entry["id"],
                "commonName": entry["commonName"],
                "scientificName": entry.get("scientificName", ""),
                "draft": bool(entry.get("draft")),
                "photos": len(entry.get("photos") or []),
                "caution": entry.get("caution", ""),
                "group": entry.get("group", ""),
                "missing": missing,
                "siblingLinks": sum(
                    1
                    for la in entry.get("lookalikes", [])
                    if la.get("entry") in ids and la.get("entry") != entry["id"]
                ),
            }
        )

    genera = sorted({(e.get("scientificName") or "?").split()[0] for e in group})
    drafts = sum(1 for r in rows if r["draft"])
    photoless = sum(1 for r in rows if r["photos"] == 0)
    gaps = sum(len(r["missing"]) for r in rows)
    return {
        "title": " / ".join(genera),
        "genera": genera,
        "groups": sorted({r["group"] for r in rows}),
        "cautions": sorted({r["caution"] for r in rows}),
        "size": size,
        "drafts": drafts,
        "photoless": photoless,
        "gaps": gaps,
        "linked": linked,
        "possible": possible,
        "rows": rows,
        # Leverage: how much one shared research session could close. Weighted
        # towards clusters that are large *and* mostly empty.
        "score": gaps + photoless * 2 + (possible - linked) * 0.5 + size,
    }


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
.wrap { max-width: 1040px; margin: 0 auto; padding: 32px 20px 80px; }
h1 { font-size: 26px; margin: 0 0 6px; letter-spacing: -0.01em; }
.lede { color: var(--muted); margin: 0 0 24px; max-width: 70ch; }
.totals { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 28px; }
.total { background: var(--card); border: 1px solid var(--line); border-radius: 10px;
  padding: 10px 14px; }
.total b { display: block; font-size: 20px; }
.total span { color: var(--muted); font-size: 12px; text-transform: uppercase;
  letter-spacing: 0.06em; }
.cluster { background: var(--card); border: 1px solid var(--line); border-radius: 12px;
  margin-bottom: 18px; overflow: hidden; }
.head { display: flex; flex-wrap: wrap; align-items: baseline; gap: 10px;
  padding: 14px 16px; border-bottom: 1px solid var(--line); }
.head h2 { font-size: 17px; margin: 0; font-style: italic; }
.rank { color: var(--muted); font-variant-numeric: tabular-nums; font-size: 13px; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; margin-left: auto; }
.chip { background: var(--chip); border-radius: 999px; padding: 2px 9px; font-size: 12px;
  color: var(--muted); white-space: nowrap; }
.chip.on { color: var(--warn); }
.chip.bad { color: var(--bad); }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; min-width: 700px; }
th, td { text-align: left; padding: 8px 16px; border-bottom: 1px solid var(--line);
  vertical-align: top; font-size: 13px; }
th { color: var(--muted); font-weight: 600; font-size: 11px; text-transform: uppercase;
  letter-spacing: 0.06em; }
tbody tr:last-child td { border-bottom: 0; }
.sci { color: var(--muted); font-style: italic; }
.ok { color: var(--accent); }
.no { color: var(--bad); }
.miss { color: var(--warn); }
code { font: 12px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace; color: var(--muted); }
"""


def render(data: list[dict], total_entries: int) -> str:
    out = [
        "<title>Similar-species clusters</title>",
        f"<style>{CSS}</style>",
        '<div class="wrap">',
        "<h1>Similar-species clusters</h1>",
        '<p class="lede">Entries joined by a shared genus or by a lookalike link that '
        "points at another catalogue entry — the groups where one research session "
        "fills several pages at once. Ordered by how much is still outstanding inside "
        "each cluster.</p>",
    ]

    clustered = sum(c["size"] for c in data)
    totals = [
        (len(data), "clusters"),
        (clustered, f"of {total_entries} entries"),
        (sum(c["drafts"] for c in data), "still draft"),
        (sum(c["photoless"] for c in data), "with no photo"),
        (sum(c["possible"] - c["linked"] for c in data), "unwritten sibling pairs"),
    ]
    out.append('<div class="totals">')
    for value, label in totals:
        out.append(f'<div class="total"><b>{value}</b><span>{html.escape(label)}</span></div>')
    out.append("</div>")

    for rank, c in enumerate(data, 1):
        chips = [
            f'{c["size"]} entries',
            " · ".join(c["groups"]),
        ]
        out.append('<section class="cluster">')
        out.append('<div class="head">')
        out.append(f'<h2>{html.escape(c["title"])}</h2>')
        out.append(f'<span class="rank">#{rank}</span>')
        out.append('<div class="chips">')
        for chip in chips:
            out.append(f'<span class="chip">{html.escape(chip)}</span>')
        if c["drafts"]:
            out.append(f'<span class="chip on">{c["drafts"]} draft</span>')
        if c["photoless"]:
            out.append(f'<span class="chip bad">{c["photoless"]} no photo</span>')
        out.append(
            f'<span class="chip">lookalike pairs {c["linked"]}/{c["possible"]}</span>'
        )
        if "doNotEat" in c["cautions"]:
            out.append('<span class="chip bad">do not eat</span>')
        if "psychoactive" in c["cautions"]:
            out.append('<span class="chip on">psychoactive</span>')
        out.append("</div></div>")

        out.append('<div class="scroll"><table><thead><tr>')
        for header in ["Entry", "State", "Photos", "Sibling links", "Missing"]:
            out.append(f"<th>{header}</th>")
        out.append("</tr></thead><tbody>")
        for r in c["rows"]:
            state = (
                '<span class="miss">draft</span>'
                if r["draft"]
                else '<span class="ok">shipped</span>'
            )
            photos = (
                f'<span class="ok">{r["photos"]}</span>'
                if r["photos"]
                else '<span class="no">0</span>'
            )
            missing = (
                f'<span class="miss">{html.escape(", ".join(r["missing"]))}</span>'
                if r["missing"]
                else '<span class="ok">complete</span>'
            )
            out.append(
                "<tr>"
                f'<td><b>{html.escape(r["commonName"])}</b><br>'
                f'<span class="sci">{html.escape(r["scientificName"])}</span><br>'
                f'<code>{html.escape(r["id"])}</code></td>'
                f"<td>{state}</td>"
                f"<td>{photos}</td>"
                f'<td>{r["siblingLinks"]}/{c["size"] - 1}</td>'
                f"<td>{missing}</td>"
                "</tr>"
            )
        out.append("</tbody></table></div></section>")

    out.append("</div>")
    return "\n".join(out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(REPO / "docs" / "similar-groups.html"))
    args = parser.parse_args()

    entries = json.loads(SPECIES.read_text())
    data = sorted(
        (describe(g) for g in clusters(entries)),
        key=lambda c: (-c["score"], -c["size"], c["title"]),
    )

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(data, len(entries)))
    print(f"{len(data)} clusters covering {sum(c['size'] for c in data)} entries → {out}")


if __name__ == "__main__":
    main()
