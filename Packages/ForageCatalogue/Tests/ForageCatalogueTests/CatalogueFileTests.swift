import Foundation
import Testing

import ForageCatalogue

@Suite("CatalogueFile")
struct CatalogueFileTests {
    /// The real catalogue in the repo, located relative to this source file.
    private static var repoCatalogue: URL? {
        CatalogueLocator.search(from: URL(fileURLWithPath: #filePath))
    }

    @Test("The shipped catalogue decodes through the shared model")
    func decodesRepoCatalogue() throws {
        let url = try #require(Self.repoCatalogue, "couldn't locate species.json from \(#filePath)")
        let species = try CatalogueFile.load(from: url)
        #expect(!species.isEmpty)
    }

    /// The editor writes the file the app reads. If encoding isn't byte-stable against what
    /// is already on disk, every save produces a whole-file diff and real edits get lost in it.
    @Test("Re-encoding the shipped catalogue is byte-identical to the file on disk")
    func roundTripIsByteStable() throws {
        let url = try #require(Self.repoCatalogue)
        let original = try Data(contentsOf: url)

        let species = try CatalogueFile.load(from: url)
        let reencoded = try CatalogueFile.encoder().encode(species) + Data("\n".utf8)

        #expect(
            reencoded == original,
            """
            Re-encoding changed the file. On disk: \(original.count) bytes, re-encoded: \
            \(reencoded.count) bytes. Align species.json with CatalogueFile.encoder() so the \
            editor's first save is a no-op.
            """
        )
    }

    @Test("A catalogue survives a save and reload unchanged")
    func savePreservesEntries() throws {
        let species = [
            ForageSpecies(
                id: "test-a", commonName: "Test A", maoriName: "Tēhi",
                scientificName: "Testus alpha", category: .fungi, origin: .native,
                caution: .doNotEat, months: [.november, .december, .january],
                summary: "A test.", habitat: "Nowhere.", identification: "Unmistakable.",
                edibleParts: "None.", preparation: "None.",
                lookalikes: [Lookalike(name: "Other", risk: .deadly, howToTell: "Check the base.", entry: .deathCap)],
                warnings: ["Do not eat."], harvestEthics: "Leave it.",
                sources: ["Somebody, A Book, p. 1"],
                recipes: [Recipe(title: "Nothing", method: "Do not.")]
            )
        ]

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "catalogue-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try CatalogueFile.save(species, to: url)
        #expect(try CatalogueFile.load(from: url) == species)
    }

    @Test("A missing file reports unreadable rather than crashing")
    func missingFile() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "no-such-catalogue.json")
        #expect(throws: CatalogueFile.Failure.self) {
            try CatalogueFile.load(from: url)
        }
    }
}
