"""The invariant that matters: enrichment can fill blanks, never overwrite you.

These guard hand-authored, safety-critical content. If one fails, the enricher has
gained the ability to change something a person wrote in a book-checked entry.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest

from enrich_catalogue import (
    FIELD_POLICY,
    Field,
    FindingKind,
    InatTaxon,
    NzorOrigin,
    NzorRecord,
    Policy,
    fill_entry,
    inspect_entry,
)

TAXON = InatTaxon(
    taxon_id=404899, scientific_name="Piper excelsum", preferred_common_name="Kawakawa"
)


def make_entry(**overrides: Any) -> dict[str, Any]:
    entry: dict[str, Any] = {
        "id": "kawakawa",
        "commonName": "Kawakawa",
        "maoriName": "Kawakawa",
        "scientificName": "Piper excelsum",
        "origin": "native",
        "identification": "Heart-shaped leaves riddled with holes.",
        "warnings": ["Avoid in pregnancy."],
        "sources": ["Langlands, Foraging New Zealand, p. 40"],
    }
    entry.update(overrides)
    return entry


class TestNeverOverwrites:
    def test_a_field_with_a_value_is_left_alone(self) -> None:
        entry = make_entry(moreImagesURL="https://example.org/mine")
        findings = list(fill_entry(entry, TAXON))

        assert entry["moreImagesURL"] == "https://example.org/mine"
        assert findings == []

    def test_whitespace_is_not_treated_as_empty_enough_to_replace(self) -> None:
        """A value that is only spaces is still something a person typed.

        Reported rather than overwritten, so a stray space cannot silently block
        enrichment forever.
        """
        entry = make_entry(moreImagesURL="   ")
        findings = list(fill_entry(entry, TAXON))

        assert entry["moreImagesURL"] == "   "
        assert [finding.kind for finding in findings] == [FindingKind.SUGGESTION]

    def test_an_empty_field_is_filled(self) -> None:
        entry = make_entry(moreImagesURL="")
        findings = list(fill_entry(entry, TAXON))

        assert entry["moreImagesURL"] == TAXON.taxon_page
        assert [finding.kind for finding in findings] == [FindingKind.FILLED]

    def test_nothing_outside_the_fillable_policy_is_ever_written(self) -> None:
        entry = make_entry(moreImagesURL="")
        before = {key: value for key, value in entry.items() if key != Field.MORE_IMAGES_URL}

        list(fill_entry(entry, TAXON))

        after = {key: value for key, value in entry.items() if key != Field.MORE_IMAGES_URL}
        assert after == before

    def test_safety_critical_fields_are_not_fillable(self) -> None:
        """A regression guard: these must never acquire a FILL_WHEN_EMPTY policy."""
        protected = {
            "identification",
            "warnings",
            "lookalikes",
            "preparation",
            "edibleParts",
            "harvestEthics",
            "sources",
            "recipes",
            "caution",
            "summary",
            "habitat",
            "maoriName",
            "commonName",
            "id",
        }
        fillable = {
            str(field) for field, policy in FIELD_POLICY.items() if policy is Policy.FILL_WHEN_EMPTY
        }
        assert fillable & protected == set()

    def test_missing_taxon_fills_nothing(self) -> None:
        entry = make_entry(moreImagesURL="")
        assert list(fill_entry(entry, None)) == []
        assert entry["moreImagesURL"] == ""


class TestReportsWithoutChanging:
    def test_a_synonym_is_reported_not_corrected(self) -> None:
        entry = make_entry(scientificName="Acca sellowiana")
        nzor = NzorRecord(
            partial_name="Acca sellowiana",
            status="Current",
            accepted_name="Feijoa sellowiana",
            origins=(NzorOrigin.EXOTIC,),
        )

        findings = list(inspect_entry(entry, nzor, None))

        assert entry["scientificName"] == "Acca sellowiana", "must not rewrite the name"
        assert any(
            finding.kind is FindingKind.DISAGREEMENT and "Feijoa sellowiana" in finding.message
            for finding in findings
        )

    def test_an_origin_conflict_is_reported_not_corrected(self) -> None:
        entry = make_entry(origin="native")
        nzor = NzorRecord(None, "Current", None, (NzorOrigin.EXOTIC,))

        findings = list(inspect_entry(entry, nzor, None))

        assert entry["origin"] == "native"
        assert any(finding.kind is FindingKind.DISAGREEMENT for finding in findings)

    @pytest.mark.parametrize("origin", [NzorOrigin.NON_ENDEMIC, NzorOrigin.INDIGENOUS])
    def test_indigenous_biostatuses_agree_with_native(self, origin: NzorOrigin) -> None:
        """ "Non-endemic" is still indigenous — it occurs naturally here and elsewhere."""
        entry = make_entry(origin="native")
        nzor = NzorRecord(None, "Current", None, (origin,))
        assert list(inspect_entry(entry, nzor, None)) == []

    def test_endemic_source_with_native_entry_is_a_suggestion_not_a_conflict(self) -> None:
        """Most sources don't record endemism, so `native` is not wrong — just less precise."""
        entry = make_entry(origin="native")
        nzor = NzorRecord(None, "Current", None, (NzorOrigin.ENDEMIC,))

        findings = list(inspect_entry(entry, nzor, None))

        assert entry["origin"] == "native", "origin is report-only"
        assert [finding.kind for finding in findings] == [FindingKind.SUGGESTION]
        assert "endemic" in findings[0].message

    def test_endemic_entry_agrees_with_endemic_source(self) -> None:
        entry = make_entry(origin="endemic")
        nzor = NzorRecord(None, "Current", None, (NzorOrigin.ENDEMIC,))
        assert list(inspect_entry(entry, nzor, None)) == []

    def test_endemic_entry_conflicts_with_a_non_endemic_source(self) -> None:
        """Claiming endemism when the source says it occurs elsewhere is a real disagreement."""
        entry = make_entry(origin="endemic")
        nzor = NzorRecord(None, "Current", None, (NzorOrigin.NON_ENDEMIC,))

        findings = list(inspect_entry(entry, nzor, None))

        assert entry["origin"] == "endemic"
        assert [finding.kind for finding in findings] == [FindingKind.DISAGREEMENT]

    def test_a_pest_is_consistent_with_exotic(self) -> None:
        """NZOR cannot tell an introduced species from a declared pest."""
        entry = make_entry(origin="pest")
        nzor = NzorRecord(None, "Current", None, (NzorOrigin.EXOTIC,))
        assert list(inspect_entry(entry, nzor, None)) == []

    def test_a_maori_name_candidate_is_a_suggestion_only(self) -> None:
        entry = make_entry(maoriName="")
        candidate = InatTaxon(1, "Stellaria media", "Kohukohu")

        findings = list(inspect_entry(entry, None, candidate))

        assert entry["maoriName"] == "", "te reo names are never written by a script"
        assert [finding.kind for finding in findings] == [FindingKind.SUGGESTION]

    def test_no_suggestion_when_a_maori_name_is_already_present(self) -> None:
        entry = make_entry(maoriName="Kawakawa")
        candidate = InatTaxon(1, "Piper excelsum", "Something else")
        assert list(inspect_entry(entry, None, candidate)) == []


class TestSeasonality:
    """The thresholds decide whether a season suggestion is made at all, so each edge is pinned."""

    def test_below_minimum_observations_is_noise(self) -> None:
        from enrich_catalogue import Seasonality

        thin = Seasonality(counts={1: Seasonality.MINIMUM_OBSERVATIONS - 1})
        assert not thin.is_meaningful
        exact = Seasonality(counts={1: Seasonality.MINIMUM_OBSERVATIONS})
        assert exact.is_meaningful

    def test_peak_months_are_those_at_or_above_the_share_of_the_busiest_month(self) -> None:
        from enrich_catalogue import Seasonality

        # Busiest month 100 → threshold 25 at PEAK_SHARE 0.25. 25 is in, 24 is out.
        season = Seasonality(counts={3: 100, 4: 25, 5: 24, 6: 1})
        assert season.peak_months == (3, 4)

    def test_no_observations_means_no_peak(self) -> None:
        from enrich_catalogue import Seasonality

        assert Seasonality(counts={}).peak_months == ()

    def test_a_peak_spanning_most_of_the_year_is_not_suggested(self) -> None:
        from enrich_catalogue import Seasonality, inspect_seasonality

        wide = Seasonality(
            counts=dict.fromkeys(range(1, Seasonality.NARROW_ENOUGH_TO_MENTION + 2), 50)
        )
        entry = make_entry(months=[])
        assert [f.kind for f in inspect_seasonality(entry, wide)] == []

    def test_a_narrow_peak_on_a_year_round_entry_is_a_suggestion(self) -> None:
        from enrich_catalogue import FindingKind, Seasonality, inspect_seasonality

        narrow = Seasonality(counts={3: 50, 4: 50, 5: 50})
        entry = make_entry(months=[])
        findings = list(inspect_seasonality(entry, narrow))
        assert [f.kind for f in findings] == [FindingKind.SUGGESTION]
        assert entry["months"] == [], "months are report-only"

    def test_unreliable_data_produces_nothing(self) -> None:
        from enrich_catalogue import Seasonality, inspect_seasonality

        entry = make_entry(months=[1])
        assert list(inspect_seasonality(entry, Seasonality(counts={6: 5}))) == []
        assert list(inspect_seasonality(entry, None)) == []


class TestSharedPhotoLoop:
    """Both scripts fetch photos through one loop, so licence and URL handling cannot drift."""

    def test_only_acceptably_licensed_photos_are_taken_and_wanted_is_a_ceiling(
        self, tmp_path: Path
    ) -> None:
        from sources import licensed_photos

        observations = [
            {
                "uri": "obs1",
                "photos": [
                    {"license_code": "cc-by-nc", "url": "https://x/1/square.jpg"},
                    {"license_code": "cc0", "url": "https://x/2/square.jpg"},
                ],
            },
            {
                "uri": "obs2",
                "photos": [
                    {"license_code": "cc-by", "url": "https://x/3/square.jpg"},
                    {"license_code": "cc-by", "url": "https://x/4/square.jpg"},
                ],
            },
        ]
        fetched: list[str] = []

        def fake_download(url: str, destination: Path) -> bool:
            fetched.append(url)
            destination.write_bytes(b"jpg")
            return True

        got = list(
            licensed_photos(
                observations, tmp_path, "puha", wanted=2, size="large", downloader=fake_download
            )
        )

        assert [path.name for path, *_ in got] == ["puha-1.jpg", "puha-2.jpg"]
        assert fetched == ["https://x/2/large.jpg", "https://x/3/large.jpg"], (
            "NC skipped, size rewritten, stopped at wanted"
        )
        assert [str(licence) for _, licence, *_ in got] == ["cc0", "cc-by"]

    def test_a_failed_download_is_skipped_not_counted(self, tmp_path: Path) -> None:
        from sources import licensed_photos

        observations = [
            {
                "uri": "o",
                "photos": [
                    {"license_code": "cc0", "url": "https://x/bad/square.jpg"},
                    {"license_code": "cc0", "url": "https://x/good/square.jpg"},
                ],
            }
        ]
        got = list(
            licensed_photos(
                observations,
                tmp_path,
                "puha",
                wanted=1,
                size="medium",
                downloader=lambda url, dest: "good" in url and not dest.write_bytes(b"x"),
            )
        )
        assert [path.name for path, *_ in got] == ["puha-1.jpg"]


class TestEvaluationSets:
    def test_the_negative_set_shares_nothing_with_the_shipped_catalogue(self) -> None:
        from fetch_eval_photos import OUT_OF_CATALOGUE_TAXA, catalogue_taxa, check_disjoint

        assert check_disjoint(catalogue_taxa(), OUT_OF_CATALOGUE_TAXA) == []

    def test_an_overlap_by_id_or_by_name_is_caught(self) -> None:
        from fetch_eval_photos import check_disjoint

        catalogue = {"hemlock": "Conium maculatum", "puha": "Sonchus oleraceus"}
        assert check_disjoint(catalogue, {"hemlock": "Something else"}) == ["hemlock"]
        assert check_disjoint(catalogue, {"poison-parsley": "conium maculatum"}) == [
            "poison-parsley"
        ]
        assert check_disjoint(catalogue, {"foxglove": "Digitalis purpurea"}) == []
