"""Description filling copies verbatim, credits, and never overwrites."""

from __future__ import annotations

from datetime import date
from typing import Any

from fetch_descriptions import Fetched, Passage, fill, pick_wikipedia, split_sections

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


def test_wikipedia_sections_pick_description_and_habitat_and_keep_subheadings() -> None:
    fetched = pick_wikipedia("Hypochaeris radicata", EXTRACT, date(2026, 9, 14))
    assert fetched.identification is not None
    assert fetched.identification.text == "Leaves are hairy.\nFlowers\nYellow."
    assert fetched.habitat is not None and fetched.habitat.text == "Lawns."
    assert (
        fetched.summary is not None
        and fetched.summary.text == "Hypochaeris radicata is a perennial."
    )
    assert "CC BY-SA 4.0" in fetched.identification.attribution
    assert "14/09/2026" in fetched.identification.citation
    assert [h for h, _ in split_sections(EXTRACT)] == ["", "Botany", "Distribution and habitat"]


def test_fill_writes_blanks_only_and_cites_once() -> None:
    passage = Passage("Copied.", "Wikipedia, 'X' (CC BY-SA 4.0)", "cite")
    entry: dict[str, Any] = {
        "identification": {"text": "Hand-written.", "sources": []},
        "habitat": {"text": "", "sources": []},
        "summary": {"text": "  ", "sources": []},
        "sources": [],
    }
    written = fill(entry, Fetched(identification=passage, habitat=passage, summary=passage))
    assert written == ["habitat", "summary"]
    assert entry["identification"] == {"text": "Hand-written.", "sources": []}
    assert entry["habitat"] == {"text": "Copied.", "sources": ["Wikipedia, 'X' (CC BY-SA 4.0)"]}
    assert entry["summary"] == {"text": "Copied.", "sources": ["Wikipedia, 'X' (CC BY-SA 4.0)"]}
    assert entry["sources"] == ["Habitat and summary text: cite"]
