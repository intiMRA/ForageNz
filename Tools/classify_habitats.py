"""Classify each entry's habitat prose into the `Habitat` buckets the app can filter on.

Nothing here adds a claim. The only input is the entry's own `habitat` text — already copied
from a licensed source or written by the owner — and the only output is a set of labels that
text already supports. An entry with no habitat prose gets no labels: absent means nobody has
classified it, never that the species grows nowhere.

Two things stop the obvious false positives:

  - **Denials are dropped.** The field mushroom's "Not in woodland." would otherwise file it
    under forest, which is precisely backwards. Text is split into clauses, and each clause is
    truncated where it turns into a denial — "not in", "does not grow with", "doesn't occur",
    "cannot", "never", "rarely". Truncating rather than discarding the clause keeps the claim
    in "Common on the coast, does not reach the alpine zone."
  - **Ambiguous words carry their context.** "Park" is urban unless it is a national, forest
    or regional park; "sea" is the coast unless it is "sea level"; "marsh" is wetland unless
    it is saltmarsh, which is coast; a lake is wetland unless the species is merely found
    *near* one. Bare "sandy" and "rocky" are not read as coastal at all, because inland soil
    is both.
  - **A herbarium list is not prose.** "Specimens examined: … Atkinson Park, Titirangi Beach"
    is a run of place names, and New Zealand place names are built out of habitat words. The
    whole paragraph is dropped before anything is read.

The rules are deliberately shy. A missed label is an entry that does not show up in a filter;
a wrong one tells someone to look for food in the wrong place.

    python Tools/classify_habitats.py            # report
    python Tools/classify_habitats.py --write
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from sources import CATALOGUE

#: Mirrors `Habitat.allCases` in Swift, so the written arrays read in a stable order.
HABITATS = (
    "coastal",
    "forest",
    "shrubland",
    "grassland",
    "wetland",
    "alpine",
    "urban",
    "disturbed",
)

#: Where a clause stops claiming a habitat and starts denying one. Everything from here to the
#: end of the clause is dropped. "does not grow with native bush trees, so a bolete under beech
#: or kānuka is something else" is the shape that motivated the verb forms: it names three
#: habitats, all of them to rule out, and an earlier version that only caught a clause-initial
#: negator or "not in/on/under" read every one of them as a claim.
DENIAL = re.compile(
    r"^\W*(?:not|never|rarely|seldom|avoids?|absent)\b"
    r"|\bnot\s+(?:in|on|under|near|with)\b"
    r"|\b(?:does|do|did|is|are|was|were|will|would|can|could|should)\s+not\b"
    r"|\b(?:doesn|don|didn|isn|aren|wasn|weren|won|wouldn|can|couldn|shouldn)['\u2019]t\b"
    r"|\bcannot\b"
    r"|\b(?:never|rarely|seldom)\b",
    re.I,
)
#: Clause boundaries: sentence punctuation, dashes used as asides, and "but".
CLAUSES = re.compile(r"[.;:\u2014\u2013]|\bbut\b", re.I)

#: A herbarium collection list is not habitat prose, and reading it as prose is worse than
#: reading nothing: it is a run of New Zealand place names, and place names are made of habitat
#: words. *Psilocybe aucklandiae*'s list gave it `coastal` from "Titirangi **Beach**" and
#: `urban` from "Atkinson **Park**", neither of which says anything about where the fungus
#: grows. Everything from the heading to the end of that paragraph goes.
SPECIMEN_LIST = re.compile(
    r"\b(?:specimens?|materials?|collections?)\s+(?:examined|studied|seen)\b[^\n]*",
    re.I,
)

RULES: dict[str, tuple[str, ...]] = {
    "coastal": (
        r"\bcoast(?:al|s|line)?\b",
        r"\b(?:sea)?shores?\b",
        r"\bforeshore\b",
        r"\bbeach(?:es)?\b",
        r"\b(?:sand\s*)?dunes?\b",
        r"\bintertidal\b",
        r"\bestuar(?:y|ies|ine)\b",
        r"\bsalt\s?marsh(?:es)?\b",
        r"\btidal\b",
        r"\blittoral\b",
        r"\bmangroves?\b",
        r"\bharbours?\b",
        r"\brock\s?pools?\b",
        r"\bsplash zone\b",
        # "Sea" needs an article or a qualifier to be the sea itself. Bare, it is usually
        # part of a name — hemlock's prose mentions sea celery — or "sea level", an altitude.
        r"\b(?:the|open|warm|tropical|temperate|shallow)\s+seas?\b(?!\s*level)",
        r"\bsea\s?water\b",
        r"\bseaside\b",
    ),
    "forest": (
        r"\bforest(?:s|ed)?\b",
        r"\bbush\b",
        r"\bwoodland?s?\b",
        r"\bwoods\b",
        r"\bcanopy\b",
        r"\bunderstor(?:e)?y\b",
        r"\bplantations?\b",
        r"\bpodocarp\b",
        # A shelter belt is a planted row of tall trees — macrocarpa, pine, poplar — so it
        # belongs with the forest, not with the hedgerows it sits beside in the prose.
        r"\bshelter\s?belts?\b",
        # "Under introduced broadleaf trees" is a forest; "roadside trees" is not, so the
        # word only counts when something is growing under them.
        r"\bunder\b[^,.;]{0,40}\btrees?\b",
        r"\bunder\b[^,.;]{0,40}\b(?:oak|birch|beech|pine|willow|poplar|hornbeam|chestnut)s?\b",
        # Growing on the fallen wood or litter of a forest tree puts you in that forest, the
        # same claim "under beech" makes from the other side. Wanted by *Psilocybe makarorae*,
        # whose prose gives its substrate — "the fallen, rotting wood of southern beeches
        # (genus Nothofagus)" — and never uses the word forest.
        r"\b(?:wood|litter|logs?|branches?|trunks?|stumps?)\b[^,.;]{0,40}"
        r"\b(?:beech|nothofagus|podocarp|pine|eucalypt|rimu|kauri|tōtara|totara|kahikatea"
        r"|tāwa|tawa|māhoe|mahoe|mānuka|manuka|kānuka|kanuka)\w*",
        # A fungus fruiting on fallen wood is telling you to look in the trees.
        r"\b(?:logs?|stumps?|fallen timber|dead wood|deadwood)\b",
        r"\bon\b[^,.;]{0,30}\btrees?\b",
    ),
    "shrubland": (
        r"\bscrub(?:land|by)?\b",
        r"\bshrubland\b",
        r"\bgorse\b",
        r"\bbroom\b",
        r"\bhedge(?:s|row|rows)?\b",
        r"\bthickets?\b",
        r"\bbracken\b",
        r"\bregenerating\b",
        r"\bm[aā]nuka\b",
        r"\bk[aā]nuka\b",
    ),
    "grassland": (
        r"\bpastures?\b",
        r"\bpastureland\b",
        r"\bpaddocks?\b",
        r"\bmeadows?\b",
        r"\blawns?\b",
        r"\bgrassland?s?\b",
        r"\bgrassy\b",
        r"\bgrass\b",
        r"\bgraz(?:ed|ing)\b",
        r"\bfarmland\b",
        r"\bfarms?\b",
        r"\bturf\b",
        r"\b(?:sports|playing)\s?fields?\b",
    ),
    "wetland": (
        r"\bwetlands?\b",
        r"\bswamp(?:s|y)?\b",
        r"\bbog(?:s|gy)?\b",
        # Saltmarsh is the coast, not fresh water.
        r"(?<!salt)(?<!salt )\bmarsh(?:es|y|land)?\b",
        r"\brivers?\b",
        r"\briver\s?(?:banks?|beds?)\b",
        r"\bstream(?:s|side|sides)?\b",
        r"\bcreeks?\b",
        r"\bponds?\b",
        # A lake edge is wetland; "encountered near lakes and picnic grounds" is a locality,
        # telling you where people run into the species, not what it grows in. `lakeside` and
        # `lake margins` still count, so nothing that really lives on a shore is lost.
        r"(?<!near )\blake(?:s|side)?\b",
        r"\bditch(?:es)?\b",
        r"\bdrains?\b",
        r"\bseepage\b",
        r"\bfreshwater\b",
        r"\briparian\b",
        r"\bwaterlogged\b",
        r"\bwet ground\b",
    ),
    "alpine": (
        r"\balpine\b",
        r"\bsub-?alpine\b",
        r"\btussocks?\b",
        r"\bmontane\b",
        r"\bscree(?:s)?\b",
        r"\bherbfields?\b",
        r"\btree\s?line\b",
        r"\bmountains?\b",
        r"\bhigh country\b",
        r"\bsnow\s?line\b",
    ),
    "urban": (
        r"\bgardens?\b",
        r"\bsuburb(?:s|an)?\b",
        r"\burban\b",
        r"\bcit(?:y|ies)\b",
        r"\btowns?\b",
        r"\bberms?\b",
        r"\bstreets?\b",
        r"\bbackyards?\b",
        r"\ballotments?\b",
        # Cultivated *ground* is a garden. "Cultivated on rice straw in Southeast Asia" is a
        # commercial crop and says nothing about where to look here.
        r"\bcultivated\b(?:\s+\w+){0,2}\s+(?:ground|soil|land|beds?|paddocks?|gardens?)\b",
        r"\bcultivation\b",
        r"\bplantings?\b",
        r"\bcemeter(?:y|ies)\b",
        r"\bchurchyards?\b",
        # A national, forest, regional or conservation park is the opposite of urban.
        r"(?<!national )(?<!forest )(?<!regional )(?<!conservation )\bparks?\b",
    ),
    "disturbed": (
        r"\broadsides?\b",
        r"\bverges?\b",
        r"\bwaysides?\b",
        r"\bwaste\s?(?:ground|land|places|areas)\b",
        r"\bwasteland\b",
        r"\bdisturbed\b",
        r"\brailways?\b",
        r"\brubbish\b",
        r"\bvacant\b",
        r"\babandoned\b",
        r"\bderelict\b",
        r"\bfallow\b",
        r"\btrackside\b",
        r"\bcar\s?parks?\b",
        r"\bpavements?\b",
        r"\bkerbs?\b",
        r"\balong roads\b",
    ),
}

COMPILED: dict[str, re.Pattern[str]] = {
    habitat: re.compile("|".join(patterns), re.I) for habitat, patterns in RULES.items()
}


def claims(text: str) -> list[str]:
    """The parts of `text` that assert a habitat, truncated where each starts denying one.

    Truncating rather than dropping the whole clause keeps the claim in "Common in the North
    Island, does not reach Southland" while still losing the denial.
    """
    kept: list[str] = []
    for clause in CLAUSES.split(SPECIMEN_LIST.sub(" ", text)):
        if not clause:
            continue
        denial = DENIAL.search(clause)
        asserted = clause[: denial.start()] if denial else clause
        if asserted.strip():
            kept.append(asserted)
    return kept


def classify(text: str) -> list[str]:
    """The habitats `text` supports, in `HABITATS` order. Empty for blank or unmatched prose."""
    asserted = " ".join(claims(text))
    if not asserted.strip():
        return []
    return [habitat for habitat in HABITATS if COMPILED[habitat].search(asserted)]


def evidence(text: str) -> dict[str, list[str]]:
    """Per habitat, the words in `text` that earned it — the reason, not just the verdict.

    A label is only as good as the phrase behind it, and the two defects found so far were
    both invisible in the verdict and obvious in the evidence: `urban` on a mushroom because
    its prose mentioned *sea celery*, `shrubland` on a pine-plantation fungus because a
    shelter belt was filed with the hedgerows.
    """
    asserted = " ".join(claims(text))
    found: dict[str, list[str]] = {}
    for habitat in HABITATS:
        # Deduplicated case-insensitively, first spelling kept: "Forest" then "forest" is one
        # piece of evidence, and listing it twice pads the review sheet without informing it.
        seen: dict[str, str] = {}
        for match in COMPILED[habitat].finditer(asserted):
            word = match.group(0).strip()
            seen.setdefault(word.casefold(), word)
        if seen:
            found[habitat] = list(seen.values())
    return found


def write_review(catalogue: list[dict[str, Any]], path: Path) -> None:
    """A markdown sheet for the owner: every label, the phrase behind it, and the prose."""
    lines = [
        "# Habitat classification — review sheet",
        "",
        "Generated by `Tools/classify_habitats.py --review`. Every label is derived from that",
        "entry's own `habitat` prose and nothing else; **Evidence** is the literal text that",
        "matched. A wrong label is a rule to fix in the tool, not a value to edit here — the",
        "file is regenerated on every run.",
        "",
    ]

    def section(title: str, entries: list[dict[str, Any]], note: str) -> None:
        lines.extend([f"## {title} ({len(entries)})", "", note, ""])
        for entry in entries:
            text = entry["habitat"]["text"].strip()
            found = evidence(text)
            credit = entry["habitat"]["sources"]
            lines.append(f"### {entry['commonName']} — `{entry['id']}`")
            lines.append("")
            lines.append(f"- **Labels:** {', '.join(found) if found else '_none_'}")
            for habitat, words in found.items():
                lines.append(f"    - `{habitat}` ← {', '.join(repr(w) for w in words)}")
            lines.append(f"- **Prose:** {text or '_empty_'}")
            lines.append(f"- **Credit:** {'; '.join(credit) if credit else '_yours, uncredited_'}")
            lines.append("")

    shipped = [e for e in catalogue if not e.get("draft")]
    drafts = [e for e in catalogue if e.get("draft")]
    section(
        "Shipped entries",
        sorted(shipped, key=lambda e: str(e["commonName"])),
        "These are the ones the app actually shows. Worth reading all of them.",
    )
    unmatched = [e for e in drafts if e["habitat"]["text"].strip() and not e["habitats"]]
    section(
        "Drafts whose prose earned no label",
        sorted(unmatched, key=lambda e: str(e["commonName"])),
        "Their `habitat` field is really a distribution section — a native range, not a place "
        "to look. These need a habitat statement before they can be classified.",
    )
    classified_drafts = [e for e in drafts if e["habitats"]]
    section(
        "Classified drafts",
        sorted(classified_drafts, key=lambda e: str(e["commonName"])),
        "Prose copied from Wikipedia or Flora of NZ, so the geography may be the species' "
        "global range rather than its New Zealand one. Lower confidence than the shipped set.",
    )
    path.write_text("\n".join(lines))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    parser.add_argument("--write", action="store_true")
    parser.add_argument(
        "--review",
        type=Path,
        nargs="?",
        const=Path("docs/habitat-review.md"),
        help="Write a markdown review sheet showing the evidence behind every label.",
    )
    args = parser.parse_args(argv)

    catalogue: list[dict[str, Any]] = json.loads(args.catalogue.read_text())
    counts = dict.fromkeys(HABITATS, 0)
    unclassified: list[str] = []
    no_prose: list[str] = []

    for entry in catalogue:
        text = entry["habitat"]["text"]
        habitats = classify(text)
        entry["habitats"] = habitats
        for habitat in habitats:
            counts[habitat] += 1
        if habitats:
            continue
        (no_prose if not text.strip() else unclassified).append(entry["id"])

    classified = len(catalogue) - len(unclassified) - len(no_prose)
    print(f"{classified} of {len(catalogue)} entries classified")
    for habitat, count in counts.items():
        print(f"    {count:4d}  {habitat}")
    print(f"{len(no_prose)} entries have no habitat prose to classify from")
    print(f"{len(unclassified)} entries have prose that matched no rule")
    for name in unclassified:
        print(f"    {name}")
    if args.write:
        args.catalogue.write_text(json.dumps(catalogue, ensure_ascii=False, indent=2) + "\n")
    if args.review:
        write_review(catalogue, args.review)
        print(f"Review sheet written to {args.review}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
