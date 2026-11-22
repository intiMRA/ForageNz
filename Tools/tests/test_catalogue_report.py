"""The report's "no link back" flag: a missed one-way partnership would look like a finished pair."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import catalogue_report as report  # noqa: E402


def entry(id_: str, *links: tuple[str, str]) -> dict:
    return {"id": id_, "commonName": id_, "associations": [{"kind": k, "entry": e, "note": "n"} for k, e in links]}


def by_id(*entries: dict) -> dict:
    return {e["id"]: e for e in entries}


def test_a_root_partnership_on_both_pages_has_its_reverse():
    jack = entry("slippery-jack", ("mycorrhizalPartner", "monterey-pine"))
    pine = entry("monterey-pine", ("mycorrhizalPartner", "slippery-jack"))
    assert report.has_reverse(jack, jack["associations"][0], by_id(jack, pine))


def test_a_link_the_partner_does_not_carry_is_one_way():
    jack = entry("slippery-jack", ("mycorrhizalPartner", "monterey-pine"))
    pine = entry("monterey-pine")
    assert not report.has_reverse(jack, jack["associations"][0], by_id(jack, pine))


def test_a_reverse_of_the_wrong_kind_does_not_count():
    parasite = entry("peppery-bolete", ("parasiteOf", "fly-agaric"))
    wrong = entry("fly-agaric", ("parasiteOf", "peppery-bolete"))
    right = entry("fly-agaric", ("hostOf", "peppery-bolete"))
    link = parasite["associations"][0]
    assert not report.has_reverse(parasite, link, by_id(parasite, wrong))
    assert report.has_reverse(parasite, link, by_id(parasite, right))


def test_a_partner_with_no_entry_is_one_way():
    jack = entry("slippery-jack", ("mycorrhizalPartner", "no-such-tree"))
    assert not report.has_reverse(jack, jack["associations"][0], by_id(jack))


def test_the_row_flags_only_the_one_way_partner():
    oak = entry("english-oak", ("mycorrhizalPartner", "death-cap"), ("mycorrhizalPartner", "porcini"))
    cap = entry("death-cap", ("mycorrhizalPartner", "english-oak"))
    porcini = entry("porcini")
    row = report.row(oak, set(), by_id(oak, cap, porcini))
    assert [(p["name"], p["oneWay"]) for p in row["partners"]] == [("death-cap", False), ("porcini", True)]
    assert "(no link back)" in report.render_row(row)
