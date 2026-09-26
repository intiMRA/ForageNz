"""Put the copied descriptions into metric, and say so in the credit.

New Zealand reads metric, and a field guide that says "up to 3 feet" is asking the reader to
do arithmetic in a gully. The copied text mostly needs no conversion: Wikipedia writes metric
first and puts imperial in brackets, so the bracket is deleted and the sentence stands.

Where a measurement is imperial-only it is converted and the original kept in brackets, the
reverse of what Wikipedia did, so nothing is lost and the claim can still be checked against
the source.

Both are changes to a CC BY-SA quotation, which the licence permits and requires you to
declare, so every field this touches gains "units converted to metric" in its own credit.
Fields with no measurement are left exactly as they were.

    python Tools/metricate.py            # report
    python Tools/metricate.py --write
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from sources import CATALOGUE

PROSE = ("summary", "habitat", "identification", "edibleParts", "preparation")
NOTE = "units converted to metric"

METRIC_UNIT = (
    r"(?:mm|cm|m|km|g|kg|millimet(?:re|er)s?|centimet(?:re|er)s?"
    r"|met(?:re|er)s?|kilomet(?:re|er)s?|grams?|kilograms?|\u00b0\s?C)"
)
#: Units safe to convert by arithmetic: every one is unambiguously a measurement.
IMPERIAL_UNIT = r"(?:inch(?:es)?|feet|foot|ft|miles?|lbs?|pounds?|ounces?|oz)"
#: Inside a bracket that already begins with a digit, "in" is an inch and not the preposition,
#: and Fahrenheit appears only as a conversion of a Celsius value. Both are safe to *drop*
#: there, where the metric is alongside; neither is ever converted by arithmetic.
BRACKETED_IMPERIAL = rf"(?:{IMPERIAL_UNIT}|in\b|\u00b0\s?F\b)"
#: Wikipedia's house style: the metric value, then the same measurement in imperial brackets.
TRAILING_IMPERIAL = re.compile(
    rf"(\d[\d,.\s\u2013\u2014-]*(?:to[\s-]*\d[\d,.]*)?[\s-]*{METRIC_UNIT}(?:-\w+)*)"
    rf"\s*\(\s*[\u2212+-]?\d[^()]*?{BRACKETED_IMPERIAL}[^()]*\)",
    re.I,
)
#: The mirror of the above: imperial first, metric in brackets ("18 inches (46 cm)"). The
#: metric is already there, so the imperial goes and the brackets come off.
LEADING_IMPERIAL = re.compile(
    rf"\d[\d,.\s\u2013\u2014/\u2044+-]*\s?{BRACKETED_IMPERIAL}\s*\((\d[^()]*?{METRIC_UNIT})\)", re.I
)
#: The same measurement twice in one breath: "5-7 mm or 0.20-0.28 inches".
ALTERNATIVE_IMPERIAL = re.compile(
    rf"([\u2212+-]?\d[\d,.\s\u2013\u2014-]*\s?{METRIC_UNIT})\s+or\s+"
    rf"[\u2212+-]?\d[\d,.\s\u2013\u2014/\u2044+-]*\s?{BRACKETED_IMPERIAL}",
    re.I,
)
#: And the same pair the other way round: "above 10°F or -12°C".
ALTERNATIVE_METRIC = re.compile(
    rf"[\u2212+-]?\d[\d,.\s\u2013\u2014/\u2044+-]*\s?{BRACKETED_IMPERIAL}\s+or\s+"
    rf"([\u2212+-]?\d[\d,.\s\u2013\u2014-]*\s?{METRIC_UNIT})",
    re.I,
)
#: A measurement with no metric alongside it, e.g. "about 18 inches high" or "2 to 3 ft".
#: Deliberately narrow: a whole number, optionally a range, optionally a "+1/2" tail, and not
#: already inside brackets, round or square. A bare fraction ("1/6 to 1/2 inches") is left
#: alone and reported rather than half-converted: a wrong measurement in a field guide is
#: worse than an unconverted one.
LONE_IMPERIAL = re.compile(
    rf"(?<![(\[\w/\u2044])(\d+(?:[.,]\d+)?)(?:\s*\+\s*(\d)\s*[/\u2044]\s*(\d))?"
    rf"(\s*(?:to|\u2013|\u2014|-)\s*\d+(?:[.,]\d+)?(?:\s*\+\s*\d\s*[/\u2044]\s*\d)?)?"
    rf"\s?({IMPERIAL_UNIT})\b",
    re.I,
)
#: What the patterns above deliberately skip, so a run can report it instead of mangling it.
#: "in" counts only where it is followed by a bracket or a dimension word, which is what
#: separates "6 in]" from "flowers 3-12 in umbelliform cymes".
UNCONVERTED = re.compile(
    rf"[\d\u2044/]\s*[\d\u2044/]*\s?(?:{IMPERIAL_UNIT}\b|\u00b0\s?F\b"
    rf"|in\s*(?:[)\]]|long|wide|tall|across|deep|thick|in diameter))",
    re.I,
)

#: Metres or millimetres per imperial unit, and how the result should read.
CONVERSIONS: dict[str, tuple[float, str, int]] = {
    "inch": (25.4, "mm", 0),
    "inches": (25.4, "mm", 0),
    "foot": (0.3048, "m", 1),
    "feet": (0.3048, "m", 1),
    "ft": (0.3048, "m", 1),
    "mile": (1.609, "km", 1),
    "miles": (1.609, "km", 1),
    "lb": (0.454, "kg", 2),
    "lbs": (0.454, "kg", 2),
    "pound": (0.454, "kg", 2),
    "pounds": (0.454, "kg", 2),
    "ounce": (28.35, "g", 0),
    "ounces": (28.35, "g", 0),
    "oz": (28.35, "g", 0),
}


def value_of(whole: str, numerator: str | None, denominator: str | None) -> float:
    """`1` or `1 + 1/2` as a number."""
    total = float(whole.replace(",", ""))
    if numerator and denominator and float(denominator) != 0:
        total += float(numerator) / float(denominator)
    return total


def convert(match: re.Match[str]) -> str:
    """One imperial measurement as metric, with the original kept in square brackets.

    Square rather than round: it is the conventional mark for an editor's insertion inside a
    quotation, and it keeps this tool's output out of reach of its own round-bracket
    patterns, so running twice cannot strip the original it just preserved.
    """
    whole, numerator, denominator, upper, unit = match.groups()
    factor, metric_unit, places = CONVERSIONS[unit.lower()]

    def render(raw: float) -> str:
        # A decimal place on a big number is false precision: 1,372 m, not 1,371.6 m.
        converted = raw * factor
        if converted >= 100:
            return f"{converted:,.0f}"
        return f"{converted:.{places}f}".rstrip("0").rstrip(".") if places else f"{converted:.0f}"

    low = render(value_of(whole, numerator, denominator))
    if upper:
        tail = re.sub(r"^\s*(?:to|\u2013|\u2014|-)\s*", "", upper)
        parts = re.match(r"(\d+(?:[.,]\d+)?)(?:\s*\+\s*(\d)\s*[/\u2044]\s*(\d))?", tail)
        high = render(value_of(*(parts.groups() if parts else (tail, None, None))))
        return f"{low}\u2013{high} {metric_unit} [{match.group(0).strip()}]"
    return f"{low} {metric_unit} [{match.group(0).strip()}]"


def metricate(text: str) -> str:
    """The same text in metric. Unchanged when it holds no imperial measurement."""
    #: Every form where the source already gave the metric is resolved first, so the
    #: converter only ever has to do arithmetic where there is genuinely no metric value.
    resolved = TRAILING_IMPERIAL.sub(r"\1", text)
    resolved = LEADING_IMPERIAL.sub(r"\1", resolved)
    resolved = ALTERNATIVE_IMPERIAL.sub(r"\1", resolved)
    resolved = ALTERNATIVE_METRIC.sub(r"\1", resolved)
    return LONE_IMPERIAL.sub(convert, resolved)


def convert_field(field: dict[str, Any]) -> bool:
    """Convert one prose field in place. `True` if it changed."""
    after = metricate(field["text"])
    if after == field["text"]:
        return False
    field["text"] = after
    field["sources"] = [note_the_change(c) for c in field["sources"]]
    return True


def note_the_change(credit: str) -> str:
    return credit if NOTE in credit else f"{credit} — {NOTE}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args(argv)

    catalogue: list[dict[str, Any]] = json.loads(args.catalogue.read_text())
    changed: list[str] = []
    for entry in catalogue:
        for field in PROSE:
            if not convert_field(entry[field]):
                continue
            changed.append(f"{entry['id']}.{field}")

    left = [f"{e['id']}.{f}" for e in catalogue for f in PROSE if UNCONVERTED.search(e[f]["text"])]
    print(f"{len(changed)} fields converted")
    for name in changed[:20]:
        print(f"    {name}")
    print(f"{len(left)} fields still hold an imperial measurement this cannot convert safely")
    for name in left:
        print(f"    {name}")
    if args.write:
        args.catalogue.write_text(json.dumps(catalogue, ensure_ascii=False, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
