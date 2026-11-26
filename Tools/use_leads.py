#!/usr/bin/env python3
"""Read the non-food use leads out of docs/plans/useful-plants.md.

The plan's four lead tables (*Candidates noted while filling food entries*, the Jenny Dean and
One Hundred Dollars dye cross-references, and *Recipe leads*) are where every use still to be
written is recorded. This turns them into one list per catalogue entry, each lead tagged with the
use kinds in scope (owner, 26/11/2026: fibre, dye, craft, cosmetics) that its text names, so the
report can file them into batches and the drafting script knows which entries will get a use.

The kinds come from words in the lead, so they are a sorting aid, not a claim: a lead is re-read
at its source before anything reaches a page.

    python3 Tools/use_leads.py            # summary
    python3 Tools/use_leads.py --ids      # entry ids that will get a use, one per line
    python3 Tools/use_leads.py --draft    # set plannedUses and draft on each of them

`--draft` follows the owner's order of 26/11/2026: every entry that will get a use is a draft
until the owner has reviewed it. It only adds: kinds already planned stay planned, and a draft
flag is never cleared here — only the owner clears it.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parent.parent
PLAN = REPO / "docs" / "plans" / "useful-plants.md"

#: The plan's lead tables, by heading prefix, with the column holding the use text and the column
#: holding where it was seen (None when the table has no such column).
TABLES: dict[str, tuple[str, int, int | None]] = {
    "## Candidates noted while filling food entries": ("Candidates", 1, 2),
    "## Jenny Dean's Wild Colour cross-reference": ("Wild Colour", 1, 2),
    "## One Hundred Dollars a Month dye-plant list cross-reference": ("One Hundred Dollars", 1, 2),
    "## Recipe leads": ("Recipe leads", 1, 3),
}

#: Words that put a lead under a use kind. Word starts, case-insensitive. Medicinal words are not
#: here on purpose: medicinal use is out of scope, so a lead naming only that gets no kind.
KIND_WORDS: dict[str, tuple[str, ...]] = {
    "fibre": ("fibre", "fiber", "weav", "basket", "cordage", "rope", "string", "twine", "thatch",
              "mat ", "mats", "paper", "cloth", "net ", "nets", "raranga", "plait", "brooms", "besom"),
    "dye": ("dye", "dyes", "stain", "ink", "mordant", "colour for wool"),
    "craft": ("tinder", "kindling", "soap plant", "saponin", "lather", "scent", "perfum", "pomade",
              "enfleurage", "polish", "candle", "wax", "brush", "glue", "tannin", "tanning", "insect repell",
              "pot-scourer", "scour", "bag", "vessel", "wrapping", "packing", "size canoes", "flute"),
    "cosmetics": ("salve", "balm", "lotion", "lip balm", "soap", "bath", "cream", "skin", "hair rinse",
                  "infused oil", "oil infus", "toner", "cosmetic", "ointment"),
}
KIND_ORDER = ["fibre", "dye", "craft", "cosmetics"]

ID_PATTERN = re.compile(r"`([a-z0-9-]+)`")


def kinds_in(text: str) -> list[str]:
    lowered = " " + text.lower() + " "
    found = []
    for kind in KIND_ORDER:
        for word in KIND_WORDS[kind]:
            if re.search(r"(?<![a-z])" + re.escape(word), lowered):
                found.append(kind)
                break
    return found


def split_row(line: str) -> list[str]:
    """Cells of a markdown table row; pipes inside backticks or links are not expected here."""
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def parse(plan_text: str) -> dict[str, list[dict[str, Any]]]:
    """Entry id → its leads, in plan order."""
    leads: dict[str, list[dict[str, Any]]] = {}
    current: tuple[str, int, int | None] | None = None
    for line in plan_text.splitlines():
        if line.startswith("## "):
            current = next((spec for head, spec in TABLES.items() if line.startswith(head)), None)
            continue
        if current is None or not line.startswith("|") or line.startswith("|---"):
            continue
        cells = split_row(line)
        if not ID_PATTERN.search(cells[0]):
            continue  # header row
        table, use_col, where_col = current
        text = cells[use_col] if use_col < len(cells) else ""
        where = cells[where_col] if where_col is not None and where_col < len(cells) else ""
        # The recipe table names its kind in its own column; read it with the recipe text.
        kind_text = text + (" " + cells[2] if table == "Recipe leads" and len(cells) > 2 else "")
        if table in ("Wild Colour", "One Hundred Dollars"):
            kind_text += " dye"
        lead = {
            "table": table,
            "species": cells[0],
            "text": text,
            "where": where,
            "kinds": kinds_in(kind_text),
            "done": "on the page" in cells[0],
        }
        for entry_id in dict.fromkeys(ID_PATTERN.findall(cells[0])):
            leads.setdefault(entry_id, []).append(lead)
    return leads


def planned_kinds(entry_leads: list[dict[str, Any]]) -> list[str]:
    found = {kind for lead in entry_leads for kind in lead["kinds"]}
    return [kind for kind in KIND_ORDER if kind in found]


def will_get_a_use(leads: dict[str, list[dict[str, Any]]], catalogue_ids: set[str]) -> list[str]:
    """Catalogue entries with at least one in-scope lead, in plan order."""
    return [i for i, ls in leads.items() if i in catalogue_ids and planned_kinds(ls)]


#: Sources lines that record a finished use review. An entry the owner has reviewed and shipped
#: keeps its uses as decided: a new lead on it goes to the owner, not back into a draft (the
#: 27/11/2026 run re-drafted the shipped pines, docks, mallows, oaks and cabbage trees).
REVIEW_LINES = ("Other uses reviewed", "Other uses, owner link round")


def use_review_settled(entry: dict[str, Any]) -> bool:
    return not entry.get("draft") and any(line.startswith(REVIEW_LINES) for line in entry.get("sources", []))


def mark_planned(catalogue: list[dict[str, Any]], leads: dict[str, list[dict[str, Any]]]) -> list[str]:
    """Add each entry's planned kinds and draft it. Returns the ids that changed."""
    changed = []
    for entry in catalogue:
        kinds = planned_kinds(leads.get(entry["id"], []))
        if not kinds or use_review_settled(entry):
            continue
        merged = [k for k in KIND_ORDER if k in kinds or k in (entry.get("plannedUses") or [])]
        if merged != (entry.get("plannedUses") or []) or not entry.get("draft"):
            entry["plannedUses"] = merged
            entry["draft"] = True
            changed.append(entry["id"])
    return changed


def main() -> None:
    import json
    import sys

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ids", action="store_true")
    parser.add_argument("--draft", action="store_true")
    args = parser.parse_args()
    leads = parse(PLAN.read_text())
    catalogue = json.loads((REPO / "ForageNZ" / "Catalogue" / "species.json").read_text())
    ids = {e["id"] for e in catalogue}
    chosen = will_get_a_use(leads, ids)
    if args.draft:
        sys.path.insert(0, str(REPO / "Tools"))
        from sources import write_catalogue

        changed = mark_planned(catalogue, leads)
        write_catalogue(catalogue)
        print(f"{len(changed)} entries drafted or given planned uses")
        return
    if args.ids:
        print("\n".join(chosen))
        return
    missing = [i for i in leads if i not in ids]
    print(f"{len(leads)} entries named in the plan's lead tables; {len(chosen)} in the catalogue with an in-scope use")
    if missing:
        print("not in the catalogue:", ", ".join(missing))
    out_of_scope = [i for i in leads if i in ids and i not in chosen]
    if out_of_scope:
        print("only out-of-scope leads:", ", ".join(out_of_scope))


if __name__ == "__main__":
    main()
