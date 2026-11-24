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


def species(id_: str, name: str, group: str, *links: str) -> dict:
    return {
        "id": id_, "commonName": id_, "scientificName": name, "group": group,
        "associations": [{"kind": "mycorrhizalPartner", "entry": e, "note": "n"} for e in links],
    }


def lead(a: str, b: str) -> dict:
    return {"a": a, "b": b, "kinds": {a: ["lives on"], b: ["host of"]}, "records": {a: 1, b: 2}}


def test_link_batches_file_each_open_pair_under_its_fungus_and_mark_declined_ones():
    entries = [
        species("porcini", "Boletus edulis", "fungi"),
        species("sweet-chestnut", "Castanea sativa", "nuts"),
        species("silver-birch", "Betula pendula", "greens"),
        species("turkey-tail", "Trametes versicolor", "fungi", "english-oak"),
        species("english-oak", "Quercus robur", "greens", "turkey-tail"),
        species("matai", "Prumnopitys taxifolia", "greens"),
        species("hounds-tongue-fern", "Zealandia pustulata", "greens"),
    ]
    leads = {
        "pairs": [
            lead("porcini", "sweet-chestnut"),
            lead("porcini", "silver-birch"),
            lead("english-oak", "turkey-tail"),  # linked since: left out
            lead("hounds-tongue-fern", "matai"),
            lead("gone", "porcini"),  # entry removed: left out
        ],
        "hosts": {"porcini": [{"name": "Betula utilis", "kinds": ["lives on"], "nz": 3, "records": 1}]},
    }
    batches = report.link_batches(entries, leads)
    assert [b["name"] for b in batches] == ["Boletes and suillus", "Plants on plants"]
    boletes, plants = batches
    [porcini] = boletes["rows"]
    assert [(p["entry"]["id"], p["kinds"], p["declined"]) for p in porcini["pairs"]] == [
        ("silver-birch", ["lives on"], None),
        ("sweet-chestnut", ["lives on"], "no NZ record for chestnut"),
    ]
    assert (boletes["open"], boletes["declined"], boletes["hosts"]) == (1, 1, 1)
    assert [p["entry"]["id"] for r in plants["rows"] for p in r["pairs"]] == ["matai"]


def test_a_host_under_an_old_name_becomes_a_pair_with_its_entry_unless_already_linked():
    entries = [
        species("umere-milkcap", "Lactarius umerensis", "fungi", "red-beech"),
        species("red-beech", "Fuscospora fusca", "greens", "umere-milkcap"),
        species("silver-beech", "Lophozonia menziesii", "greens"),
    ]
    hosts = [
        {"name": "Nothofagus fusca", "kinds": ["lives on"], "nz": 9, "records": 2},  # linked: left out
        {"name": "Nothofagus menziesii", "kinds": ["lives on"], "nz": 9, "records": 7},
        {"name": "Betula utilis", "kinds": ["lives on"], "nz": 3, "records": 1},
    ]
    [batch] = report.link_batches(entries, {"pairs": [], "hosts": {"umere-milkcap": hosts}})
    [row] = batch["rows"]
    assert [(p["entry"]["id"], p["records"]) for p in row["pairs"]] == [("silver-beech", 7)]
    assert [h["name"] for h in row["hosts"]] == ["Betula utilis"]


def test_a_host_the_catalogue_has_since_linked_keeps_its_place_with_a_tick():
    entries = [
        species("slippery-jack", "Suillus luteus", "fungi", "contorta-pine"),
        species("contorta-pine", "Pinus contorta", "greens", "slippery-jack"),
    ]
    hosts = [
        {"name": "Pinus contorta", "kinds": ["lives on"], "nz": 1074, "records": 3},
        {"name": "Pinus muricata", "kinds": ["lives on"], "nz": 202, "records": 2},
    ]
    [batch] = report.link_batches(entries, {"pairs": [], "hosts": {"slippery-jack": hosts}})
    [row] = batch["rows"]
    assert [(h["name"], h["linked"]) for h in row["hosts"]] == [("Pinus contorta", True), ("Pinus muricata", False)]
    page = "".join(report.render_links([batch]))
    assert "Pinus contorta" + report.TICK in page
    assert "Pinus muricata" + report.TICK not in page


def test_a_host_with_no_wild_new_zealand_presence_is_dropped_from_the_leads():
    entries = [species("slippery-jack", "Suillus luteus", "fungi")]
    hosts = [
        {"name": "Pinus densiflora", "kinds": ["root partner"], "nz": 44, "records": 1},
        {"name": "Pinus thunbergii", "kinds": ["root partner"], "nz": 35, "records": 1},
        {"name": "Pinus ayacahuite", "kinds": ["root partner"], "nz": 20, "records": 1},
        {"name": "Pinus hartwegii", "kinds": ["root partner"], "nz": 17, "records": 1},
        {"name": "Pinus edulis", "kinds": ["root partner"], "nz": 15, "records": 1},
        {"name": "Pinus lambertiana", "kinds": ["lives on"], "nz": 15, "records": 1},
        {"name": "Pinus tabuliformis", "kinds": ["root partner"], "nz": 14, "records": 1},
        {"name": "Pinus jeffreyi", "kinds": ["root partner"], "nz": 13, "records": 1},
        {"name": "Pinus kesiya", "kinds": ["root partner"], "nz": 12, "records": 1},
        {"name": "Pinus resinosa", "kinds": ["lives on"], "nz": 12, "records": 2},
        {"name": "Pinus koraiensis", "kinds": ["root partner"], "nz": 10, "records": 1},
        {"name": "Tsuga canadensis", "kinds": ["lives on"], "nz": 9, "records": 1},
        {"name": "Pinus pumila", "kinds": ["root partner"], "nz": 1, "records": 1},
        {"name": "Tilia cordata", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Carpinus betulus", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Agrostis canina", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Populus tremuloides", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Lophozonia cunninghamii", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Corymbia ficifolia", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Metrosideros collina", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Betula papyrifera", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Acer saccharum", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Abies lasiocarpa", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Betula alleghaniensis", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Alnus rhombifolia", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Betula ermanii", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Betula lenta", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Betula nana", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Quercus mongolica", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Quercus petraea", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Quercus agrifolia", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Abies sachalinensis", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Abies amabilis", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Picea glauca", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Picea pungens", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Picea engelmannii", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Carya ovata", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Carya laciniosa", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Pinus clausa", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Pinus massoniana", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Castanea dentata", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Tilia tomentosa", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Larix gmelinii", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Larix laricina", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Acer sterculiaceum subsp. franchetii", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Callitropsis nootkatensis", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Populus cathayana", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Fagus grandifolia", "kinds": ["root partner"], "nz": 5, "records": 1},
        {"name": "Pinus banksiana", "kinds": ["root partner"], "nz": 30, "records": 1},
    ]
    [batch] = report.link_batches(entries, {"pairs": [], "hosts": {"slippery-jack": hosts}})
    [row] = batch["rows"]
    assert [h["name"] for h in row["hosts"]] == ["Pinus banksiana"]
    page = "".join(report.render_links([batch]))
    assert "Pinus densiflora" not in page
    assert "Pinus thunbergii" not in page
    assert "Pinus ayacahuite" not in page
    assert "Pinus hartwegii" not in page
    assert "Pinus edulis" not in page
    assert "Pinus lambertiana" not in page
    assert "Pinus tabuliformis" not in page
    assert "Pinus jeffreyi" not in page
    assert "Pinus kesiya" not in page
    assert "Pinus resinosa" not in page
    assert "Pinus koraiensis" not in page
    assert "Tsuga canadensis" not in page
    assert "Pinus pumila" not in page
    for name in [
        "Tilia cordata",
        "Carpinus betulus",
        "Agrostis canina",
        "Populus tremuloides",
        "Lophozonia cunninghamii",
        "Corymbia ficifolia",
        "Metrosideros collina",
        "Betula papyrifera",
        "Acer saccharum",
        "Abies lasiocarpa",
        "Betula alleghaniensis",
        "Alnus rhombifolia",
        "Betula ermanii",
        "Betula lenta",
        "Betula nana",
        "Quercus mongolica",
        "Quercus petraea",
        "Quercus agrifolia",
        "Abies sachalinensis",
        "Abies amabilis",
        "Picea glauca",
        "Picea pungens",
        "Picea engelmannii",
        "Carya ovata",
        "Carya laciniosa",
        "Pinus clausa",
        "Pinus massoniana",
        "Castanea dentata",
        "Tilia tomentosa",
        "Larix gmelinii",
        "Larix laricina",
        "Acer sterculiaceum subsp. franchetii",
        "Callitropsis nootkatensis",
        "Populus cathayana",
        "Fagus grandifolia",
    ]:
        assert name not in page


def test_a_declined_host_lead_is_dropped_for_that_fungus_only():
    entries = [species("shaggy-inkcap", "Coprinus comatus", "fungi"), species("fly-agaric", "Amanita muscaria", "fungi")]
    stinkwort = {"name": "Dittrichia graveolens", "kinds": ["root partner"], "nz": 96, "records": 1}
    leads = {"pairs": [], "hosts": {"shaggy-inkcap": [stinkwort], "fly-agaric": [stinkwort]}}
    rows = {r["entry"]["id"]: r for b in report.link_batches(entries, leads) for r in b["rows"]}
    assert rows["shaggy-inkcap"]["hosts"] == []
    assert [h["name"] for h in rows["fly-agaric"]["hosts"]] == ["Dittrichia graveolens"]


def test_a_host_whose_entry_the_plan_declined_for_that_fungus_is_dropped():
    entries = [
        species("shaggy-parasol", "Chlorophyllum rhacodes", "fungi"),
        species("bluefoot-bolete", "Xerocomellus cisalpinus", "fungi"),
        species("norway-spruce", "Picea abies", "conifers"),
    ]
    spruce = {"name": "Picea abies", "kinds": ["lives on"], "nz": 37, "records": 1}
    leads = {"pairs": [], "hosts": {"shaggy-parasol": [spruce], "bluefoot-bolete": [spruce]}}
    rows = {r["entry"]["id"]: r for b in report.link_batches(entries, leads) for r in b["rows"]}
    assert rows["shaggy-parasol"]["hosts"] == []
    assert [h["name"] for h in rows["bluefoot-bolete"]["hosts"]] == ["Picea abies"]


def test_the_partners_sheet_lists_every_partner_commonest_first_with_an_inaturalist_link():
    oak = dict(species("english-oak", "Quercus robur", "greens"), moreImagesURL="https://www.inaturalist.org/taxa/56133")
    row = {
        "entry": species("turkey-tail", "Trametes versicolor", "fungi"),
        "hosts": [{"name": "Weinmannia racemosa", "kinds": ["lives on"], "nz": 40, "records": 1}],
    }
    pairs = [{"entry": oak, "kinds": ["lives on"], "records": 3, "nz": 9, "declined": None}]
    sheet = report.partners_sheet(row, pairs)
    assert sheet.index("Weinmannia racemosa") < sheet.index("Quercus robur")
    assert "https://www.inaturalist.org/taxa/56133" in sheet
    assert "https://www.inaturalist.org/taxa/search?q=Weinmannia+racemosa" in sheet


def test_a_globi_host_with_a_rank_word_matches_the_inaturalist_style_name():
    # GloBI writes "Pinus nigra subsp. laricio"; the catalogue writes names as iNaturalist does.
    entries = [
        species("slippery-jack", "Suillus luteus", "fungi", "corsican-pine"),
        species("corsican-pine", "Pinus nigra laricio", "greens", "slippery-jack"),
    ]
    hosts = [{"name": "Pinus nigra subsp. laricio", "kinds": ["lives on"], "nz": 467, "records": 2}]
    [batch] = report.link_batches(entries, {"pairs": [], "hosts": {"slippery-jack": hosts}})
    [row] = batch["rows"]
    assert [(h["name"], h["linked"]) for h in row["hosts"]] == [("Pinus nigra subsp. laricio", True)]


def test_the_link_next_section_is_left_out_once_every_lead_is_linked():
    jack = species("slippery-jack", "Suillus luteus", "fungi")
    pine = species("monterey-pine", "Pinus radiata", "trees")
    leads = {"pairs": [lead("slippery-jack", "monterey-pine")], "hosts": {}}
    assert report.open_leads(report.link_batches([jack, pine], leads))
    jack["associations"] = [{"kind": "mycorrhizalPartner", "entry": "monterey-pine", "note": "n"}]
    pine["associations"] = [{"kind": "mycorrhizalPartner", "entry": "slippery-jack", "note": "n"}]
    assert not report.open_leads(report.link_batches([jack, pine], leads))
