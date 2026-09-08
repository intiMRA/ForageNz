import Foundation
import Testing

import ForageCatalogue

@Suite("Photo audit")
struct PhotoAuditTests {
    private static var repoCatalogue: URL? {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = directory.appending(path: "ForageNZ/Catalogue/species.json")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }
        return nil
    }

    /// The photos ship inside the app, so this is the check that stops the bundle growing
    /// without anyone noticing.
    @Test("Shipped photos are present, within budget, and none are orphaned")
    func shippedPhotosAudit() throws {
        let catalogue = try #require(Self.repoCatalogue)
        let species = try CatalogueFile.load(from: catalogue)
        let report = PhotoAudit.audit(
            species: species,
            photoDirectory: PhotoAudit.directory(forCatalogueAt: catalogue)
        )

        for finding in report.findings {
            Issue.record("\(finding.speciesId) · \(finding.fileName): \(finding.problem)")
        }
        for orphan in report.orphanedFiles {
            Issue.record("\(orphan) is in Photos/ but no entry references it — delete it or attach it.")
        }

        #expect(report.totalBytes <= CataloguePhotos.totalByteBudget)
    }

    @Test("A referenced but missing file is reported")
    func missingFileIsReported() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "photos-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let species = makeSpecies(photos: [
            SpeciesPhoto(fileName: "nope.heic", caption: "Whole plant", credit: "© Someone (CC BY)")
        ])

        let report = PhotoAudit.audit(species: [species], photoDirectory: directory)
        #expect(report.findings.count == 1)
        #expect(report.findings.first?.problem.contains("missing") == true)
    }

    @Test("An oversized file is reported")
    func oversizedFileIsReported() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "photos-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fat = Data(repeating: 0, count: CataloguePhotos.maximumBytesPerPhoto + 1)
        try fat.write(to: directory.appending(path: "big.heic"))

        let species = makeSpecies(photos: [
            SpeciesPhoto(fileName: "big.heic", caption: "Whole plant", credit: "© Someone (CC BY)")
        ])

        let report = PhotoAudit.audit(species: [species], photoDirectory: directory)
        #expect(report.findings.contains { $0.problem.contains("ceiling") })
    }

    @Test("A file nothing references is flagged as an orphan")
    func orphanIsReported() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "photos-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data([0]).write(to: directory.appending(path: "stray.heic"))

        let report = PhotoAudit.audit(species: [makeSpecies(photos: [])], photoDirectory: directory)
        #expect(report.orphanedFiles == ["stray.heic"])
    }

    @Test("A photo without a caption or credit is a blocking model issue")
    func uncaptionedPhotoBlocks() {
        let species = makeSpecies(photos: [SpeciesPhoto(fileName: "a.heic", caption: "", credit: "")])
        let fields = species.blockingIssues.map(\.field)
        #expect(fields.contains("photos[0]"))
        #expect(species.blockingIssues.count >= 2, "caption and credit are separate obligations")
    }

    @Test("Too few photos is advisory, not blocking")
    func tooFewPhotosIsAdvisory() {
        let species = makeSpecies(photos: [])
        #expect(species.isPublishable)
        #expect(species.validationIssues.contains { $0.field == "photos" && $0.severity == .advisory })
    }

    private func makeSpecies(photos: [SpeciesPhoto]) -> ForageSpecies {
        ForageSpecies(
            id: "test", commonName: "Test", scientificName: "Testus testa",
            category: .greens, origin: .introduced, caution: .straightforward,
            summary: "A summary.", habitat: "Somewhere.", identification: "Distinctive.",
            edibleParts: "Leaves.", preparation: "Boil.",
            sources: ["A Book, p. 1"], photos: photos
        )
    }
}
