"""Check every scientific name in the catalogue against NZOR, and report what is wrong.

Three questions per entry, answered by the New Zealand Organisms Register:

  - **Is it a name at all?** A name NZOR has never heard of is either a typo or, in an entry
    built from a scanned book, a species that never existed.
  - **Is it current?** NZOR names the accepted name when yours is a synonym.
  - **Is it recorded in New Zealand?** A biostatus is what says so, and supplies the origin.

The catalogue is never written to. A name is a judgement call — `Pyropia / Porphyra spp.`
is a deliberate choice, not an error — so this reports and leaves the deciding to you.

    python Tools/audit_names.py                 # the whole catalogue
    python Tools/audit_names.py --drafts-only
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Any

from enrich_catalogue import fetch_inat_taxon, fetch_nzor
from sources import CATALOGUE, COURTESY_DELAY

#: A genus-level or higher name: `Suillus spp.`, `Boletaceae`. NZOR holds these, but a
#: biostatus and an accepted-name check only mean something for a species.
ABOVE_SPECIES = re.compile(r"\bspp?\.|\b[A-Z]\w+(?:aceae|ales)\b")


class Verdict(StrEnum):
    OK = "ok"
    UNKNOWN = "not a name NZOR knows"
    SYNONYM = "a synonym; NZOR prefers another name"
    NOT_IN_NZ = "no New Zealand biostatus"
    ALTERNATIVES = "several names in one field"


@dataclass(frozen=True)
class Finding:
    species_id: str
    name: str
    verdict: Verdict
    detail: str
    draft: bool


def names_in(field: str) -> list[str]:
    """The distinct names an entry's `scientificName` mentions.

    Some entries deliberately name two taxa (`Urtica dioica / Urtica urens`) or add a
    parenthesised synonym; each name is checked, the field is not rewritten.
    """
    # A parenthesis holding no capitalised word is a note about the name, not a name.
    without_notes = re.sub(r"\((?![^)]*[A-Z])[^)]*\)|\((?:syn\.|and other)[^)]*\)", " ", field)
    parts = re.split(r"\s*/\s*|\s*\(|\)\s*", without_notes)
    return [part.strip() for part in parts if part.strip()]


def check(name: str) -> tuple[Verdict, str]:
    record = fetch_nzor(name)
    time.sleep(COURTESY_DELAY)
    if record is None:
        # iNaturalist knows names NZOR does not, which separates "typo" from "real species
        # NZOR happens not to list".
        taxon = fetch_inat_taxon(name)
        time.sleep(COURTESY_DELAY)
        detail = (
            f"iNaturalist has it as {taxon.scientific_name}"
            if taxon
            else "iNaturalist has no such taxon either"
        )
        return Verdict.UNKNOWN, detail

    accepted = (record.accepted_name or "").strip()
    if accepted and accepted.lower() != name.lower():
        return Verdict.SYNONYM, f"NZOR accepts {accepted}"
    if not record.origins and not ABOVE_SPECIES.search(name):
        return Verdict.NOT_IN_NZ, f"status {record.status or 'unknown'}"
    return Verdict.OK, ""


def audit(catalogue: list[dict[str, Any]], drafts_only: bool) -> list[Finding]:
    findings: list[Finding] = []
    entries = [e for e in catalogue if e.get("draft")] if drafts_only else catalogue
    for index, entry in enumerate(entries, start=1):
        field = str(entry["scientificName"])
        names = names_in(field)
        if len(names) > 1:
            findings.append(
                Finding(
                    entry["id"],
                    field,
                    Verdict.ALTERNATIVES,
                    f"checking {len(names)}",
                    bool(entry.get("draft")),
                )
            )
        for name in names:
            verdict, detail = check(name)
            if verdict is not Verdict.OK:
                findings.append(
                    Finding(entry["id"], name, verdict, detail, bool(entry.get("draft")))
                )
        if index % 25 == 0:
            print(f"  {index}/{len(entries)} checked", file=sys.stderr)
    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    parser.add_argument("--drafts-only", action="store_true")
    args = parser.parse_args(argv)

    catalogue: list[dict[str, Any]] = json.loads(args.catalogue.read_text())
    findings = audit(catalogue, args.drafts_only)

    for verdict in Verdict:
        if verdict is Verdict.OK:
            continue
        group = [f for f in findings if f.verdict is verdict]
        if not group:
            continue
        print(f"\n{verdict.value} ({len(group)}):")
        for finding in group:
            mark = "draft" if finding.draft else "SHIPPED"
            print(f"  [{mark}] {finding.species_id}: {finding.name} — {finding.detail}")

    checked = len([e for e in catalogue if e.get("draft")]) if args.drafts_only else len(catalogue)
    problems = [f for f in findings if f.verdict is not Verdict.ALTERNATIVES]
    print(f"\n{checked} entries checked, {len(problems)} to look at")
    return 0


if __name__ == "__main__":
    sys.exit(main())
