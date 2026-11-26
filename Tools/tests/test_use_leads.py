from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import catalogue_report as report  # noqa: E402
import use_leads  # noqa: E402

PLAN = """\
## Candidates noted while filling food entries

| Species (entry id) | Use | Where it was seen |
|---|---|---|
| Hedge woundwort (`hedge-woundwort`) | Tough stem fibre; yellow dye from the plant | PFAF |
| Narrow-leaved plantain (`plantain`), greater plantain (`greater-plantain`) | Leaf-infused oil for salves | Nerdy Farm Wife |
| Hawthorn (`hawthorn`) | Hedging; hard wood for tools | PFAF |

## Recipe leads

| Species (entry id) | Recipe | Kind | Source | Safety points the source states |
|---|---|---|---|---|
| Scotch broom (`scotch-broom`) — **on the page 26/11/2026 (pilot)** | Acid-yellow wool | Dye | Snapdragon Life | None stated |

## Not a lead table

| Species (entry id) | Use | Where |
|---|---|---|
| Gorse (`gorse`) | Dye | nowhere |
"""


def test_each_row_files_under_every_id_it_names_with_the_kinds_its_words_name():
    leads = use_leads.parse(PLAN)
    assert use_leads.planned_kinds(leads["hedge-woundwort"]) == ["fibre", "dye"]
    assert use_leads.planned_kinds(leads["plantain"]) == ["cosmetics"]
    assert use_leads.planned_kinds(leads["greater-plantain"]) == ["cosmetics"]
    assert "gorse" not in leads


def test_a_lead_with_only_out_of_scope_uses_plans_nothing():
    leads = use_leads.parse(PLAN)
    assert use_leads.planned_kinds(leads["hawthorn"]) == []
    assert use_leads.will_get_a_use(leads, {"hawthorn", "plantain"}) == ["plantain"]


def test_a_lead_already_on_a_page_is_marked_done():
    leads = use_leads.parse(PLAN)
    assert leads["scotch-broom"][0]["done"]
    assert use_leads.planned_kinds(leads["scotch-broom"]) == ["dye"]


def test_marking_drafts_and_adds_kinds_but_never_clears_any():
    leads = use_leads.parse(PLAN)
    catalogue = [
        {"id": "hedge-woundwort", "draft": False, "plannedUses": ["craft"]},
        {"id": "hawthorn", "draft": False, "plannedUses": []},
    ]
    assert use_leads.mark_planned(catalogue, leads) == ["hedge-woundwort"]
    assert catalogue[0] == {"id": "hedge-woundwort", "draft": True, "plannedUses": ["fibre", "dye", "craft"]}
    assert catalogue[1]["draft"] is False
    assert use_leads.mark_planned(catalogue, leads) == []


def test_the_report_batches_waiting_drafts_by_group_and_splits_them_by_genus_or_use():
    leads = use_leads.parse(PLAN)
    entries = [
        {"id": "hedge-woundwort", "commonName": "Hedge woundwort", "scientificName": "Stachys sylvatica",
         "group": "greens", "draft": True, "plannedUses": ["fibre", "dye"]},
        {"id": "curled-dock", "commonName": "Curled dock", "scientificName": "Rumex crispus",
         "group": "greens", "draft": True, "plannedUses": ["dye"]},
        {"id": "broad-leaved-dock", "commonName": "Broad-leaved dock", "scientificName": "Rumex obtusifolius",
         "group": "greens", "draft": True, "plannedUses": ["dye"], "uses": [{"kind": "dye"}]},
        {"id": "comfrey", "commonName": "Comfrey", "scientificName": "Symphytum officinale",
         "group": "greens", "draft": True, "plannedUses": ["craft", "cosmetics"]},
        {"id": "hawthorn", "commonName": "Hawthorn", "group": "fruit", "draft": False},
        {"id": "scotch-broom", "commonName": "Scotch broom", "scientificName": "Cytisus scoparius",
         "group": "greens", "draft": False, "plannedUses": ["dye"], "uses": [{"kind": "dye"}]},
    ]
    batches = report.use_batches(entries, leads)
    assert [b["key"] for b in batches] == ["greens"]
    assert "scotch-broom" not in [r["entry"]["id"] for r in batches[0]["rows"]]
    assert batches[0]["written"] == 1
    subs = [(s["label"], [r["entry"]["id"] for r in s["rows"]]) for s in batches[0]["subs"]]
    assert subs == [
        ("Rumex", ["broad-leaved-dock", "curled-dock"]),
        ("Fibre uses", ["hedge-woundwort"]),
        ("Cosmetic uses", ["comfrey"]),
    ]
    html = "\n".join(report.render_uses(batches))
    assert "Tough stem fibre" in html and "Rumex" in html and "Scotch broom" not in html
