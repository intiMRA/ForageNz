import Foundation
import Testing

import ForageCatalogue

@Suite("SpeciesID generation")
struct SpeciesIDGeneratorTests {
    private static var repoCatalogue: URL? {
        CatalogueLocator.search(from: URL(fileURLWithPath: #filePath))
    }

    /// The checked-in enum must be exactly what the generator produces for the shipped
    /// catalogue — byte for byte — or someone edited one without the other.
    @Test("The checked-in SpeciesID.swift is what the catalogue generates")
    func checkedInEnumIsCurrent() throws {
        let catalogue = try #require(Self.repoCatalogue)
        let species = try CatalogueFile.load(from: catalogue)
        let generated = try #require(SpeciesIDGenerator.fileURL(forCatalogueAt: catalogue))
        let onDisk = try String(contentsOf: generated, encoding: .utf8)

        #expect(onDisk == SpeciesIDGenerator.render(ids: species.map(\.id)), "run catalogue-tool --normalise and commit the result")
    }

    @Test("Case names are camelCase of the id, and rendering is deterministic")
    func caseNames() {
        #expect(SpeciesIDGenerator.caseName(for: "death-cap") == "deathCap")
        #expect(SpeciesIDGenerator.caseName(for: "red-pored-boletes") == "redPoredBoletes")
        #expect(SpeciesIDGenerator.caseName(for: "puha") == "puha")
        #expect(SpeciesIDGenerator.render(ids: ["b", "a", "b"]) == SpeciesIDGenerator.render(ids: ["a", "b"]))
    }

    @Test("A lookalike naming a species the enum lacks fails to decode")
    func unknownEntryFailsToDecode() {
        let json = Data("""
        {"name":"Ghost","risk":"deadly","howToTell":"Nothing.","entry":"not-a-species"}
        """.utf8)
        #expect(throws: DecodingError.self) {
            try CatalogueFile.decoder().decode(Lookalike.self, from: json)
        }
    }

    @Test("Regenerating outside the repo layout is reported, not an error")
    func regenerateOutsideRepo() throws {
        let stray = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "species.json")
        #expect(try SpeciesIDGenerator.regenerate(for: [], catalogueURL: stray) == .notInRepo)
    }
}
