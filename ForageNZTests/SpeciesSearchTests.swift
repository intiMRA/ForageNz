import Foundation
import Testing

@testable import ForageNZ

private func makeSpecies(
    id: String,
    commonName: String,
    maoriName: String? = nil,
    group: ForageGroup = .greens,
    origin: ForageOrigin = .introduced,
    months: [ForageMonth] = [],
    summary: SourcedText = "A plant.",
    habitat: SourcedText = "Ground.",
    habitats: [Habitat] = [],
    identification: SourcedText = "Green."
) -> ForageSpecies {
    ForageSpecies(
        id: id,
        commonName: commonName,
        maoriName: maoriName,
        scientificName: "Testus \(id)",
        group: group,
        origin: origin,
        caution: .straightforward,
        months: months,
        summary: summary,
        habitat: habitat,
        habitats: habitats,
        identification: identification,
        edibleParts: "Leaves.",
        preparation: "Boil."
    )
}

private func ids(_ query: String, in species: [ForageSpecies], month: ForageMonth = .june) -> [String] {
    SpeciesFilter(query: query).apply(to: species, currentMonth: month).map(\.id)
}

@Suite("SpeciesSearch")
struct SpeciesSearchTests {
    @Test("Macrons, case and hyphens do not matter")
    func folding() {
        let species = [
            makeSpecies(id: "kanuka", commonName: "Kānuka", maoriName: "Kānuka"),
            makeSpecies(id: "tutae", commonName: "Tūtae-kākā")
        ]
        #expect(ids("kanuka", in: species) == ["kanuka"])
        #expect(ids("TUTAE KAKA", in: species) == ["tutae"])
        #expect(ids("tūtae-kākā", in: species) == ["tutae"])
    }

    @Test("A name match outranks the summary, which outranks the identification and habitat prose")
    func ranking() {
        let species = [
            makeSpecies(id: "prose", commonName: "Alpha", identification: "Grows near sorrel."),
            makeSpecies(id: "summary", commonName: "Beta", summary: "Tastes like sorrel."),
            makeSpecies(id: "name", commonName: "Sheep's sorrel")
        ]
        #expect(ids("sorrel", in: species) == ["name", "summary", "prose"])
    }

    @Test("Every word must be found, and filler words are not required")
    func everyWord() {
        let species = [
            makeSpecies(id: "both", commonName: "Watercress", identification: "White flowers."),
            makeSpecies(id: "one", commonName: "Dock", identification: "Green flowers.")
        ]
        #expect(ids("white flowers", in: species) == ["both"])
        #expect(ids("the white flowers by a", in: species) == ["both"])
    }

    @Test("Words that name a group, origin, habitat or month narrow by that facet")
    func facetWords() {
        let species = [
            makeSpecies(id: "march-fungus", commonName: "Field mushroom", group: .fungi, months: [.march]),
            makeSpecies(id: "may-fungus", commonName: "Wood ear", group: .fungi, months: [.may]),
            makeSpecies(id: "fruit", commonName: "Blackberry", group: .fruit, origin: .pest, months: [.march], habitats: [.disturbed]),
            makeSpecies(id: "endemic", commonName: "Kawakawa", group: .herbs, origin: .endemic, habitats: [.forest]),
            makeSpecies(id: "native", commonName: "Karamū", group: .fruit, origin: .native, months: [.may], habitats: [.coastal, .forest])
        ]
        #expect(ids("fungi march", in: species) == ["march-fungus"])
        #expect(ids("fruit in mar", in: species) == ["fruit"])
        #expect(Set(ids("what can I pick in March", in: species)) == ["march-fungus", "fruit", "endemic"])
        #expect(ids("berries weeds", in: species) == ["fruit"])
        #expect(ids("waste ground", in: species) == ["fruit"])
        #expect(Set(ids("native", in: species)) == ["endemic", "native"])
        #expect(ids("endemic", in: species) == ["endemic"])
        #expect(ids("coast", in: species) == ["native"])
        // Year-round entries are in season every month, as on the In season tab.
        #expect(Set(ids("in season", in: species, month: .march)) == ["march-fungus", "fruit", "endemic"])
    }

    @Test("The owner's approved habitat synonyms narrow by habitat, in the plural too")
    func habitatSynonyms() {
        let species = [
            makeSpecies(id: "cress", commonName: "Watercress", habitats: [.wetland]),
            makeSpecies(id: "dock", commonName: "Dock", habitats: [.grassland, .disturbed]),
            makeSpecies(id: "flax", commonName: "Mountain flax", habitats: [.alpine])
        ]
        #expect(ids("watercress stream", in: species) == ["cress"])
        #expect(ids("streams", in: species) == ["cress"])
        #expect(ids("paddocks", in: species) == ["dock"])
        #expect(ids("grass", in: species) == ["dock"])
        #expect(ids("car park", in: species) == ["dock"])
        // A synonym inside a species name does not hide that species.
        #expect(ids("mountain flax", in: species) == ["flax"])
    }

    @Test("An entry named by the whole query is found even when one of its words names a facet")
    func nameBeatsFacet() {
        let species = [
            makeSpecies(id: "lawyer", commonName: "Bush lawyer", group: .fruit),
            makeSpecies(id: "forest", commonName: "Supplejack", habitats: [.forest])
        ]
        #expect(ids("bush lawyer", in: species) == ["lawyer"])
        #expect(ids("bush", in: species) == ["lawyer", "forest"])
    }

    @Test("A word inside a name is found, ranked below one that starts a word; prose is never matched mid-word")
    func wordStarts() {
        let species = [
            makeSpecies(id: "watercress", commonName: "Watercress"),
            makeSpecies(id: "cress", commonName: "Land cress"),
            makeSpecies(id: "prose", commonName: "Dock", identification: "Wash before eating.")
        ]
        #expect(ids("cress", in: species) == ["cress", "watercress"])
        #expect(ids("ash", in: species).isEmpty)
    }

    @Test("The screen reports which words were read as facets")
    func recognised() {
        let search = SpeciesSearch("native fruit in season near the coast", currentMonth: .april)
        #expect(search.groups == [.fruit])
        #expect(search.origins == [.native, .endemic])
        #expect(search.habitats == [.coastal])
        #expect(search.months == [.april])
        #expect(search.terms.isEmpty)
        #expect(SpeciesSearch("kawakawa", currentMonth: .april).recognisesFacets == false)
    }

    @Test("Every facet word is one of the guide's own labels, or its singular or plural")
    func vocabularyComesFromLabels() {
        func words(_ labels: [String]) -> Set<String> {
            Set(labels.flatMap { SpeciesSearch.fold($0).split(separator: " ").map(String.init) })
        }
        func carried(_ word: String, by labels: [String]) -> Bool {
            if labels.map(SpeciesSearch.fold).contains(where: { $0.contains(word) }) { return true }
            let known = words(labels)
            return known.contains(word + "s")
                || (word.hasSuffix("s") && known.contains(String(word.dropLast())))
                || (word.hasSuffix("y") && known.contains(word.dropLast() + "ies"))
                || (word.hasSuffix("f") && known.contains(word.dropLast() + "ves"))
        }

        for (word, group) in SpeciesSearch.Vocabulary.groups {
            #expect(carried(word, by: [String(localized: group.displayName), group.rawValue]), "\(word)")
        }
        for (word, origins) in SpeciesSearch.Vocabulary.origins {
            let labels = origins.flatMap { [String(localized: $0.displayName), $0.rawValue] }
            #expect(carried(word, by: labels), "\(word)")
        }
        for (word, habitat) in SpeciesSearch.Vocabulary.habitats {
            let labels = [String(localized: habitat.displayName), String(localized: habitat.shortLabel), habitat.rawValue]
            #expect(carried(word, by: labels), "\(word)")
        }
        for (word, month) in SpeciesSearch.Vocabulary.months {
            #expect(carried(word, by: [month.displayName, month.shortName]), "\(word)")
        }
    }
}

@Suite("PlainWordsSearch")
struct PlainWordsSearchTests {
    @Test("A reading keeps only words the user typed, so nothing the model makes up reaches the screen")
    func keepsTypedWordsOnly() {
        let reading = SearchReading(
            words: ["White", "flowers", "edible", "the"],
            groups: [.greens],
            origins: [.native],
            habitats: [.wetland],
            months: [.march]
        )
        let search = reading.search(keepingWordsFrom: "white flowers by the stream")
        #expect(search.terms == ["white", "flowers"])
        #expect(search.groups == [.greens])
        #expect(search.origins == [.native, .endemic])
        #expect(search.habitats == [.wetland])
        #expect(search.months == [.march])
    }

    @Test("A search built from parts matches like a typed one, and an empty one matches everything")
    func builtFromParts() {
        let species = [
            makeSpecies(id: "cress", commonName: "Watercress", habitats: [.wetland], identification: "White flowers."),
            makeSpecies(id: "dock", commonName: "Dock", habitats: [.wetland], identification: "Green flowers."),
            makeSpecies(id: "daisy", commonName: "Daisy", habitats: [.grassland], identification: "White flowers.")
        ]
        let search = SpeciesSearch(terms: ["White", "flowers"], habitats: [.wetland])
        #expect(SpeciesFilter().apply(to: species, using: search).map(\.id) == ["cress"])
        #expect(SpeciesFilter().apply(to: species, using: SpeciesSearch(terms: [])).count == 3)
    }

    @Test("Dropping a reading's words keeps its filters")
    func withoutTerms() {
        let search = SpeciesSearch(terms: ["plants"], habitats: [.grassland], months: [.november])
        let filtersOnly = search.withoutTerms
        #expect(filtersOnly.terms.isEmpty)
        #expect(filtersOnly.habitats == [.grassland])
        #expect(filtersOnly.months == [.november])
    }

    @Test("Only a sentence is worth the model's time")
    func worthReading() {
        #expect(PlainWordsSearch.isWorthReading("white flowers by a stream"))
        #expect(!PlainWordsSearch.isWorthReading("kawakawa"))
        #expect(!PlainWordsSearch.isWorthReading("bush lawyer"))
    }
}
