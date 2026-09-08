import Foundation
import Testing

import ForageCatalogue

@Suite("CatalogueLocator")
struct CatalogueLocatorTests {
    /// The case that matters: launched from Xcode, neither the working directory nor the
    /// app bundle sits inside the repo, so only the source anchor can find the catalogue.
    @Test("Resolves from outside the repo entirely")
    func resolvesWithNoUsableWorkingDirectory() {
        let resolved = CatalogueLocator.resolve(
            arguments: [],
            fileManager: FileManager.default
        )

        let url = resolved
        #expect(url != nil, "Locator found nothing — the editor would open with no catalogue")
        #expect(url?.lastPathComponent == "species.json")
        #expect(FileManager.default.fileExists(atPath: url?.path ?? ""))
    }

    @Test("An explicit --catalogue argument wins over any search")
    func explicitArgumentWins() {
        let resolved = CatalogueLocator.resolve(arguments: ["tool", "--catalogue", "/tmp/other.json"])
        #expect(resolved?.path == "/tmp/other.json")
    }

    @Test("A --catalogue flag with no value falls back to searching")
    func danglingArgumentIsIgnored() {
        let resolved = CatalogueLocator.resolve(arguments: ["tool", "--catalogue"])
        #expect(resolved?.lastPathComponent == "species.json")
    }

    @Test("Searching a directory with no repo above it finds nothing")
    func searchGivesUp() {
        #expect(CatalogueLocator.search(from: URL(fileURLWithPath: "/"), levels: 3) == nil)
    }

    @Test("Searching upwards finds the catalogue from a nested directory")
    func searchWalksUp() throws {
        let anchor = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let found = try #require(CatalogueLocator.search(from: anchor))
        #expect(found.pathComponents.suffix(3) == ["ForageNZ", "Catalogue", "species.json"])
    }
}
