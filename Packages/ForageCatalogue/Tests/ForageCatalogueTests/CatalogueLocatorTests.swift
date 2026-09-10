import Foundation
import Testing

import ForageCatalogue

@Suite("CatalogueLocator")
struct CatalogueLocatorTests {
    /// The case that matters: launched from Xcode, neither the working directory nor the
    /// app bundle sits inside the repo, so only the source anchor can find the catalogue.
    @Test("Resolves from outside the repo entirely")
    func resolvesWithNoUsableWorkingDirectory() {
        // Working directory and bundle both outside the repo, exactly as under Xcode. Only
        // the default source anchor — this file — is left to find it.
        let resolved = CatalogueLocator.resolve(
            arguments: [],
            startingAt: URL(fileURLWithPath: "/"),
            currentDirectory: "/",
            bundleURL: URL(fileURLWithPath: "/Applications")
        )

        #expect(resolved != nil, "Locator found nothing — the editor would open with no catalogue")
        #expect(resolved?.lastPathComponent == "species.json")
        #expect(FileManager.default.fileExists(atPath: resolved?.path ?? ""))
    }

    @Test("With every origin outside the repo, it finds nothing rather than guessing")
    func nothingToFind() {
        let resolved = CatalogueLocator.resolve(
            arguments: [],
            startingAt: URL(fileURLWithPath: "/"),
            currentDirectory: "/",
            bundleURL: URL(fileURLWithPath: "/Applications"),
            sourceAnchor: "/Applications/Elsewhere.swift"
        )
        #expect(resolved == nil)
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
