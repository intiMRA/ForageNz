"""The invariant that matters: enrichment can fill blanks, never overwrite you.

These guard hand-authored, safety-critical content. If one fails, the enricher has
gained the ability to change something a person wrote in a book-checked entry.
"""

from __future__ import annotations

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

    @pytest.mark.parametrize(
        "origin", [NzorOrigin.ENDEMIC, NzorOrigin.NON_ENDEMIC, NzorOrigin.INDIGENOUS]
    )
    def test_indigenous_biostatuses_agree_with_native(self, origin: NzorOrigin) -> None:
        """ "Non-endemic" is still indigenous — it occurs naturally here and elsewhere."""
        entry = make_entry(origin="native")
        nzor = NzorRecord(None, "Current", None, (origin,))
        assert list(inspect_entry(entry, nzor, None)) == []

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
