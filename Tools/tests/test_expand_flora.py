"""Expanded text still says what the Flora said, and the Flora credit admits the change."""

from __future__ import annotations

from expand_flora import NOTE, expand, expand_field

FLORA = "Flora of New Zealand Online, Manaaki Whenua \u2013 Landcare Research (CC BY 3.0 NZ)"


def test_sex_symbols_and_flowers_are_written_out() -> None:
    assert expand("Racemes with numerous ♂ and ♀ fls, up to 3 cm long.") == (
        "Racemes with numerous male and female flowers, up to 3 cm long."
    )
    assert expand("relatively large ⚥ fls") == "relatively large bisexual flowers"


def test_a_dotted_abbreviation_keeps_the_sentence_stop_only_when_it_ended_the_sentence() -> None:
    assert expand("Lvs us. glab. on upper surface") == "Leaves usually glabrous on upper surface"
    assert expand("ovate, glab. Fr. 5 mm diam.") == "ovate, glabrous. Fruit 5 mm diameter."
    assert expand("Petiole c. ⅔ as long as lamina.") == "Petiole about ⅔ as long as lamina."


def test_comparisons_are_of_length_unless_the_clause_is_about_width() -> None:
    assert expand("Pedicels > petioles") == "Pedicels longer than petioles"
    assert expand("calyx teeth ± = tube") == "calyx teeth more or less equal to tube"
    assert expand("Filament width usually < anther width") == (
        "Filament width usually less than anther width"
    )


def test_plus_minus_before_a_measurement_is_an_approximation() -> None:
    assert expand("stamens ± 3 mm long") == "stamens about 3 mm long"


def test_region_codes_and_taxonomy_are_left_alone() -> None:
    text = "N.; S.; St.; K., Ch. Webb et al. (1988); subsp. ferox"
    assert expand(text) == text


def test_only_flora_fields_change_and_only_the_flora_credit_is_noted() -> None:
    wikipedia = {"text": "Lvs us. glab.", "sources": ["Wikipedia (CC BY-SA 4.0)"]}
    assert not expand_field(wikipedia)
    assert wikipedia["text"] == "Lvs us. glab."

    flora = {"text": "Lvs us. glab.", "sources": [FLORA, "Wikipedia (CC BY-SA 4.0)"]}
    assert expand_field(flora)
    assert flora["text"] == "Leaves usually glabrous."
    assert flora["sources"] == [f"{FLORA} — {NOTE}", "Wikipedia (CC BY-SA 4.0)"]
    assert not expand_field(flora)
