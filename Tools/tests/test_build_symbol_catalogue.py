"""A list can take any system symbol the app's target ships, but not a restricted or script copy."""

from __future__ import annotations

from build_symbol_catalogue import selectable_symbols

YEAR_TO_IOS = {"2019": "13.0", "2024": "18.0", "2025": "26.0"}


def test_keeps_released_symbols_in_order_and_drops_newer_and_restricted_ones() -> None:
    order = ["leaf", "applelogo", "sparkles.2", "tree"]
    availability = {"leaf": "2019", "applelogo": "2019", "sparkles.2": "2025", "tree": "2024"}

    assert selectable_symbols(order, availability, YEAR_TO_IOS, {"applelogo"}, (18, 0)) == ["leaf", "tree"]


def test_drops_a_script_copy_only_when_its_base_symbol_is_kept() -> None:
    order = ["character", "character.ja", "folder.rtl", "folder", "dot.radiowaves.up", "only.ar"]
    availability = dict.fromkeys(order, "2019")

    assert selectable_symbols(order, availability, YEAR_TO_IOS, set(), (18, 0)) == [
        "character",
        "folder",
        "dot.radiowaves.up",
        "only.ar",
    ]
