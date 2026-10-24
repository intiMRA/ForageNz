"""Spell out the Flora of New Zealand's shorthand, and say so in the credit.

The Flora writes for botanists: "Racemes with numerous ♂ and ♀ fls", "Lvs us. glab.",
"Pedicels > petioles". A forager reading that on a phone in the bush gets symbols, not a
description. Each abbreviation here has one meaning in the Flora's own conventions, so it is
replaced by that meaning and nothing else: "Racemes with numerous male and female flowers",
"Leaves usually glabrous", "Pedicels longer than petioles".

Botanical terms (lamina, glabrous, acuminate) stay: they are words with definitions, not
shorthand. So do taxonomic abbreviations (subsp., var., et al.) and the Flora's region codes
("N.; S.; St.; K., Ch."), which are not prose and do not expand to a sentence.

Spelling an abbreviation out is a change to a CC BY quotation, which the licence permits and
requires you to declare, so every field this touches gains "abbreviations spelled out" in its
Flora credit.

    python Tools/expand_flora.py            # report
    python Tools/expand_flora.py --write
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from sources import CATALOGUE, write_catalogue

PROSE = ("summary", "habitat", "identification", "edibleParts", "preparation")
NOTE = "abbreviations spelled out"
FLORA = "Flora of New Zealand"

#: Shorthand with no full stop, matched as a whole word. Order matters only where one is a
#: prefix of another, and none is.
WORDS = {
    "Lvs": "Leaves",
    "lvs": "leaves",
    "Fls": "Flowers",
    "fls": "flowers",
    "fld": "flowered",
    "lf": "leaf",
    "Sts": "Sometimes",
    "sts": "sometimes",
}
#: Shorthand ending in a full stop. The stop is the abbreviation's, so it goes; but when the
#: abbreviation also ended the sentence (a capital or the end of the text follows) the
#: sentence's own stop is put back.
DOTTED = {
    "Infl": "Inflorescence",
    "infl": "inflorescence",
    "Fr": "Fruit",
    "fr": "fruit",
    "glab": "glabrous",
    "us": "usually",
    "opp": "opposite",
    "occ": "occasionally",
    "coriac": "coriaceous",
    "membr": "membranous",
    "diam": "diameter",
    "Id": "Island",
    "c": "about",
}
#: Sex symbols, and the Flora's comparisons of one organ's length with another's.
SYMBOLS = (
    ("♂", "male"),
    ("♀", "female"),
    ("⚥", "bisexual"),
    ("±", "more or less"),
)
#: The comparison is of length unless the clause is about width, where it is of size.
COMPARISONS = {
    "<": ("shorter than", "less than"),
    ">": ("longer than", "greater than"),
    "=": ("equal to", "equal to"),
}
WIDTH = re.compile(r"\b(?:width|wide|broad)")

DOTTED_PATTERN = re.compile(
    r"(?<![\w.])(" + "|".join(sorted(DOTTED, key=len, reverse=True)) + r")\.((?=\s+[A-Z]|\s*$))?"
)
WORD_PATTERN = re.compile(r"(?<![\w.])(" + "|".join(WORDS) + r")(?!\w)")
#: A unit written with the old Flora's full stop mid-sentence: "5 mm. long".
UNIT_STOP = re.compile(r"(\d\s?(?:mm|cm|m))\.(?=\s+[a-z(])")


def expand_dotted(match: re.Match[str]) -> str:
    full = DOTTED[match.group(1)]
    ends_sentence = match.group(2) is not None
    return f"{full}." if ends_sentence else full


def compare(match: re.Match[str], text: str) -> str:
    before = re.split(r"[.;,(]", text[: match.start()])[-1]
    after = re.split(r"[.;,)]", text[match.end() :])[0]
    length, size = COMPARISONS[match.group(1)]
    return size if WIDTH.search(before + " " + after) else length


def expand(text: str) -> str:
    """The same text with the Flora's shorthand written out. Unchanged when it holds none."""
    out = text.replace("at fl.", "at flowering").replace(" fl. ", " flower ")
    out = WORD_PATTERN.sub(lambda m: WORDS[m.group(1)], out)
    out = DOTTED_PATTERN.sub(expand_dotted, out)
    out = UNIT_STOP.sub(r"\1", out)
    #: Before a measurement "±" is an approximation, not a manner: "± 3 mm" is about 3 mm.
    out = re.sub(r"±\s*(?=\d)", "about ", out)
    for symbol, word in SYMBOLS:
        out = out.replace(symbol, word)
    out = re.sub(r"\s*([<>=])\s*", lambda m: f" {compare(m, out)} ", out)
    return re.sub(r"(?<=\S)[ \t]{2,}", " ", out).strip()


def is_flora(field: dict[str, Any]) -> bool:
    return any(FLORA in credit for credit in field["sources"])


def expand_field(field: dict[str, Any]) -> bool:
    """Expand one Flora-credited prose field in place. `True` if it changed."""
    if not is_flora(field):
        return False
    after = expand(field["text"])
    if after == field["text"]:
        return False
    field["text"] = after
    field["sources"] = [note_the_change(c) for c in field["sources"]]
    return True


def note_the_change(credit: str) -> str:
    if FLORA not in credit or NOTE in credit:
        return credit
    return f"{credit} — {NOTE}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args(argv)

    catalogue: list[dict[str, Any]] = json.loads(args.catalogue.read_text())
    changed = [
        f"{entry['id']}.{field}"
        for entry in catalogue
        for field in PROSE
        if expand_field(entry[field])
    ]
    print(f"{len(changed)} fields expanded")
    for name in changed[:20]:
        print(f"    {name}")
    if args.write:
        write_catalogue(catalogue, args.catalogue)
    return 0


if __name__ == "__main__":
    sys.exit(main())
