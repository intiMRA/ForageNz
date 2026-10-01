#!/usr/bin/env python3
"""Stage openly-licensed iNaturalist photos for catalogue entries that have none.

Unlike `fetch_eval_photos.py`, which builds throwaway test data, everything this writes is
*candidate catalogue content*: New Zealand research-grade observations, CC0 or CC BY only,
encoded to the catalogue's own HEIC settings so what you review is what would ship.

It deliberately stops short of shipping them. A catalogue photo needs a caption naming the
feature it shows, and choosing which frames to keep is a judgement no query makes:

  - The liberty-cap pass rejected a phylogenetic tree diagram the API served as a "photo",
    and two frames of expanded convex caps that contradicted the entry's own
    "sharply conical" text.
  - The weraroa pass rejected the richest CC0 observation outright because it was shot on a
    mown lawn, and weraroa is a forest species on rotting wood.

A photo that argues against the identification prose is worse than no photo. So the default
run downloads and encodes into a staging directory with a manifest, and a human picks. With
`--write` the survivors are attached to the catalogue with **blank captions**, which is a
blocking validation issue until someone writes them — that is the point, not an oversight.

    python3 Tools/fetch_catalogue_photos.py --limit 5
    python3 Tools/fetch_catalogue_photos.py --only weraroa,puha
    python3 Tools/fetch_catalogue_photos.py --only puha --write

No run re-offers a frame a reviewer has already seen: the staging manifests record which
iNaturalist photo each candidate was, and kept, discarded and still-waiting frames are all
skipped. Observations tying on agreeing identifications are ordered at random, so two runs
over the same pool shortlist different specimens.

By default only entries with *no* photos are considered, so an entry that came out of review
short of its target is stuck there. `--top-up` includes those, asks for the shortfall, and
excludes the observations its existing photos already came from:

    python3 Tools/fetch_catalogue_photos.py --only psilocybe-aucklandiae --top-up

Entries with no acceptable photos are reported and skipped, never half-filled.
"""

from __future__ import annotations

import argparse
import json
import random
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from sources import (
    CATALOGUE,
    COURTESY_DELAY,
    Licence,
    Source,
    SourceError,
    download,
    results_of,
)

#: iNaturalist's place id for New Zealand. A research-grade observation from California says
#: nothing about what the species looks like in a NZ gully, and the catalogue's habitat prose
#: is NZ-specific — see the porcini finding in the habitat work.
NEW_ZEALAND_PLACE_ID = 6803

#: Where the Swift constants live. Parsed rather than copied so the encoder and the budget
#: cannot drift from what the app and `catalogue-tool --check` enforce.
PHOTO_CONSTANTS = (
    Path(__file__).resolve().parent.parent
    / "ForageNZ"
    / "Catalogue"
    / "Model"
    / "SpeciesPhoto.swift"
)

PHOTO_DIRECTORY = CATALOGUE.parent / "Photos"

#: How many candidates to fetch per photo actually wanted. Rejection is the normal case, not
#: the exception: liberty-cap kept 6 of 14 and weraroa 6 of 25.
#:
#: Raised from 3 after measuring the first staged batch, where the real keep rate was about a
#: half rather than the third this assumed — blackberry kept 2 of 4 (one blurred, one
#: mildewed), puha 1 of 4, nettle 4 of 6. At 3 an entry routinely finishes short, and topping
#: it up means a second trip to the network for the frames the first pass already ranked
#: below the ones it took.
CANDIDATE_MULTIPLIER = 6

#: Never take more than this many frames from one observation when others are available.
#: Four photos of one specimen from four angles teach less than four specimens, and a single
#: misidentified observation would otherwise supply an entry's whole photo set.
MAX_PER_OBSERVATION = 2


class PhotoConstants:
    """The catalogue's photo rules, read from the Swift source."""

    def __init__(self, swift: str) -> None:
        self.maximum_pixel_size = _swift_int(swift, "maximumPixelSize")
        self.maximum_bytes_per_photo = _swift_int(swift, "maximumBytesPerPhoto")
        self.total_byte_budget = _swift_int(swift, "totalByteBudget")
        self.compression_quality = _swift_float(swift, "compressionQuality")

    @classmethod
    def load(cls, path: Path = PHOTO_CONSTANTS) -> PhotoConstants:
        return cls(path.read_text())


def _swift_int(swift: str, name: str) -> int:
    match = re.search(rf"let {name} = ([0-9_]+)", swift)
    if not match:
        raise SystemExit(f"{name} not found in {PHOTO_CONSTANTS.name} — did it get renamed?")
    return int(match.group(1).replace("_", ""))


def _swift_float(swift: str, name: str) -> float:
    match = re.search(rf"let {name} = ([0-9.]+)", swift)
    if not match:
        raise SystemExit(f"{name} not found in {PHOTO_CONSTANTS.name} — did it get renamed?")
    return float(match.group(1))


def wanted_count(entry: dict[str, Any]) -> int:
    """Mirrors `CataloguePhotos.recommendedCount`: 6 with a deadly lookalike, else 4.

    Not a flat number, because the entries that need the most evidence are exactly the ones
    where being wrong is worst. Kept in sync by `test_wanted_count_matches_swift`.
    """
    deadly = any(
        lookalike.get("risk") == "deadly" for lookalike in entry.get("lookalikes") or []
    )
    return 6 if deadly else 4


def shortfall(entry: dict[str, Any], target: int) -> int:
    """How many more photos this entry wants."""
    return max(target - len(entry.get("photos") or []), 0)


def already_used_observations(entry: dict[str, Any]) -> set[str]:
    """Observation URLs the entry's existing photos already came from.

    A top-up that re-offered the frames a reviewer kept last time would waste the trip and,
    worse, invite a second frame of the same specimen into a set whose whole value is that it
    spreads across specimens.
    """
    return {
        str(photo.get("sourceURL"))
        for photo in entry.get("photos") or []
        if photo.get("sourceURL")
    }


def previously_offered(species_id: str, staging: Path) -> tuple[frozenset[int], frozenset[str]]:
    """Photo ids and observation URLs this entry has already been shown, from the manifests.

    Keeping a photo is not the only verdict worth remembering: a reviewer who discarded a
    frame has judged it, and re-downloading it next time they press Fetch more… spends a trip
    to the network to ask the same question again. Because selection ranks by agreeing
    identifications, the frames that come back are exactly the ones already seen — which is
    what made a second fetch look like it did nothing.

    Reads every JSON in the staging root: the September runs left `retry.json` … `retry5.json`
    beside the `manifest<N>.json` files, and a frame recorded only in those is still a frame
    the reviewer has seen. `photoID` is only in manifests written after this, so older entries
    fall back to their observation URL — coarser, but it is the signal they carry.
    """
    photo_ids: set[int] = set()
    observations: set[str] = set()
    for path in sorted(staging.glob("*.json")):
        try:
            decoded = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(decoded, dict):
            continue
        for photo in decoded.get(species_id) or []:
            if (photo_id := photo.get("photoID")) is not None:
                photo_ids.add(int(photo_id))
            elif source := photo.get("sourceURL"):
                observations.add(str(source))
    return frozenset(photo_ids), frozenset(observations)


def query_names(scientific_name: str) -> list[str]:
    """Names to search iNaturalist for, in order of preference.

    Three shapes in the catalogue need handling. A compound name ("Urtica dioica / Urtica
    urens") is two real species and both are searched. A genus page ("Coprosma spp.") is
    searched at genus rank — iNaturalist has no "spp." taxon, and dropping the suffix is the
    only way to get anything at all. And a qualified group ("Boletaceae (red-pored)") carries
    an English qualifier in brackets that no taxon name contains; leaving it in silently
    returns nothing, which reads as "no photos exist" when the truth is "we asked badly".

    Note what this cannot fix: a family-level query returns photos of the family, so anything
    it stages for such an entry is a picture of *something in that group*, not of the entry.
    Those need a human to choose, which is what the staging step is for.
    """
    names: list[str] = []
    for part in scientific_name.split("/"):
        name = re.sub(r"\([^)]*\)", " ", part)
        name = re.sub(r"\bspp?\.", " ", name)
        name = " ".join(name.split())
        if name and name not in names:
            names.append(name)
    return names


def agreeing_identifications(observation: dict[str, Any]) -> int:
    """How many identifiers landed on the observation's own taxon.

    The single best cheap signal that a photo shows what it claims to. The weraroa set came
    from observations with 5 to 15 agreeing identifications; the liberty-cap set included one
    posted as *Mycena* by its own observer and corrected by six people.
    """
    taxon_id = (observation.get("taxon") or {}).get("id")
    if taxon_id is None:
        return 0
    return sum(
        1
        for identification in observation.get("identifications") or []
        if (identification.get("taxon") or {}).get("id") == taxon_id
    )


@dataclass(frozen=True)
class Candidate:
    species_id: str
    observation_id: int
    photo_id: int
    licence: str
    attribution: str
    observation_url: str
    place: str
    observed_on: str
    agreeing: int
    url: str


def has_unrestricted_photo(observation: dict[str, Any]) -> bool:
    """Whether any of an observation's photos is CC0 or CC BY rather than CC BY-NC."""
    for photo in observation.get("photos") or []:
        try:
            if Licence(photo.get("license_code")).is_unrestricted:
                return True
        except ValueError:
            continue
    return False


def observations_for(name: str, wanted: int) -> list[dict[str, Any]]:
    """NZ research-grade observations carrying a licence permissive enough to ship."""
    return results_of(
        Source.INAT_OBSERVATIONS,
        {
            "taxon_name": name,
            "quality_grade": "research",
            "photo_license": Licence.query_value(),
            "place_id": NEW_ZEALAND_PLACE_ID,
            "per_page": min(wanted * CANDIDATE_MULTIPLIER * 2, 60),
            "order_by": "votes",
        },
    )


def select_candidates(
    species_id: str,
    observations: list[dict[str, Any]],
    wanted: int,
    max_per_observation: int = MAX_PER_OBSERVATION,
    skip_photo_ids: frozenset[int] = frozenset(),
    rng: random.Random | None = None,
) -> list[Candidate]:
    """Best-identified observations first, spread across as many of them as possible.

    Takes one photo from each observation before taking a second from any, so a shortlist of
    four covers four specimens rather than four angles on one — and so a single wrong
    identification cannot supply the whole set.

    Observations carrying a commercially-unrestricted photo (CC0 or CC BY) are taken before
    CC BY-NC ones, and unrestricted frames come first within an observation. NC is admitted
    because the app will be free, but every NC photo is one that would have to be stripped if
    that ever changed, so the fallback order keeps that set as small as the pool allows. This
    tier sits *above* the identification ranking deliberately: licence is a hard constraint on
    what may ship at all, where agreeing identifications are evidence about what the frame
    shows.

    Observations on the same number of agreeing identifications are ordered at random, so two
    runs over the same pool do not shortlist the same specimens. The ranking itself is not
    randomised: a frame five identifiers agreed on is better evidence than one nobody
    seconded, and shuffling that away to gain variety would trade the thing the shortlist is
    for. Common species are where duplicates were worst and where the ties are, so the
    tiebreak is where the variety is worth having.

    `max_per_observation` is raised only by the top-up fallback, for the case the cap's own
    rule already allows for: there are no *other* observations to spread across.
    """
    rng = rng or random.Random()
    ranked = sorted(
        observations,
        key=lambda o: (has_unrestricted_photo(o), agreeing_identifications(o), rng.random()),
        reverse=True,
    )
    by_observation: list[list[Candidate]] = []
    for observation in ranked:
        frames: list[Candidate] = []
        for photo in observation.get("photos") or []:
            try:
                licence = Licence(photo.get("license_code"))
            except ValueError:
                continue
            url = str(photo.get("url") or "")
            if not url:
                continue
            if int(photo.get("id") or 0) in skip_photo_ids:
                continue
            frames.append(
                Candidate(
                    species_id=species_id,
                    observation_id=int(observation.get("id") or 0),
                    photo_id=int(photo.get("id") or 0),
                    licence=str(licence),
                    attribution=str(photo.get("attribution") or ""),
                    observation_url=str(observation.get("uri") or ""),
                    place=str(observation.get("place_guess") or ""),
                    observed_on=str(observation.get("observed_on_string") or ""),
                    agreeing=agreeing_identifications(observation),
                    # `square.` is a thumbnail; `large.` is what survives the 1400px encode.
                    url=url.replace("square.", "large."),
                )
            )
        if frames:
            # Unrestricted frames first, so a mixed-licence observation gives up its CC BY
            # photo before its CC BY-NC one. `sorted` is stable, so frame order is otherwise
            # the observation's own.
            frames.sort(key=lambda frame: not Licence(frame.licence).is_unrestricted)
            by_observation.append(frames[:max_per_observation])

    selected: list[Candidate] = []
    for depth in range(max_per_observation):
        for frames in by_observation:
            if len(selected) >= wanted:
                return selected
            if depth < len(frames):
                selected.append(frames[depth])
    return selected


def encode(source: Path, destination: Path, constants: PhotoConstants) -> int:
    """Re-encode to the catalogue's HEIC settings, stepping quality down to fit the ceiling.

    Steps down rather than accepting an oversized file, because the alternative is shipping a
    reject: one weraroa frame landed 250 KB over at the default quality and is fine at 56.
    Returns the file size in bytes, or 0 if `sips` produced nothing usable.
    """
    quality = int(constants.compression_quality * 100)
    while quality >= 30:
        subprocess.run(
            [
                "sips", "-s", "format", "heic",
                "-s", "formatOptions", str(quality),
                "-Z", str(constants.maximum_pixel_size),
                str(source), "--out", str(destination),
            ],
            check=False,
            capture_output=True,
        )
        if not destination.exists():
            return 0
        size = destination.stat().st_size
        if size <= constants.maximum_bytes_per_photo:
            return size
        quality -= 6
    return destination.stat().st_size if destination.exists() else 0


def catalogue_bytes(directory: Path = PHOTO_DIRECTORY) -> int:
    return sum(path.stat().st_size for path in directory.glob("*") if path.is_file())


@dataclass
class Staged:
    species_id: str
    photos: list[dict[str, Any]] = field(default_factory=list)
    note: str = ""


def stage(
    entry: dict[str, Any],
    staging: Path,
    constants: PhotoConstants,
    wanted: int,
    exclude_observations: frozenset[str] = frozenset(),
) -> Staged:
    species_id = str(entry["id"])
    result = Staged(species_id=species_id)
    shipped = shipped_photo_bytes(species_id)
    seen_photo_ids, seen_observations = previously_offered(species_id, staging)
    # Anything a reviewer has already been shown is excluded whether they kept it or not, so
    # pressing Fetch more… twice reaches further down the pool instead of re-offering the top.
    excluded = exclude_observations | seen_observations

    candidates: list[Candidate] = []
    for name in query_names(str(entry["scientificName"])):
        try:
            found = observations_for(name, wanted)
        except SourceError as error:
            result.note = f"query failed ({error})"
            return result
        unused = [
            observation
            for observation in found
            if str(observation.get("uri") or "") not in excluded
        ]
        candidates = select_candidates(
            species_id, unused, wanted, skip_photo_ids=seen_photo_ids
        )

        # Nothing left to spread across. The cap says "when others are available", and here
        # there are none: an observation already used may hold frames nobody has been shown —
        # Stirling's aucklandiae observation carries eight and had offered two. Going deeper
        # into it beats telling a reviewer no photos exist when seven do.
        if excluded and len(candidates) < wanted:
            # Ask for the shortfall *plus* what is already shipped. Selection walks the
            # observations breadth-first, so the frames a previous run took come back first
            # and are dropped by the byte check below; without the extra depth the pass
            # returns only those and stages nothing new.
            reach = wanted - len(candidates) + len(shipped)
            candidates += select_candidates(
                species_id,
                found,
                reach,
                max_per_observation=reach,
                skip_photo_ids=seen_photo_ids | frozenset(
                    candidate.photo_id for candidate in candidates
                ),
            )
        if candidates:
            break
        time.sleep(COURTESY_DELAY)

    if not candidates:
        # Expected for NZ endemics with few observers, and for genus pages. Left for a human
        # rather than filled from a looser query. The two cases read identically to a user and
        # are not the same problem: one says look elsewhere, the other says you have already
        # seen everything this query can offer and discarded it.
        result.note = (
            "every shippable NZ research-grade photo has already been offered"
            if seen_photo_ids or seen_observations
            else "no NZ research-grade photos under an accepted licence"
        )
        return result

    # One directory per species, matching the layout the September staging runs already use
    # in `.staged-photos/`. A flat dump would interleave with those and make it impossible to
    # see which batch a loose file belonged to.
    directory = staging / species_id
    directory.mkdir(parents=True, exist_ok=True)
    # Numbering continues past whatever is already staged, so a top-up run adds to the tray
    # instead of overwriting candidates a reviewer has not got to yet.
    for index, candidate in enumerate(candidates, start=next_index(directory, species_id)):
        original = directory / f"{species_id}-{index}.jpg"
        if not download(candidate.url, original):
            print(f"    download failed: {candidate.url}", file=sys.stderr)
            continue
        encoded = directory / f"{species_id}-{index}.heic"
        size = encode(original, encoded, constants)
        original.unlink(missing_ok=True)
        if not size:
            print(f"    encode failed: {candidate.photo_id}", file=sys.stderr)
            continue
        # A deeper pass can reach a frame that is already shipped: the catalogue records which
        # observation a photo came from, not which frame of it. Same source and same encoder
        # means identical bytes, so the file itself is the check. Staged files are checked the
        # same way, which catches what `previously_offered` cannot — the frames staged before
        # manifests recorded a `photoID`.
        if encoded.read_bytes() in shipped or is_duplicate_of_staged(encoded, directory):
            encoded.unlink(missing_ok=True)
            continue
        result.photos.append(
            {
                "fileName": encoded.name,
                "photoID": candidate.photo_id,
                "caption": "",
                "credit": candidate.attribution,
                "sourceURL": candidate.observation_url,
                "bytes": size,
                "agreeingIdentifications": candidate.agreeing,
                "place": candidate.place,
                "observedOn": candidate.observed_on,
                "licence": candidate.licence,
            }
        )
        time.sleep(COURTESY_DELAY)
    return result


def is_duplicate_of_staged(encoded: Path, directory: Path) -> bool:
    """Whether a freshly staged file repeats one already waiting in the same tray.

    Compares sizes first: the tray for a well-covered entry holds a couple of dozen files, and
    two encodes of different frames almost never land on the same byte count.
    """
    size = encoded.stat().st_size
    return any(
        path != encoded
        and path.stat().st_size == size
        and path.read_bytes() == encoded.read_bytes()
        for path in directory.glob("*.heic")
    )


def shipped_photo_bytes(species_id: str) -> set[bytes]:
    """The contents of this entry's photos that are already in the catalogue."""
    return {
        path.read_bytes()
        for path in PHOTO_DIRECTORY.glob(f"{species_id}-*.heic")
        if path.is_file()
    }


def next_index(directory: Path, species_id: str) -> int:
    """First `<species>-N` number free in a staging directory."""
    used = [
        int(match.group(1))
        for path in directory.glob(f"{species_id}-*")
        if (match := re.fullmatch(rf"{re.escape(species_id)}-(\d+)", path.stem))
    ]
    return max(used, default=0) + 1


def next_manifest(staging: Path) -> Path:
    """A manifest name no previous run is using.

    Never overwrites: a staged manifest is where the hand-written captions live before they
    reach the catalogue, and the September runs left five of them (`manifest.json`,
    `retry.json` … `retry5.json`) beside the photos they describe. Clobbering one would throw
    away review, not just a download.
    """
    if not (staging / "manifest.json").exists():
        return staging / "manifest.json"
    index = 2
    while (staging / f"manifest{index}.json").exists():
        index += 1
    return staging / f"manifest{index}.json"


def catalogue_photo(staged_photo: dict[str, Any]) -> dict[str, Any]:
    """The four fields `SpeciesPhoto` decodes, dropping the review-only metadata."""
    return {
        "caption": staged_photo["caption"],
        "credit": staged_photo["credit"],
        "fileName": staged_photo["fileName"],
        "sourceURL": staged_photo["sourceURL"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--catalogue", type=Path, default=CATALOGUE)
    parser.add_argument(
        "--staging",
        type=Path,
        default=Path(".staged-photos"),
        help="where encoded candidates land for review (gitignored)",
    )
    parser.add_argument("--only", default="", help="comma-separated ids to limit the run")
    parser.add_argument("--limit", type=int, default=0, help="stop after N entries")
    parser.add_argument(
        "--per-species",
        type=int,
        default=0,
        help="override the 4/6 recommended count (6 applies to deadly-lookalike entries)",
    )
    parser.add_argument(
        "--top-up",
        action="store_true",
        help="also take entries that already have photos but are below their target, staging "
        "only the shortfall and skipping observations they already use",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="move survivors into Photos/ and attach them with BLANK captions, which block "
        "validation until a human writes them",
    )
    arguments = parser.parse_args(argv)

    constants = PhotoConstants.load()
    entries: list[dict[str, Any]] = json.loads(arguments.catalogue.read_text())
    only = {part.strip() for part in arguments.only.split(",") if part.strip()}

    def target_for(entry: dict[str, Any]) -> int:
        return arguments.per_species or wanted_count(entry)

    todo = [
        entry for entry in entries
        if shortfall(entry, target_for(entry)) > 0
    ] if arguments.top_up else [entry for entry in entries if not entry.get("photos")]
    if only:
        todo = [entry for entry in todo if entry["id"] in only]
    if arguments.limit:
        todo = todo[: arguments.limit]

    # `totalByteBudget` governs what SHIPS, and staged files do not ship: they sit outside any
    # Xcode target, about half are rejected at review, and the survivors are attached one entry
    # at a time as drafts are promoted. Charging downloads against it stopped an earlier run at
    # 233 of 279 entries for no reason — and the figure it compared was arbitrary anyway, since
    # `catalogue_bytes()` counts only the shipped folder and ignored the 110 MB already staged.
    # The real guard against overshooting the budget is `PhotoAudit`, which reads what shipped.
    shipped = catalogue_bytes()
    print(
        f"{len(todo)} entr{'y' if len(todo) == 1 else 'ies'} "
        f"{'below their photo target' if arguments.top_up else 'with no photos'} · "
        f"catalogue is {shipped / 1e6:.1f} MB of the {constants.total_byte_budget / 1e6:.0f} MB "
        "ship budget (staging is not charged against it)"
    )

    staged: list[Staged] = []
    empty: list[str] = []
    for entry in todo:
        target = target_for(entry)
        wanted = shortfall(entry, target) if arguments.top_up else target
        result = stage(
            entry,
            arguments.staging,
            constants,
            wanted,
            exclude_observations=frozenset(already_used_observations(entry))
            if arguments.top_up else frozenset(),
        )
        if result.photos:
            staged.append(result)
            print(f"  {result.species_id}: {len(result.photos)} of {wanted} staged")
        else:
            empty.append(f"{result.species_id} ({result.note})")
            print(f"  {result.species_id}: {result.note}")

    manifest = next_manifest(arguments.staging)
    if staged:
        arguments.staging.mkdir(parents=True, exist_ok=True)
        manifest.write_text(
            json.dumps(
                {result.species_id: result.photos for result in staged},
                indent=2,
                ensure_ascii=False,
            )
        )
        print(f"\nManifest written to {manifest}")

    if empty:
        print(f"\n{len(empty)} entr{'y' if len(empty) == 1 else 'ies'} with nothing usable:")
        for line in empty:
            print(f"  {line}")

    if not arguments.write:
        print(
            "\nReview the staged files before shipping any of them, then re-run with --write.\n"
            "Reject any frame that contradicts the entry's own identification or habitat prose."
        )
        return 0

    by_id = {result.species_id: result for result in staged}
    PHOTO_DIRECTORY.mkdir(parents=True, exist_ok=True)
    for entry in entries:
        result = by_id.get(str(entry["id"]))
        if not result:
            continue
        for photo in result.photos:
            # Re-encode rather than move, so the pixel size in `SpeciesPhoto.swift` is what
            # governs at SHIP time, not whenever the file happened to be staged. The pool holds
            # files from several runs — 942 of them are 1400 px from before the drop to 1000 —
            # and re-downloading to pick up a constant change would be hours of courtesy delays
            # for a downscale `sips` can do locally. It is a second lossy generation, but the
            # downscale discards more than the re-compression adds, and `encode` still steps
            # quality down to hold `maximumBytesPerPhoto`.
            # The staged file is left where it is rather than moved away. It is the only
            # surviving copy at the original resolution — the downloads are deleted after
            # staging — so keeping it is what lets a later `maximumPixelSize` change be
            # re-applied with another `--write` instead of another night of downloads.
            source = arguments.staging / result.species_id / photo["fileName"]
            destination = PHOTO_DIRECTORY / photo["fileName"]
            if not encode(source, destination, constants):
                print(f"    re-encode failed, copying as-is: {photo['fileName']}", file=sys.stderr)
                shutil.copyfile(source, destination)
        entry["photos"] = [catalogue_photo(photo) for photo in result.photos]

    arguments.catalogue.write_text(
        json.dumps(entries, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    )
    # Checked here and not before the loop, because `photo["bytes"]` is the STAGED size and the
    # write re-encodes: at the current constants a staged file is ~2× what ships, so a
    # pre-flight check would refuse writes that comfortably fit. This reads what is actually on
    # disk. It reports rather than fails — the files are already written, so the useful output
    # is the number, and `catalogue-tool --photos` is the gate that blocks on it.
    total = catalogue_bytes()
    budget = constants.total_byte_budget
    print(
        f"\nAttached photos to {len(by_id)} entries with blank captions.\n"
        f"Catalogue photos now {total / 1e6:.1f} MB of the {budget / 1e6:.0f} MB budget."
    )
    if total > budget:
        print(
            f"OVER BUDGET by {(total - budget) / 1e6:.1f} MB. Lower "
            "`CataloguePhotos.maximumPixelSize` and re-run --write; bytes scale with pixel "
            "count, and the staged originals are still on disk.",
            file=sys.stderr,
        )
    print("Write a caption for each, then run `swift run catalogue-tool --normalise`.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
