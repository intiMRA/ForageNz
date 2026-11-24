"""The symbiosis filter and the catalogue matching behind docs/globi-symbioses.html."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import globi_symbioses as globi  # noqa: E402

COLUMNS = ["source_taxon_name", "interaction_type", "target_taxon_name"]


def payload(*records: tuple[str, str]) -> dict:
    return {"columns": COLUMNS, "data": [["Boletus edulis", kind, partner] for kind, partner in records]}


def entry(id_: str, name: str, *linked: str) -> dict:
    return {"id": id_, "scientificName": name, "associations": [{"kind": "mycorrhizalPartner", "entry": e} for e in linked]}


def test_query_names_drop_aggregates_subspecies_and_second_names():
    assert globi.query_names("Rubus fruticosus agg.") == ["Rubus fruticosus"]
    assert globi.query_names("Convolvulus sepium subsp. roseata") == ["Convolvulus sepium"]
    assert globi.query_names("Tetragonia implexicoma / T. trigyna") == ["Tetragonia implexicoma"]


def test_hybrids_are_asked_for_with_and_without_the_sign_however_it_is_written():
    assert globi.query_names("Mentha ×piperita") == ["Mentha x piperita", "Mentha piperita"]
    assert globi.query_names("Viola × wittrockiana") == ["Viola x wittrockiana", "Viola wittrockiana"]


def test_names_match_whatever_hybrid_sign_each_side_uses():
    assert globi.name_key("Mentha x piperita") == globi.name_key("Mentha ×piperita") == "mentha piperita"
    assert globi.name_key("Betula pendula subsp. pendula") == "betula pendula"


def test_every_page_is_fetched(monkeypatch, tmp_path):
    pages = {0: [["a", "hasHost", "b"]] * 3, 3: [["a", "hasHost", "c"]]}
    calls = []

    def fake_get_json(url, params):
        calls.append(params["offset"])
        return {"columns": COLUMNS, "data": pages[params["offset"]]}

    monkeypatch.setattr(globi, "LIMIT", 3)
    monkeypatch.setattr(globi, "COURTESY_DELAY", 0)
    monkeypatch.setattr(globi, "get_json", fake_get_json)
    payload = globi.fetch("Quercus robur", tmp_path, refresh=False)
    assert calls == [0, 3]
    assert len(payload["data"]) == 4
    # A second call is served from the cache.
    assert globi.fetch("Quercus robur", tmp_path, refresh=False) == payload and calls == [0, 3]


def test_the_richer_of_a_hybrid_s_two_names_is_used(monkeypatch, tmp_path):
    sizes = {"Prunus x domestica": 1, "Prunus domestica": 5}
    monkeypatch.setattr(globi, "fetch", lambda name, cache, refresh: {"columns": COLUMNS, "data": [[]] * sizes[name]})
    name, payload = globi.fetch_species("Prunus ×domestica", tmp_path, refresh=False)
    assert name == "Prunus domestica" and len(payload["data"]) == 5


def test_only_symbiotic_kinds_are_kept():
    rows = globi.symbiotic_rows(payload(
        ("hasEctomycorrhizalHost", "Pinus radiata"),
        ("hasHost", "Quercus robur"),
        ("eatenBy", "Homo sapiens"),
        ("interactsWith", "Tricholoma caligatum"),
        ("visitedBy", "Apis mellifera"),
        ("symbiontOf", "Calluna vulgaris"),
        ("mutualistOf", "Erica cinerea"),
    ))
    assert rows == [("hasEctomycorrhizalHost", "Pinus radiata"), ("hasHost", "Quercus robur")]


def test_a_response_without_the_expected_columns_gives_nothing():
    assert globi.symbiotic_rows({"columns": ["source_taxon_name"], "data": [["x"]]}) == []


def test_partners_merge_kinds_and_spellings_match_the_catalogue_and_drop_higher_ranks():
    porcini = entry("porcini", "Boletus edulis", "english-oak")
    names = globi.catalogue_names([
        porcini,
        entry("english-oak", "Quercus robur"),
        entry("silver-birch", "Betula pendula"),
    ])
    partners = globi.partners_of(porcini, payload(
        ("hasHost", "Quercus robur"),
        ("hasHost", "Quercus robur"),
        ("hasEctomycorrhizalHost", "Quercus robur"),
        ("hasHost", "Betula pendula subsp. pendula"),
        ("hasHost", "Betula pendula"),
        ("hasHost", "Picea abies"),
        ("hasHost", "Pinus"),
        ("hasHost", "Pinus sp."),
        ("hasHost", "under Colorado Blue Spuce"),
        ("symbiontOf", "Boletus edulis"),
    ), names)
    summary = [(p.name, p.kinds, p.partner_id, p.linked) for p in partners]
    # Catalogue species first, most-recorded first; no genus-only names; never itself.
    assert summary == [
        ("Quercus robur", {"hasHost": 2, "hasEctomycorrhizalHost": 1}, "english-oak", True),
        ("Betula pendula subsp. pendula", {"hasHost": 2}, "silver-birch", False),
        ("Picea abies", {"hasHost": 1}, None, False),
    ]


def test_a_gbif_match_counts_only_when_it_reaches_species(monkeypatch):
    answers = {
        "Quercus robur": {"rank": "SPECIES", "speciesKey": 2878688},
        "Betula pendula subsp. pendula": {"rank": "SUBSPECIES", "speciesKey": 5331916},
        "Quercus robustus": {"rank": "GENUS", "genusKey": 2877951},
        "Nonsense name": {"matchType": "NONE"},
    }
    calls = []

    def fake_get_json(url, params):
        calls.append(params["name"])
        assert params["strict"] == "true"
        return answers[params["name"]]

    monkeypatch.setattr(globi, "get_json", fake_get_json)
    cache: dict = {}
    assert globi.gbif_species_key("Quercus robur", cache) == 2878688
    assert globi.gbif_species_key("Betula pendula subsp. pendula", cache) == 5331916
    assert globi.gbif_species_key("Quercus robustus", cache) is None
    assert globi.gbif_species_key("Nonsense name", cache) is None
    assert globi.gbif_species_key("Quercus robur", cache) == 2878688
    assert calls.count("Quercus robur") == 1


def test_new_zealand_counts_come_from_the_species_facet(monkeypatch):
    monkeypatch.setattr(globi, "get_json", lambda url, params: {
        "facets": [{"field": "SPECIES_KEY", "counts": [{"name": "2878688", "count": 586}]}]
    })
    assert globi.nz_species_counts() == {2878688: 586}


def test_the_page_lists_partners_per_species_and_names_unreached_species():
    porcini = {"id": "porcini", "commonName": "Porcini", "scientificName": "Boletus edulis", "group": "fungi"}
    partners = [
        globi.Partner("Betula pendula", {"hasHost": 3}, "silver-birch", False, nz_records=449),
        globi.Partner("Quercus robur", {"hasHost": 2, "hasEctomycorrhizalHost": 1}, "english-oak", True, nz_records=586),
        globi.Partner("Picea abies", {"hasHost": 1}, None, False, nz_records=12),
    ]
    page = globi.render(
        [globi.SpeciesRow(porcini, "Boletus edulis", partners)],
        {"silver-birch": "Silver birch", "english-oak": "English oak"},
        ["kawakawa"], ["gingidia-grisea"], 3, 1,
    )
    assert page.count("<tr><td>") == 1
    assert "<b>Silver birch</b></a>: lives on</li>" in page
    assert "<b>English oak</b></a>: lives on, root partner (it is the fungus)" in page and "✓ linked" in page
    assert "<i>Picea abies</i>" in page
    assert "targetTaxon=Betula+pendula" in page
    assert "Not reached for 1: kawakawa" in page
    assert "No GloBI records at all for 1 species" in page and "gingidia-grisea" in page


def test_useful_entries_are_edible_ones_and_do_not_eat_ones_with_a_recorded_use():
    entries = [
        {"id": "porcini", "caution": "careRequired"},
        {"id": "death-cap", "caution": "doNotEat"},
        {"id": "beach-spinach", "caution": "doNotEat"},
    ]
    uses = "| Kōkihi / beach spinach (`beach-spinach`) | Red berries used as a dye |"
    assert globi.useful_ids(entries, uses) == {"porcini", "beach-spinach"}


def test_only_partners_that_help_find_a_useful_species_are_kept():
    useful = {"porcini", "english-oak", "matai", "hounds-tongue-fern", "celery", "scotch-broom"}
    groups = {
        "porcini": "fungi", "death-cap": "fungi", "english-oak": "nuts", "matai": "fruit",
        "hounds-tongue-fern": "greens", "celery": "greens", "scotch-broom": "greens",
    }
    porcini = {"id": "porcini", "group": "fungi"}
    oak = {"id": "english-oak", "group": "nuts"}

    def partner(kinds, partner_id=None):
        return globi.Partner("Name name", dict.fromkeys(kinds, 1), partner_id, False)

    def keep(entry, kinds, partner_id=None, kingdom=None):
        return globi.findable(entry, partner(kinds, partner_id), useful, groups, kingdom)

    # A fungus: the plants it grows under or on, never animals or plants listed as living on it.
    assert keep(porcini, ["hasEctomycorrhizalHost"], kingdom="Plantae")
    assert keep(porcini, ["parasiteOf", "hostOf"], kingdom="Plantae")
    assert not keep(porcini, ["hasHost"], kingdom="Animalia")
    assert not keep(porcini, ["hostOf"], kingdom="Plantae")
    assert not keep(porcini, ["hasHost"], kingdom=None)
    # A plant: useful catalogue species only, never other GloBI partners or do-not-eat ones.
    assert keep(oak, ["ectomycorrhizalHostOf"], "porcini")
    assert not keep(oak, ["ectomycorrhizalHostOf"], "death-cap")
    assert not keep(oak, ["hasPathogen"], kingdom="Plantae")
    # Two plants: kept when one lives on the other, dropped when the only record is a disease.
    assert keep({"id": "hounds-tongue-fern", "group": "greens"}, ["hasHost"], "matai")
    assert not keep({"id": "scotch-broom", "group": "greens"}, ["pathogenOf"], "celery")


def test_a_kingdom_is_asked_for_once_per_species_key(monkeypatch):
    calls = []

    def fake_get_json(url, params):
        calls.append(url)
        return {"kingdom": "Plantae"}

    monkeypatch.setattr(globi, "get_json", fake_get_json)
    cache: dict = {}
    assert globi.gbif_kingdom(2878688, cache) == "Plantae"
    assert globi.gbif_kingdom(2878688, cache) == "Plantae"
    assert calls == ["https://api.gbif.org/v1/species/2878688"]


def test_leads_list_an_unlinked_pair_once_with_both_sides_words():
    oak = {"id": "english-oak", "group": "greens", "scientificName": "Quercus robur"}
    porcini = {"id": "porcini", "group": "fungi", "scientificName": "Boletus edulis"}
    rows = [
        globi.SpeciesRow(porcini, "Boletus edulis", [
            globi.Partner("Quercus robur", {"hasEctomycorrhizalHost": 2}, "english-oak", False, nz_records=900),
            globi.Partner("Pinus radiata", {"hasHost": 1}, "monterey-pine", True),
            globi.Partner("Betula utilis", {"hasHost": 1}, None, False, nz_records=4),
        ]),
        globi.SpeciesRow(oak, "Quercus robur", [
            globi.Partner("Boletus edulis", {"ectomycorrhizalHostOf": 1}, "porcini", False),
        ]),
    ]
    biota = {"porcini": {
        "quercus robur": {"types": {"has mycorrhizal host"}, "records": 2},
        "betula utilis": {"types": {"has host"}, "records": 1},
    }}
    found = globi.leads(rows, biota)
    assert found["pairs"] == [{
        "a": "english-oak", "b": "porcini",
        "kinds": {"porcini": ["root partner (it is the fungus)"], "english-oak": ["root partner (it is the host)"]},
        "records": {"porcini": 2, "english-oak": 1},
        "nz": {"english-oak": 900, "porcini": 0},
        "biota": 2,
    }]
    assert found["hosts"] == {"porcini": [{"name": "Betula utilis", "kinds": ["lives on"], "nz": 4, "records": 1, "biota": 1}]}


def test_globi_decides_the_leads_and_biota_only_counts_its_records():
    porcini = {"id": "porcini", "group": "fungi", "scientificName": "Boletus edulis"}
    rows = [globi.SpeciesRow(porcini, "Boletus edulis", [
        globi.Partner("Pinus ponderosa", {"hasEctomycorrhizalHost": 1}, None, False, nz_records=194),
        globi.Partner("Cedrus atlantica", {"hasEctomycorrhizalHost": 1}, None, False, nz_records=49),
    ])]
    biota = {"porcini": {"pinus ponderosa": {"types": {"has host"}, "records": 1}}}
    found = globi.leads(rows, biota)
    assert [(h["name"], h["biota"]) for h in found["hosts"]["porcini"]] == [("Pinus ponderosa", 1), ("Cedrus atlantica", 0)]
    assert globi.leads(rows)["hosts"]["porcini"][1]["biota"] == 0


def test_a_fungus_on_many_hosts_with_no_root_partner_record_gets_no_leads():
    turkey_tail = {"id": "turkey-tail", "group": "fungi", "scientificName": "Trametes versicolor"}
    totara = {"id": "totara", "group": "fruit", "scientificName": "Podocarpus totara"}
    on_wood = [globi.Partner(f"Genus{i} species", {"hasHost": 1}, None, False) for i in range(globi.GENERALIST_HOSTS)]
    rows = [
        globi.SpeciesRow(turkey_tail, "Trametes versicolor", [
            globi.Partner("Podocarpus totara", {"hasHost": 1, "parasiteOf": 1}, "totara", False), *on_wood,
        ]),
        globi.SpeciesRow(totara, "Podocarpus totara", [
            globi.Partner("Trametes versicolor", {"hostOf": 1}, "turkey-tail", False),
        ]),
    ]
    # A parasite record does not make it specific: no leads from either side.
    assert globi.leads(rows) == {"pairs": [], "hosts": {}}
    # The same host count with a root-partner record is a specific partnership, so it stays.
    rows[0].partners[0].kinds = {"hasEctomycorrhizalHost": 1}
    assert len(globi.leads(rows)["pairs"]) == 1
    # And a fungus on a few hosts is not a generalist.
    rows[0].partners[:] = rows[0].partners[:1]
    rows[0].partners[0].kinds = {"hasHost": 1}
    assert len(globi.leads(rows)["pairs"]) == 1


BIOTA_SEARCH = """
<a href="/scientific-names/1cb17cc3-36b9-11d5-9548-00d0592d548c"><i>Agaricus campestris</i> L. 1753 var. <i>campestris</i></a>
<a href="/scientific-names/1cb17cc2-36b9-11d5-9548-00d0592d548c"><i>Agaricus campestris</i> L. 1753</a>
<a href="/scientific-names/dd68613c-b3c0-4793-9cb9-e5729d9e07ee"><i>Agaricus campestris</i> L.</a>
<a href="/scientific-names/0238f44c-693a-4dbe-b586-909157ca4ca7"><i>Agaricus arvensis</i> Schaeff.</a>
"""


def test_biota_records_are_the_species_itself_never_a_variety_and_every_duplicate():
    assert globi.biota_record_ids("Agaricus campestris", BIOTA_SEARCH) == [
        "1cb17cc2-36b9-11d5-9548-00d0592d548c", "dd68613c-b3c0-4793-9cb9-e5729d9e07ee",
    ]


def cell(text):
    return f"<td>{text}</td>"


def test_biota_rows_are_read_by_column_heading_whichever_columns_the_page_has():
    page = (
        "<table><thead><tr><th>Recorded name</th><th>Association type</th>"
        "<th>Associated organism (recorded name)</th><th>Associated organism (current name)</th>"
        "<th>Reference</th></tr></thead><tbody><tr>"
        + cell("<i>Agaricus campestris</i> L.") + cell("has host")
        + cell('<div><i>Agrostis capillaris</i> L.</div><div id="link-view-0-2"><a>Associations record</a></div>')
        + cell("<i>Agrostis capillaris</i> L.") + cell("Arnold &amp; Brien (1961)")
        + "</tr></tbody></table>"
    )
    assert globi.biota_associations(page) == [{
        "type": "has host", "recorded": "Agrostis capillaris L.", "current": "Agrostis capillaris L.",
        "country": "", "reference": "Arnold & Brien (1961)",
    }]


def test_new_zealand_partners_keep_nz_and_literature_rows_named_to_species():
    def row(recorded, country, reference="PDD", current=None, kind="has host"):
        return {"type": kind, "recorded": recorded, "current": current or recorded, "country": country, "reference": reference}

    found = globi.new_zealand_partners([
        row("Pinus radiata D.Don", "New Zealand"),
        row("Pinus radiata D.Don", "New Zealand"),
        row("Pinus contorta Loudon", "", reference="Gadgil (2005)", kind="has mycorrhizal host"),
        row("Pinus resinosa", "Canada"),
        row("Pinus", "New Zealand"),
        row("Nothofagus solandri", "New Zealand", current="Fuscospora cliffortioides (Hook.f.) Heenan & Smissen"),
        row("Calluna vulgaris", "", reference=""),
    ])
    assert found == {
        "pinus radiata": {"types": {"has host"}, "records": 2},
        "pinus contorta": {"types": {"has mycorrhizal host"}, "records": 1},
        "nothofagus solandri": {"types": {"has host"}, "records": 1},
        "fuscospora cliffortioides": {"types": {"has host"}, "records": 1},
    }
