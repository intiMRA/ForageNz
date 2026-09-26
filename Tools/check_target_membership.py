#!/usr/bin/env python3
"""Catch the one hazard of compiling the catalogue model two ways.

`ForageNZ/Catalogue/Model` is built both by SwiftPM (for `catalogue-tool` and the fast model
tests) and by Xcode (as source files of ForageNZ and CatalogueEditor). SwiftPM finds sources
by globbing the directory; Xcode only compiles what a target's build phase lists. Add a file
and forget the membership and `swift test` goes green while the apps fail to build — or worse,
only the editor fails, hours later.

Run it, or let `Tools/tests/test_target_membership.py` run it.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MODEL_DIR = Path("ForageNZ/Catalogue/Model")
PROJECT = Path("ForageNZ.xcodeproj/project.pbxproj")
#: Every target that has to compile the model.
EXPECTED_TARGETS = 2

FILE_REF = re.compile(
    r"^\t*([0-9A-F]{24}) /\* .* \*/ = \{isa = PBXFileReference;.*? path = (\S+);", re.M
)
BUILD_FILE = re.compile(
    r"^\t*([0-9A-F]{24}) /\* .* \*/ = \{isa = PBXBuildFile; fileRef = ([0-9A-F]{24})", re.M
)


def sources_phases(text: str) -> list[set[str]]:
    """The build-file ids listed in each PBXSourcesBuildPhase."""
    phases, current = [], None
    for line in text.split("\n"):
        if "isa = PBXSourcesBuildPhase;" in line:
            current = set()
        elif current is not None:
            match = re.match(r"^\t*([0-9A-F]{24}) /\* .* in Sources \*/,", line)
            if match:
                current.add(match.group(1))
            elif line.strip() == "};":
                phases.append(current)
                current = None
    return phases


def find_drift() -> list[str]:
    if not MODEL_DIR.is_dir() or not PROJECT.is_file():
        return [f"run me from the repo root: {MODEL_DIR} or {PROJECT} is missing"]

    text = PROJECT.read_text()
    on_disk = {
        str(path.relative_to("ForageNZ")) for path in MODEL_DIR.rglob("*.swift")
    }
    refs = {path: ref for ref, path in FILE_REF.findall(text)}
    builds: dict[str, list[str]] = {}
    for build, ref in BUILD_FILE.findall(text):
        builds.setdefault(ref, []).append(build)
    phases = sources_phases(text)

    problems = []
    for path in sorted(on_disk):
        ref = refs.get(path)
        if ref is None:
            problems.append(f"{path} is on disk but no target compiles it")
            continue
        compiled_by = sum(
            1 for phase in phases if phase & set(builds.get(ref, []))
        )
        if compiled_by != EXPECTED_TARGETS:
            problems.append(
                f"{path} is compiled by {compiled_by} target(s), expected {EXPECTED_TARGETS}"
            )

    for path, ref in refs.items():
        if path.startswith("Catalogue/Model/") and path not in on_disk:
            problems.append(f"{path} is in the project but not on disk")

    return problems


def main() -> int:
    problems = find_drift()
    for problem in problems:
        print(f"target membership: {problem}", file=sys.stderr)
    if problems:
        print(
            "\nAdd the file to both ForageNZ and CatalogueEditor in Xcode's File Inspector,"
            "\nor remove it from the project if it is gone.",
            file=sys.stderr,
        )
        return 1
    print(f"target membership: every model source is compiled by {EXPECTED_TARGETS} targets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
