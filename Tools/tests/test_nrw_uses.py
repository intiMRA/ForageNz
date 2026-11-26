from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import nrw_uses  # noqa: E402


def test_title_names_expands_abbreviated_genus():
    assert nrw_uses.title_names("Coriaria arborea. C. sarmentosa. Tutu.") == {"coriaria arborea", "coriaria sarmentosa"}


def test_rank_prefers_the_species_record_over_cultivars():
    assert nrw_uses.rank("Phormium tenax. Harakeke.", "phormium tenax") == 0
    assert nrw_uses.rank("Phormium tenax 'Arawa'. Harakeke cultivar.", "phormium tenax") == 2


def test_names_of_reads_synonyms():
    entry = {"scientificName": "Piper excelsum subsp. excelsum (syn. Macropiper excelsum subsp. excelsum)"}
    assert nrw_uses.names_of(entry) == ["piper excelsum", "macropiper excelsum"]


def test_same_epithet_needs_a_shared_name():
    miro = {"commonName": "Miro", "maoriName": "Miro"}
    black_beech = {"commonName": "Black beech", "maoriName": "Tawhairauriki"}
    assert nrw_uses.shares_a_name(miro, "Prumnopitys ferruginea. Miro.")
    assert not nrw_uses.shares_a_name(black_beech, "Astelia solandri. Kōwharawhara. Kahakaha. Perching astelia.")


def test_record_fields_are_read_from_sections():
    page = ('<h2><i>Coprosma robusta</i>.  Karamū.</h2>'
            '<div id="section-dyes" data-label="Dyes"><div id="section-dyes-content" class="pb-2">'
            '<p>Old-gold colour from bark</p></div></div>'
            '<div id="section-metadata" data-label="Metadata"></div>')
    original = nrw_uses.fetch
    nrw_uses.fetch = lambda url: page
    try:
        found = nrw_uses.record("f3aa98d2-d83c-42a1-9458-646c16cdd6f3")
    finally:
        nrw_uses.fetch = original
    assert found["title"] == "Coprosma robusta. Karamū."
    assert found["fields"] == {"dyes": "Old-gold colour from bark"}
