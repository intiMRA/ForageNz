"""The catalogue writer matches Swift's encoder, so a tool's diff shows only what it changed."""

from __future__ import annotations

import json

from sources import CATALOGUE, dump_catalogue


def test_the_real_catalogue_round_trips_byte_for_byte() -> None:
    """The check that actually matters: decode the shipped file, re-encode, compare bytes.

    This is the regression guard for a 12,390-insertion / 17,090-deletion diff on a
    four-entry change — Python's `json.dumps` disagrees with Swift's `JSONEncoder` on three
    details at once, and the result is a rewrite of all ~25,000 lines. Asserting against the
    real file rather than a fixture is deliberate: it is the only version whose formatting is
    authoritative, because CatalogueEditor wrote it.
    """
    original = CATALOGUE.read_text()
    assert dump_catalogue(json.loads(original)) == original


def test_key_separator_and_indent_follow_swift() -> None:
    assert dump_catalogue([{"b": 1, "a": "x"}]) == (
        "[\n  {\n    \"a\" : \"x\",\n    \"b\" : 1\n  }\n]\n"
    )


def test_empty_containers_expand_over_two_lines() -> None:
    """`.prettyPrinted` writes an empty array as a newline and a closing bracket, not `[]`."""
    assert dump_catalogue([{"photos": [], "meta": {}}]) == (
        "[\n  {\n    \"meta\" : {\n\n    },\n    \"photos\" : [\n\n    ]\n  }\n]\n"
    )


def test_booleans_do_not_render_as_integers() -> None:
    """`bool` subclasses `int`, so an `isinstance(value, int)` branch placed first writes 1."""
    assert dump_catalogue([{"draft": True, "needsBookSource": False}]) == (
        "[\n  {\n    \"draft\" : true,\n    \"needsBookSource\" : false\n  }\n]\n"
    )


def test_slashes_and_non_ascii_are_left_unescaped() -> None:
    """Swift uses `.withoutEscapingSlashes`; every catalogue URL would otherwise churn."""
    written = dump_catalogue([{"url": "https://example.org/a/b", "name": "Prunus \u00d7domestica"}])
    assert "https://example.org/a/b" in written
    assert "\\/" not in written
    assert "Prunus \u00d7domestica" in written
