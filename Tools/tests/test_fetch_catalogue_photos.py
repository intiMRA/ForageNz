"""Photo staging picks well-identified, spread-out candidates and never invents a caption."""

from __future__ import annotations

import json
import random
import re
from pathlib import Path
from typing import Any

from fetch_catalogue_photos import (
    MAX_PER_OBSERVATION,
    PHOTO_CONSTANTS,
    PhotoConstants,
    agreeing_identifications,
    already_used_observations,
    catalogue_photo,
    next_index,
    next_manifest,
    previously_offered,
    query_names,
    select_candidates,
    shortfall,
    wanted_count,
)

SWIFT_MODEL = Path(__file__).resolve().parents[2] / "ForageNZ" / "Catalogue" / "Model"


def observation(
    observation_id: int, taxon_id: int, agreeing: int, photos: int, licence: str = "cc-by"
) -> dict[str, Any]:
    return {
        "id": observation_id,
        "uri": f"https://www.inaturalist.org/observations/{observation_id}",
        "taxon": {"id": taxon_id},
        "identifications": [{"taxon": {"id": taxon_id}} for _ in range(agreeing)],
        "photos": [
            {"id": observation_id * 100 + index, "license_code": licence,
             "url": f"https://example.test/{observation_id}-{index}square.jpg",
             "attribution": f"(c) Observer {observation_id}"}
            for index in range(photos)
        ],
    }


def test_wanted_count_follows_the_deadly_lookalike_rule() -> None:
    assert wanted_count({"lookalikes": []}) == 4
    assert wanted_count({"lookalikes": [{"risk": "toxic"}]}) == 4
    assert wanted_count({"lookalikes": [{"risk": "toxic"}, {"risk": "deadly"}]}) == 6


def test_wanted_count_matches_the_swift_recommendation() -> None:
    """The Python must not drift from `CataloguePhotos.recommendedCount`."""
    swift = (SWIFT_MODEL / "SpeciesPhoto.swift").read_text()
    match = re.search(r"hasDeadlyLookalike \? (\d+) : (\d+)", swift)
    assert match, "recommendedCount changed shape — update this test and wanted_count together"
    assert wanted_count({"lookalikes": [{"risk": "deadly"}]}) == int(match.group(1))
    assert wanted_count({"lookalikes": []}) == int(match.group(2))


def test_constants_are_read_from_the_swift_source_not_copied() -> None:
    constants = PhotoConstants.load()
    swift = PHOTO_CONSTANTS.read_text()
    assert f"= {constants.maximum_pixel_size}" in swift
    assert str(constants.total_byte_budget)[:3] in swift.replace("_", "")
    assert 0 < constants.compression_quality <= 1


def test_compound_and_genus_names_both_become_searchable() -> None:
    assert query_names("Urtica dioica / Urtica urens") == ["Urtica dioica", "Urtica urens"]
    assert query_names("Coprosma spp.") == ["Coprosma"]
    assert query_names("Pyropia / Porphyra spp.") == ["Pyropia", "Porphyra"]
    assert query_names("Boletus edulis") == ["Boletus edulis"]


def test_an_english_qualifier_in_brackets_is_not_part_of_the_taxon_name() -> None:
    """`red-pored-boletes` returned nothing until this: no taxon is called "(red-pored)"."""
    assert query_names("Boletaceae (red-pored)") == ["Boletaceae"]
    assert query_names("Ulva spp. (sea lettuce)") == ["Ulva"]


def test_agreeing_identifications_ignores_identifications_of_another_taxon() -> None:
    disputed = observation(1, taxon_id=7, agreeing=2, photos=1)
    disputed["identifications"].append({"taxon": {"id": 99}})
    assert agreeing_identifications(disputed) == 2
    assert agreeing_identifications({"taxon": None, "identifications": []}) == 0


def test_candidates_spread_across_observations_before_taking_a_second_frame() -> None:
    found = [
        observation(1, taxon_id=7, agreeing=2, photos=5),
        observation(2, taxon_id=7, agreeing=9, photos=5),
        observation(3, taxon_id=7, agreeing=5, photos=5),
    ]
    selected = select_candidates("x", found, wanted=4)

    assert [c.observation_id for c in selected] == [2, 3, 1, 2]
    assert len({c.observation_id for c in selected[:3]}) == 3, "one per observation first"


def test_no_observation_supplies_more_than_the_cap_while_others_remain() -> None:
    found = [observation(1, taxon_id=7, agreeing=9, photos=10), observation(2, 7, 1, 10)]
    selected = select_candidates("x", found, wanted=6)

    from_first = [c for c in selected if c.observation_id == 1]
    assert len(from_first) <= MAX_PER_OBSERVATION


def test_unshippable_licences_are_dropped_entirely() -> None:
    """CC BY-ND and the rest stay out; only CC0, CC BY and CC BY-NC are accepted."""
    found = [observation(1, taxon_id=7, agreeing=9, photos=3, licence="cc-by-nd")]
    assert select_candidates("x", found, wanted=4) == []


def test_noncommercial_photos_are_accepted_because_the_app_is_free() -> None:
    found = [observation(1, taxon_id=7, agreeing=9, photos=3, licence="cc-by-nc")]
    assert [c.licence for c in select_candidates("x", found, wanted=2)] == ["cc-by-nc"] * 2


def test_unrestricted_licences_are_taken_before_noncommercial_ones() -> None:
    """Even when the NC observation is the better-identified one.

    Licence decides what may ship at all, so it outranks the identification evidence. Every
    NC photo is one to strip if the app ever stops being free, so the set is kept small.
    """
    found = [
        observation(1, taxon_id=7, agreeing=99, photos=1, licence="cc-by-nc"),
        observation(2, taxon_id=7, agreeing=1, photos=1, licence="cc-by"),
    ]
    assert [c.observation_id for c in select_candidates("x", found, wanted=2)] == [2, 1]


def test_within_one_observation_the_unrestricted_frame_goes_first() -> None:
    mixed = observation(1, taxon_id=7, agreeing=5, photos=2)
    mixed["photos"][0]["license_code"] = "cc-by-nc"
    mixed["photos"][1]["license_code"] = "cc0"
    assert select_candidates("x", [mixed], wanted=1)[0].licence == "cc0"


def test_thumbnail_urls_are_rewritten_to_a_shippable_size() -> None:
    selected = select_candidates("x", [observation(1, 7, 3, 1)], wanted=1)
    assert "square." not in selected[0].url and "large." in selected[0].url


def test_a_manifest_never_overwrites_one_a_previous_run_left(tmp_path: Path) -> None:
    """Staged manifests hold hand-written captions — losing one throws away review."""
    assert next_manifest(tmp_path).name == "manifest.json"

    (tmp_path / "manifest.json").write_text("{}")
    assert next_manifest(tmp_path).name == "manifest2.json"

    (tmp_path / "manifest2.json").write_text("{}")
    assert next_manifest(tmp_path).name == "manifest3.json"


def test_staged_photos_carry_no_caption_so_validation_blocks_until_written() -> None:
    staged = {
        "fileName": "x-1.heic", "photoID": 4321, "caption": "", "credit": "(c) Someone",
        "sourceURL": "https://example.test/1", "bytes": 1234, "agreeingIdentifications": 9,
        "place": "Wellington", "observedOn": "2024-01-01", "licence": "cc-by",
    }
    photo = catalogue_photo(staged)

    assert photo["caption"] == "", "a generated caption would be a claim nobody checked"
    assert set(photo) == {"caption", "credit", "fileName", "sourceURL"}, "review-only keys leak"


def test_top_up_asks_only_for_the_shortfall() -> None:
    entry = {"photos": [{"fileName": "a.heic"}, {"fileName": "b.heic"}], "lookalikes": []}
    assert shortfall(entry, wanted_count(entry)) == 2
    assert shortfall({"photos": [], "lookalikes": []}, 4) == 4
    assert shortfall({"photos": [{}] * 5, "lookalikes": []}, 4) == 0, "never negative"


def test_top_up_skips_the_observations_already_kept() -> None:
    entry = {
        "photos": [
            {"sourceURL": "https://www.inaturalist.org/observations/1"},
            {"sourceURL": "https://www.inaturalist.org/observations/1"},
            {"caption": "no source recorded"},
        ]
    }
    assert already_used_observations(entry) == {"https://www.inaturalist.org/observations/1"}


def test_staging_numbering_continues_past_what_is_already_there(tmp_path: Path) -> None:
    directory = tmp_path / "puha"
    directory.mkdir()
    (directory / "puha-1.heic").write_bytes(b"")
    (directory / "puha-10.heic").write_bytes(b"")
    (directory / "puha-notes.txt").write_bytes(b"")

    assert next_index(directory, "puha") == 11
    assert next_index(tmp_path / "empty", "puha") == 1


def test_a_cap_raised_for_the_fallback_goes_deeper_into_one_observation() -> None:
    rich = observation(1, taxon_id=9, agreeing=5, photos=8)

    capped = select_candidates("x", [rich], wanted=6)
    deeper = select_candidates("x", [rich], wanted=6, max_per_observation=6)

    assert len(capped) == MAX_PER_OBSERVATION, "the cap still holds by default"
    assert len(deeper) == 6, "the fallback may go deeper when nothing else is available"


def test_every_frame_a_reviewer_has_seen_is_remembered(tmp_path: Path) -> None:
    """Discarded counts as seen: re-offering it asks the same question a second time."""
    (tmp_path / "manifest.json").write_text(json.dumps({
        "puha": [{"fileName": "puha-1.heic", "photoID": 11, "sourceURL": "obs/1"}],
        "nettle": [{"fileName": "nettle-1.heic", "photoID": 99, "sourceURL": "obs/9"}],
    }))
    # A September manifest, written before candidates recorded which photo they were.
    (tmp_path / "retry3.json").write_text(json.dumps({
        "puha": [{"fileName": "puha-2.heic", "sourceURL": "obs/2"}],
    }))

    photo_ids, observations = previously_offered("puha", tmp_path)

    assert photo_ids == {11}, "another entry's frames are not this entry's history"
    assert observations == {"obs/2"}, "no photo id recorded, so the observation is the signal"
    assert previously_offered("unstaged", tmp_path) == (frozenset(), frozenset())


def test_a_tray_with_no_history_is_not_an_error(tmp_path: Path) -> None:
    (tmp_path / "notes.json").write_text("not json at all {")
    assert previously_offered("puha", tmp_path) == (frozenset(), frozenset())


def test_observations_tying_on_evidence_are_ordered_at_random() -> None:
    """Otherwise a second fetch shortlists the same specimens as the first."""
    tied = [observation(index, taxon_id=7, agreeing=4, photos=1) for index in range(1, 9)]

    orders = {
        tuple(
            c.observation_id
            for c in select_candidates("x", tied, wanted=8, rng=random.Random(seed))
        )
        for seed in range(6)
    }

    assert len(orders) > 1, "the tiebreak is not doing anything"


def test_better_identified_observations_still_win_over_the_shuffle() -> None:
    found = [observation(1, 7, agreeing=1, photos=1), observation(2, 7, agreeing=9, photos=1)]

    for seed in range(20):
        selected = select_candidates("x", found, wanted=2, rng=random.Random(seed))
        assert [c.observation_id for c in selected] == [2, 1], "ranking must not be random"


def test_frames_already_chosen_are_not_offered_twice() -> None:
    rich = observation(1, taxon_id=9, agreeing=5, photos=4)
    first = select_candidates("x", [rich], wanted=2)

    second = select_candidates(
        "x", [rich], wanted=2, max_per_observation=4,
        skip_photo_ids=frozenset(candidate.photo_id for candidate in first),
    )

    assert {candidate.photo_id for candidate in first}.isdisjoint(
        candidate.photo_id for candidate in second
    )
