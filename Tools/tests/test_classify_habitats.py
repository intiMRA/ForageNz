"""A label only appears when the entry's own prose puts the species in that place."""

from __future__ import annotations

from classify_habitats import HABITATS, claims, classify, evidence


def test_a_habitat_paragraph_yields_every_place_it_names() -> None:
    assert classify("Roadsides, riverbanks, gullies, forest margins, abandoned farmland.") == [
        "forest",
        "grassland",
        "wetland",
        "disturbed",
    ]
    assert classify("Coastal: rocky shores above the tide line, sand dunes, estuary margins.") == [
        "coastal"
    ]
    assert classify("Slow-moving fresh water: streams, drains, spring-fed creeks.") == ["wetland"]


def test_labels_come_back_in_a_fixed_order_whatever_order_the_prose_used() -> None:
    forwards = classify("Roadsides and forest.")
    backwards = classify("Forest and roadsides.")
    assert forwards == backwards == ["forest", "disturbed"]
    assert [h for h in HABITATS if h in forwards] == forwards


def test_a_denial_does_not_file_the_species_under_the_place_it_rules_out() -> None:
    # The field mushroom's prose, which says where it is *not*.
    assert classify(
        "Open grazed pasture and paddocks, especially after autumn rain. Not in woodland."
    ) == ["grassland"]
    assert classify("Exclusively under pine, in plantation forest. Never in native bush.") == [
        "forest"
    ]
    assert classify("Grows on banks but not in forest.") == []
    assert claims("Pasture. Not in woodland.") == ["Pasture"]

    # Porcini's prose, which rules out three habitats in one sentence. A denial does not have
    # to open the clause or read "not in" — "does not grow with" is the commoner shape.
    assert (
        classify(
            "It does not grow with native bush trees, so a bolete under beech or kānuka "
            "is something else."
        )
        == []
    )
    assert classify("Found on dunes. It doesn't occur in forest.") == ["coastal"]
    assert classify("Lowland only; cannot survive above the treeline.") == []

    # The denial truncates its clause rather than deleting it, so the claim in front survives.
    assert classify("Common on the coast, does not reach the alpine zone.") == ["coastal"]


def test_an_ambiguous_word_needs_its_context_before_it_counts() -> None:
    # "Park" is urban; a national or forest park is the opposite.
    assert classify("Parks and suburban streets.") == ["urban"]
    assert classify("Beech forest in national park land.") == ["forest"]
    # "Sea" bare is usually part of a name — this is hemlock's prose, which cites sea celery.
    assert classify(
        "Roadsides and waste ground, the same ground as wild fennel and sea celery."
    ) == ["disturbed"]
    assert classify("It occurs from the sea to the subalpine.") == ["coastal", "alpine"]
    # Saltmarsh is the coast; a freshwater marsh is not.
    assert classify("Estuaries and salt marsh.") == ["coastal"]
    assert classify("Ditches and marshy ground.") == ["wetland"]
    # A crop grown on straw overseas is not a New Zealand garden.
    assert classify("Cultivated on rice straw in Southeast Asia.") == []
    assert classify("Cultivated and disturbed ground: vegetable gardens.") == [
        "urban",
        "disturbed",
    ]


def test_trees_only_mean_forest_when_something_grows_in_them() -> None:
    assert classify("Under introduced broadleaf trees — especially oak.") == ["forest"]
    assert classify("On logs and stumps of deciduous trees.") == ["forest"]
    # Feijoa's prose: roadside trees are street planting, not a forest.
    assert classify("Suburban gardens, hedges, berm plantings and roadside trees.") == [
        "shrubland",
        "urban",
        "disturbed",
    ]


def test_a_shelter_belt_is_trees_and_a_hedgerow_is_shrubs() -> None:
    # A shelter belt is a planted row of macrocarpa or pine, so it reads as forest even
    # though the prose usually lists it alongside hedgerows.
    # "farm" is grassland in its own right, which is why walnut carries both.
    assert classify("Old farm shelter belts, homestead gardens.") == [
        "forest",
        "grassland",
        "urban",
    ]
    assert classify("Under pine, in plantations and shelter belts.") == ["forest"]
    assert classify("Old hedgerows, shelter belts and scrub.") == ["forest", "shrubland"]


def test_a_herbarium_list_is_place_names_and_is_not_read_at_all() -> None:
    # Psilocybe aucklandiae's prose. The list gave it `coastal` from "Titirangi Beach" and
    # `urban` from "Atkinson Park" — two New Zealand place names that happen to be built out
    # of habitat words, and neither says where the fungus grows.
    prose = (
        "On soil and litter, especially clay soils, in native forests and pine plantations.\n"
        "Specimens examined for the description: Atkinson Park, Titirangi Beach on soil "
        "under Leptospermum: PDD 49789; Quarry Track, Piha Valley Forest, on litter."
    )
    assert classify(prose) == ["forest"]
    # Only the list goes, never prose that follows it on its own line.
    assert classify("Material examined: Otago Peninsula.\nCoastal dunes.") == ["coastal"]


def test_a_species_merely_found_near_a_lake_is_not_a_wetland_species() -> None:
    # Psilocybe makarorae: the substrate is beech wood, and the lake is where people run into
    # it. Its forest label comes from that substrate, which never uses the word "forest".
    assert classify(
        "Fruit bodies grow on the fallen, rotting wood of southern beeches "
        "(genus Nothofagus), and are often encountered near lakes and picnic grounds"
    ) == ["forest"]
    # A species that genuinely lives on a lake edge still counts.
    assert classify("Lake margins and lakeside seepages.") == ["wetland"]
    assert classify("Shallow water at the edges of lakes.") == ["wetland"]


def test_evidence_names_the_words_behind_each_label() -> None:
    # Porcini's prose. The evidence is what makes a wrong rule visible in review.
    found = evidence(
        "Look along the drip line of mature street and park trees and in old shelter belts."
    )
    assert found == {"forest": ["shelter belts"], "urban": ["street", "park"]}

    # Keys agree with classify(), and repeats collapse to one mention.
    text = "Forest margins, regenerating bush, coastal scrub."
    assert list(evidence(text)) == classify(text)
    assert evidence("Forest, forest margins and forest floor.") == {"forest": ["Forest"]}

    # A denial leaves no evidence, because it left no claim.
    assert evidence("Not in woodland.") == {}


def test_prose_that_says_nothing_about_place_earns_no_label() -> None:
    # Wikipedia distribution sections: a native range is not a habitat.
    assert classify("The plant is native to Europe, but has become introduced elsewhere.") == []
    assert classify("Like carrots, parsnips are native to Eurasia.") == []
    assert classify("") == []
    assert classify("   ") == []
