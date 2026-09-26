"""A scraped name becomes an entry only once two registers agree."""

from __future__ import annotations

from validate_candidates import accepted_name, book_heading, choose_common_name, tidy_name


def test_tidy_name_capitalises_without_touching_the_rest() -> None:
    assert tidy_name("garden orache") == "Garden orache"
    assert tidy_name("New Zealand sow thistle") == "New Zealand sow thistle"
    assert tidy_name("Spanish Broom") == "Spanish Broom"
    assert tidy_name("Shining Karamū") == "Shining Karamū"
    assert tidy_name("  ") == ""


def test_book_heading_keeps_only_a_heading_this_entry_can_be_cited_under() -> None:
    def heading(
        title: str, common: str = "Bermuda buttercup", sci: str = "Oxalis pes-caprae"
    ) -> str | None:
        return book_heading(title, common, sci)

    assert heading("Bermuda buttercup (left)") == "Bermuda buttercup"
    assert heading("Bermuda buttercup (bottom)") == "Bermuda buttercup"
    assert heading("(right)") is None
    assert heading("") is None
    # A heading that belongs to the species next to it on the page.
    assert heading("Solanum aviculare", "Poroporo", "Solanum laciniatum") is None
    assert heading("Symphytum offi cinale", "Rough comfrey", "Symphytum asperum") is None
    assert heading("Or mountain spinach", "Garden orache", "Atriplex hortensis") is None
    assert heading("Crabapple", "Common pear", "Pyrus communis") is None
    assert heading("Tree", "Forest cabbage tree", "Cordyline banksii") is None
    # A lone word is a heading when it is the whole name.
    assert heading("Kanono", "Kanono", "Coprosma grandifolia") == "Kanono"
    # Sharing a word is not enough: each of these is the heading of a different species.
    assert heading("Cornered garlic", "Naples garlic", "Allium neapolitanum") is None
    assert heading("Red clover", "White clover", "Trifolium repens") is None
    assert heading("New Zealand celery", "Celery", "Apium graveolens") is None
    assert heading("Stinking mayweed", "Stinking chamomile", "Anthemis cotula") is None
    # A short qualifier is exactly what separates two species, so it counts too.
    assert heading("Sea celery", "Celery", "Apium graveolens") is None
    assert heading("Red clover", "Clover", "Trifolium repens") is None
    # The book's shorter form of our own name still verifies.
    assert heading("Raspberry", "Red raspberry", "Rubus idaeus") == "Raspberry"


def test_choose_common_name_prefers_the_register_and_refuses_placeholders() -> None:
    assert choose_common_name("Sea rocket", "Sea rocket (left)") == "Sea rocket"
    assert choose_common_name(None, "Sea rocket (left)") == "Sea rocket"
    assert choose_common_name(None, "beach spinach") == "Beach spinach"
    assert choose_common_name("No common name", "Stinging nettle") == "Stinging nettle"
    assert choose_common_name("No common name", "") == ""
    assert choose_common_name(None, "") == ""


def test_accepted_name_prefers_nzors_answer_over_a_synonym() -> None:
    assert accepted_name("Acca sellowiana", "Feijoa sellowiana") == "Feijoa sellowiana"
    assert accepted_name("Urtica ferox", None) == "Urtica ferox"
    assert accepted_name("Urtica ferox", "  ") == "Urtica ferox"
