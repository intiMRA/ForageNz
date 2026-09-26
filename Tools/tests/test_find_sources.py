"""A citation is only written when the page it points at answers and names the species."""

from __future__ import annotations

from find_sources import mentions, slugs_for, species_name


def test_mentions_sees_a_name_split_by_markup_but_not_a_different_species() -> None:
    assert mentions("<i>Euphorbia</i> <b>peplus</b> is a weed", "Euphorbia peplus")
    assert mentions("Euphorbia peplus L.", "Euphorbia peplus")
    assert not mentions("Euphorbia lathyris only", "Euphorbia peplus")
    assert not mentions("", "Euphorbia peplus")


def test_slugs_for_offers_the_synonym_a_register_may_file_it_under() -> None:
    assert slugs_for("Pteridium esculentum") == [("Pteridium esculentum", "pteridium-esculentum")]
    assert ("Feijoa sellowiana", "feijoa-sellowiana") in slugs_for("Acca sellowiana")


def test_species_name_reduces_an_entry_to_the_one_name_to_look_up() -> None:
    assert species_name({"scientificName": "Lactarius spp."}) == "Lactarius"
    assert (
        species_name({"scientificName": "Prunus domestica / Prunus cerasifera"})
        == "Prunus domestica"
    )
    assert species_name({"scientificName": "Boletaceae (red-pored)"}) == "Boletaceae"
    assert species_name({"scientificName": "Conium maculatum"}) == "Conium maculatum"
