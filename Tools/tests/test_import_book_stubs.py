"""Stubs carry only facts from the book, never its words."""

from __future__ import annotations

from import_book_stubs import (
    cite,
    first_scientific_name,
    guess_category,
    make_stub,
    parse_months,
    slugify,
)


def test_slugify_handles_curly_apostrophes_macrons_and_leading_digits() -> None:
    assert slugify("Buck\u2019s-horn plantain") == "bucks-horn-plantain"
    assert slugify("Shepherd's purse") == "shepherds-purse"
    assert slugify("Mānuka") == "manuka"
    assert slugify("3-cornered leek").startswith("species-")


def test_parse_months_prefers_a_stated_peak() -> None:
    assert parse_months("In season from November to July, with a peak from January to May.") == [
        1,
        2,
        3,
        4,
        5,
    ]


def test_parse_months_capitalised_peak_does_not_recurse() -> None:
    assert parse_months("Fruits October to March. Peak in December.") == [12]


def test_parse_months_ranges_wrap_the_new_year() -> None:
    assert parse_months("Berries from late November until mid-February.") == [1, 2, 11, 12]


def test_parse_months_season_words_are_southern_hemisphere() -> None:
    assert parse_months("Best foraged in winter and spring.") == [6, 7, 8, 9, 10, 11]


def test_parse_months_year_round_is_empty_and_unknown_is_none() -> None:
    assert parse_months("Available year-round.") == []
    assert parse_months("") is None
    assert parse_months("After rain.") is None


def test_first_scientific_name_drops_prose_and_extra_names() -> None:
    assert first_scientific_name("Sonchus asper, sonchus oleraceus") == "Sonchus asper"
    assert first_scientific_name("Suillus spp. There are several species") == "Suillus spp."
    assert first_scientific_name("Hosta spp.") == "Hosta spp."
    assert first_scientific_name("Phormium tenax (and other species)") == "Phormium tenax"


def test_guess_category_uses_chapter_then_title() -> None:
    assert guess_category("Slippery jack", 739, 683, 726) == "fungi"
    assert guess_category("Wakame", 690, 683, 726) == "seaweed"
    assert guess_category("Sweet chestnuts", 636, 683, 726) == "nuts"
    assert guess_category("Cherry plum", 387, 683, 726) == "fruit"
    assert guess_category("Chickweed", 212, 683, 726) == "greens"
    assert guess_category("Pineappleweed", 90, 683, 726) == "greens"
    assert guess_category("Apple mint", 260, 683, 726) == "herbs"
    assert guess_category("Darwin's barberry", 140, 683, 726) == "fruit"
    assert guess_category("Wild spearmint", 258, 683, 726) == "herbs"
    assert guess_category("Mouse-ear hawkweed", 110, 683, 726) == "greens"


def test_stub_is_a_draft_with_blank_prose_and_a_book_citation() -> None:
    stub = make_stub(
        {
            "title": "Wild parsnip",
            "scientific": "Pastinaca sativa",
            "maori": "",
            "season": "Roots in autumn.",
            "page": 66,
        },
        origin=None,
        seaweed_from=683,
        fungi_from=726,
    )
    entry = stub.entry
    assert entry["draft"] is True
    assert entry["caution"] == "careRequired"
    assert entry["months"] == [3, 4, 5]
    assert all(
        entry[field] == {"text": "", "sources": []}
        for field in ("summary", "habitat", "identification", "edibleParts", "preparation")
    )
    assert entry["lookalikes"] == [] and entry["warnings"] == []
    assert entry["sources"] == [
        "Langlands, Peter. Foraging New Zealand (Penguin Random House NZ, 2024)."
    ]
    assert "maoriName" not in entry
    assert stub.origin_unknown and entry["origin"] == "introduced"


EXTRACT = """Hypochaeris radicata is a perennial. It is found in Europe.

== Botany ==
Leaves are hairy.
=== Flowers ===
Yellow.

== Distribution and habitat ==
Lawns.
Source: USDA

== References ==
Stuff.
"""


def test_cite_names_the_book_entry_only_when_one_is_known() -> None:
    assert cite("A Book (2013)", "Samphire") == "A Book (2013), 'Samphire' entry."
    assert cite("A Book (2013)", None) == "A Book (2013)."
