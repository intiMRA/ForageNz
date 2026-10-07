import Foundation
import Testing

import ForageCatalogue

@Suite("Habitat")
struct HabitatTests {
    /// The labels are `LocalizedStringResource` so Xcode extracts them into the String
    /// Catalog. Resolved here against this target, which has no catalog, so what comes back
    /// is the key — the English source text, which is exactly what these tests are about.
    private static func resolve(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    @Test("Every case carries a label, and no two share one")
    func labelsAreDistinct() {
        let displayNames = Habitat.allCases.map { Self.resolve($0.displayName) }
        let shortLabels = Habitat.allCases.map { Self.resolve($0.shortLabel) }

        #expect(displayNames.allSatisfy { !$0.isEmpty })
        #expect(shortLabels.allSatisfy { !$0.isEmpty })
        #expect(Set(displayNames).count == Habitat.allCases.count)
        #expect(Set(shortLabels).count == Habitat.allCases.count)
    }

    /// `.disturbed` shipped as "Disturbed & waste ground" with a chip reading "Waste ground" —
    /// the one case that kept the example and dropped the habitat, so the filter read as being
    /// about vacant lots and not about verges, stopbanks and building sites too. The habitat is
    /// the first word of the display name; the chip has to start with the same word.
    @Test("A chip keeps the habitat half of the label, never the example half")
    func shortLabelsKeepTheHabitat() {
        for habitat in Habitat.allCases {
            let displayName = Self.resolve(habitat.displayName)
            let shortLabel = Self.resolve(habitat.shortLabel)
            #expect(
                shortLabel.split(separator: " ").first == displayName.split(separator: " ").first,
                """
                \(habitat.rawValue) is labelled "\(displayName)" but chipped as \
                "\(shortLabel)", which names the example rather than the place.
                """
            )
        }
    }

    @Test("Habitats survive a JSON round trip")
    func roundTrip() throws {
        let species = makeSpecies(habitats: [.coastal, .forest, .disturbed])
        let data = try JSONEncoder().encode(species)
        let decoded = try JSONDecoder().decode(ForageSpecies.self, from: data)
        #expect(decoded.habitats == [.coastal, .forest, .disturbed])
    }

    /// The key is new, so an entry written before it existed still has to decode — the same
    /// treatment `draft` gets.
    @Test("An entry with no habitats key decodes as unclassified, not as a failure")
    func missingKeyDecodes() throws {
        let json = """
        {
          "id": "test", "commonName": "Test", "scientificName": "Testus",
          "group": "greens", "origin": "introduced", "caution": "straightforward",
          "months": [], "summary": {"text": "s", "sources": []},
          "habitat": {"text": "h", "sources": []},
          "identification": {"text": "i", "sources": []},
          "edibleParts": {"text": "e", "sources": []},
          "preparation": {"text": "p", "sources": []},
          "lookalikes": [], "warnings": [], "sources": [], "recipes": [], "photos": []
        }
        """
        let decoded = try JSONDecoder().decode(ForageSpecies.self, from: Data(json.utf8))
        #expect(decoded.habitats.isEmpty)
    }

    @Test("An unclassified entry is an advisory, never a reason to fail the build")
    func unclassifiedIsAdvisoryOnly() {
        let unclassified = makeSpecies(habitats: [])
        let issue = unclassified.validationIssues.first { $0.field == .habitats }
        #expect(issue?.severity == .advisory)
        #expect(unclassified.isPublishable)

        let classified = makeSpecies(habitats: [.forest])
        #expect(!classified.validationIssues.contains { $0.field == .habitats })
    }

    @Test("with(habitats:) replaces the list and leaves the prose alone")
    func withHabitats() {
        let species = makeSpecies(habitats: [.forest])
        let changed = species.with(habitats: [.coastal, .alpine])
        #expect(changed.habitats == [.coastal, .alpine])
        #expect(changed.habitat.text == species.habitat.text)
        #expect(species.with(commonName: "Other").habitats == [.forest])
    }

    private func makeSpecies(habitats: [Habitat]) -> ForageSpecies {
        ForageSpecies(
            id: "test",
            commonName: "Test plant",
            scientificName: "Testus planta",
            group: .greens,
            origin: .introduced,
            caution: .straightforward,
            summary: "A plant for testing.",
            habitat: "Test ground.",
            habitats: habitats,
            identification: "Looks like a test.",
            edibleParts: "Leaves.",
            preparation: "Boil.",
            // These tests are about classification, not completeness, and an entry with no
            // photograph is blocking — so the fixture carries one.
            photos: [SpeciesPhoto(fileName: "test-1.heic", caption: "Whole plant.", credit: "Someone (CC BY 4.0)")]
        )
    }
}
