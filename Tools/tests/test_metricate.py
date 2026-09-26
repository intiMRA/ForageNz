"""Converted text still says what the source said, and the credit admits the change."""

from __future__ import annotations

from metricate import UNCONVERTED, convert_field, metricate, note_the_change


def test_wikipedias_imperial_bracket_is_dropped_because_the_metric_is_already_there() -> None:
    assert metricate("growing to 60\u2013170 centimetres (24\u201367 inches) tall") == (
        "growing to 60\u2013170 centimetres tall"
    )
    assert metricate("to 3,500 m (11,500 ft) in elevation") == "to 3,500 m in elevation"
    assert metricate("up to 5 millimetres (1\u20444 inch) long") == "up to 5 millimetres long"


def test_metric_given_after_the_imperial_is_kept_and_the_imperial_dropped() -> None:
    assert metricate("about 18 inches (46 cm) high") == "about 46 cm high"
    assert metricate("sea level to 4,500 feet (1,400 metres)") == "sea level to 1,400 metres"
    assert metricate("capsules are large (5\u20137 mm or 0.20\u20130.28 inches) in diameter") == (
        "capsules are large (5\u20137 mm) in diameter"
    )


def test_an_imperial_only_measurement_is_converted_and_the_original_kept() -> None:
    assert metricate("about 18 inches high") == "about 457 mm [18 inches] high"
    assert metricate("10 feet from the ground") == "3 m [10 feet] from the ground"
    # Already inside brackets: left alone, and reported by the run instead.
    assert metricate("shorter heights (25 ft)") == "shorter heights (25 ft)"


def test_ranges_and_fractions_convert_as_one_measurement() -> None:
    # A bare fraction is left alone rather than half-converted.
    assert metricate("1/6 to 1/2 inches long") == "1/6 to 1/2 inches long"
    assert metricate("sea level to 4,500 feet") == "sea level to 1,372 m [4,500 feet]"
    assert metricate("2-to-3-metre-tall (6+1\u20442 to 10 ft)") == "2-to-3-metre-tall"


def test_text_without_a_measurement_is_returned_untouched() -> None:
    plain = "The leaves are hairy and the flowers yellow."
    assert metricate(plain) is plain or metricate(plain) == plain
    assert metricate("") == ""


def test_the_credit_records_the_alteration_once() -> None:
    credit = "Wikipedia, 'Malva sylvestris' (CC BY-SA 4.0)"
    once = note_the_change(credit)
    assert once.endswith("— units converted to metric")
    assert note_the_change(once) == once


def test_wikipedias_abbreviated_inch_and_fahrenheit_are_dropped_too() -> None:
    assert metricate("growing up to 50 centimetres (20 in) tall") == (
        "growing up to 50 centimetres tall"
    )
    assert metricate("40\u201370 cm (16\u201328 in)") == "40\u201370 cm"
    assert metricate("hardy to \u221215 \u00b0C (5 \u00b0F)") == "hardy to \u221215 \u00b0C"


def test_below_zero_temperatures_convert_like_any_other_pair() -> None:
    assert metricate("cold as low as \u221220 \u00b0C (\u22124 \u00b0F) is tolerated") == (
        "cold as low as \u221220 \u00b0C is tolerated"
    )
    assert metricate("temperatures above 10\u00b0F or -12\u00b0C, such as") == (
        "temperatures above -12\u00b0C, such as"
    )


def test_a_bracket_that_is_not_a_measurement_is_left_alone() -> None:
    assert metricate("40 cm (found in shade)") == "40 cm (found in shade)"
    assert metricate("2 m (common in Otago)") == "2 m (common in Otago)"


def test_a_field_is_converted_once_and_never_again() -> None:
    field = {"text": "he saw it 10 feet from the ground", "sources": ["Wikipedia (CC BY-SA 4.0)"]}
    assert convert_field(field) is True
    once = field["text"]
    assert once == "he saw it 3 m [10 feet] from the ground"
    assert convert_field(field) is False
    assert field["text"] == once


def test_running_twice_changes_nothing() -> None:
    for text in (
        "growing to 60\u2013170 centimetres (24\u201367 inches) tall",
        "he saw it 10 feet from the ground",
        "about 18 inches (46 cm) high",
        "40\u201370 cm (16\u201328 in)",
    ):
        assert metricate(metricate(text)) == metricate(text)


def test_the_report_tells_an_inch_from_the_preposition() -> None:
    assert UNCONVERTED.search("2.5 to 6 in] in diameter")
    assert UNCONVERTED.search("shorter heights (25 ft)")
    assert UNCONVERTED.search("1/6 to 1/2 inches long")
    assert not UNCONVERTED.search("flowers 3\u201312 in umbelliform cymes")
    assert not UNCONVERTED.search("recorded growing in an English garden in 1617")
