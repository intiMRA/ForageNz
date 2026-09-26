"""Reading an entry's scientific-name field the way a register would."""

from __future__ import annotations

from audit_names import ABOVE_SPECIES, names_in


def test_names_in_splits_alternatives_and_drops_parenthesised_notes() -> None:
    assert names_in("Urtica dioica / Urtica urens") == ["Urtica dioica", "Urtica urens"]
    assert names_in("Piper excelsum (syn. Macropiper excelsum)") == ["Piper excelsum"]
    assert names_in("Suillus luteus (and other Suillus spp.)") == ["Suillus luteus"]
    assert names_in("Boletaceae (red-pored)") == ["Boletaceae"]
    assert names_in("Conium maculatum") == ["Conium maculatum"]


def test_above_species_names_are_exempt_from_the_biostatus_check() -> None:
    assert ABOVE_SPECIES.search("Suillus spp.")
    assert ABOVE_SPECIES.search("Boletaceae")
    assert ABOVE_SPECIES.search("Boletales")
    assert not ABOVE_SPECIES.search("Conium maculatum")
