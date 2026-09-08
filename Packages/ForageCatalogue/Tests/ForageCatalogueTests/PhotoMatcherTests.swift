import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

import ForageCatalogue

@Suite("Photo matcher")
struct PhotoMatcherTests {
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

    // MARK: - Vector maths

    @Test("Vectors are normalised, so a vector matches itself exactly")
    func selfDistanceIsZero() {
        let vector = FeatureVector(values: [3, 4, 0])
        #expect(abs(vector.distance(to: vector)) < 1e-6)
        let magnitude = sqrt(vector.values.reduce(0) { $0 + $1 * $1 })
        #expect(abs(magnitude - 1) < 1e-6)
    }

    @Test("Scaling an image's features doesn't change its direction")
    func scaleInvariance() {
        let a = FeatureVector(values: [1, 2, 3])
        let b = FeatureVector(values: [10, 20, 30])
        #expect(a.distance(to: b) < 1e-6)
    }

    @Test("Orthogonal vectors are further apart than near-parallel ones")
    func distanceOrdering() {
        let reference = FeatureVector(values: [1, 0])
        #expect(reference.distance(to: FeatureVector(values: [0, 1]))
                > reference.distance(to: FeatureVector(values: [1, 0.2])))
    }

    @Test("A prototype is the mean of its photos")
    func prototypeIsMean() throws {
        let mean = try #require(FeatureVector.mean(of: [
            FeatureVector(values: [1, 0]),
            FeatureVector(values: [0, 1])
        ]))
        // Equidistant from both inputs.
        let toFirst = mean.distance(to: FeatureVector(values: [1, 0]))
        let toSecond = mean.distance(to: FeatureVector(values: [0, 1]))
        #expect(abs(toFirst - toSecond) < 1e-6)
    }

    @Test("Mismatched lengths never compare as close")
    func mismatchedLengths() {
        let short = FeatureVector(values: [1, 0])
        let long = FeatureVector(values: [1, 0, 0])
        #expect(short.distance(to: long) == .greatestFiniteMagnitude)
    }

    @Test("Mean of an empty set is nil rather than a zero vector")
    func emptyMean() {
        #expect(FeatureVector.mean(of: []) == nil)
    }

    // MARK: - Real feature prints

    /// The question this whole approach hinges on: does a general-purpose embedding put two
    /// photos of the same species closer together than unrelated images?
    @Test("Two photos of the same species are closer to each other than to unrelated images")
    func realPhotosClusterTogether() throws {
        let catalogue = try #require(Self.repoCatalogue)
        let species = try CatalogueFile.load(from: catalogue)
        let photoDirectory = PhotoAudit.directory(forCatalogueAt: catalogue)

        let withPhotos = species.filter { $0.photos.count >= 2 }
        try #require(!withPhotos.isEmpty, "No species has two photos yet — nothing to measure")

        let entry = withPhotos[0]
        let first = try PhotoMatcher.featureVector(
            for: photoDirectory.appending(path: entry.photos[0].fileName)
        )
        let second = try PhotoMatcher.featureVector(
            for: photoDirectory.appending(path: entry.photos[1].fileName)
        )
        let sameSpecies = first.distance(to: second)

        // Synthetic controls: flat colour and noise are as unlike a mushroom as it gets.
        let controls = try [
            makeImage(kind: .solid(red: 0.1, green: 0.4, blue: 0.9)),
            makeImage(kind: .noise)
        ].map { try PhotoMatcher.featureVector(for: $0) }

        for control in controls {
            let unrelated = first.distance(to: control)
            #expect(
                sameSpecies < unrelated,
                "Same-species distance \(sameSpecies) was not below unrelated distance \(unrelated)"
            )
        }
    }

    @Test("Building the index skips species with no photos and records the revision")
    func indexBuild() throws {
        let catalogue = try #require(Self.repoCatalogue)
        let species = try CatalogueFile.load(from: catalogue)
        let (index, skipped) = PhotoIndex.build(
            species: species,
            photoDirectory: PhotoAudit.directory(forCatalogueAt: catalogue)
        )

        #expect(skipped.isEmpty, "Photos failed to read: \(skipped)")
        #expect(index.revision == PhotoMatcher.currentRevision)
        #expect(index.prototypes.count == species.filter { !$0.photos.isEmpty }.count)
        #expect(index.cautions.count == species.count, "Every species needs a caution for safe presentation")

        for prototype in index.prototypes {
            #expect(prototype.photoCount > 0)
        }
    }

    @Test("A species' own photo ranks that species first")
    func ownPhotoRanksFirst() throws {
        let catalogue = try #require(Self.repoCatalogue)
        let species = try CatalogueFile.load(from: catalogue)
        let photoDirectory = PhotoAudit.directory(forCatalogueAt: catalogue)
        let (index, _) = PhotoIndex.build(species: species, photoDirectory: photoDirectory)

        let entry = try #require(species.first { !$0.photos.isEmpty })
        let query = try PhotoMatcher.featureVector(
            for: photoDirectory.appending(path: entry.photos[0].fileName)
        )

        let matches = index.matches(for: query, limit: 3)
        #expect(matches.first?.speciesId == entry.id)
    }

    @Test("The index survives a round-trip, so it can ship prebuilt")
    func indexIsCodable() throws {
        let index = PhotoIndex(
            revision: 2,
            prototypes: [SpeciesPrototype(
                speciesId: "porcini", photoCount: 2, vector: FeatureVector(values: [1, 0, 0])
            )],
            cautions: ["porcini": .careRequired]
        )
        let data = try JSONEncoder().encode(index)
        let restored = try JSONDecoder().decode(PhotoIndex.self, from: data)
        #expect(restored.revision == 2)
        #expect(restored.prototypes.first?.speciesId == "porcini")
        #expect(restored.cautions["porcini"] == .careRequired)
    }

    // MARK: - Safety behaviour

    @Test("A do-not-eat entry is never cut by the result limit")
    func avoidOnlyEntriesAreAlwaysSurfaced() {
        // Death cap sits furthest away, so a plain top-2 would drop it.
        let index = PhotoIndex(
            revision: 1,
            prototypes: [
                SpeciesPrototype(speciesId: "a", photoCount: 1, vector: FeatureVector(values: [1, 0, 0])),
                SpeciesPrototype(speciesId: "b", photoCount: 1, vector: FeatureVector(values: [0.9, 0.1, 0])),
                SpeciesPrototype(speciesId: "death-cap", photoCount: 1, vector: FeatureVector(values: [0, 0, 1]))
            ],
            cautions: ["a": .straightforward, "b": .careRequired, "death-cap": .doNotEat]
        )

        let matches = index.matches(for: FeatureVector(values: [1, 0, 0]), limit: 2)
        #expect(matches.contains { $0.speciesId == "death-cap" })
        #expect(matches.last?.speciesId == "death-cap", "It should still rank last, just not be hidden")
    }

    @Test("Comparing across Vision revisions is refused, not silently wrong")
    func revisionMismatchThrows() {
        let index = PhotoIndex(revision: 1, prototypes: [], cautions: [:])
        #expect(throws: PhotoMatcher.Failure.revisionMismatch(indexRevision: 1, queryRevision: 2)) {
            try index.requireCompatible(queryRevision: 2)
        }
        #expect(throws: Never.self) { try index.requireCompatible(queryRevision: 1) }
    }

    @Test("An unreadable file reports rather than crashing")
    func unreadableFile() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "not-an-image.heic")
        #expect(throws: PhotoMatcher.Failure.self) {
            try PhotoMatcher.featureVector(for: url)
        }
    }

    // MARK: - Synthetic control images

    private enum ImageKind {
        case solid(red: Double, green: Double, blue: Double)
        case noise
    }

    private func makeImage(kind: ImageKind, size: Int = 320) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))

        switch kind {
        case .solid(let red, let green, let blue):
            context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        case .noise:
            var generator = SystemRandomNumberGenerator()
            for x in stride(from: 0, to: size, by: 4) {
                for y in stride(from: 0, to: size, by: 4) {
                    context.setFillColor(
                        red: .random(in: 0...1, using: &generator),
                        green: .random(in: 0...1, using: &generator),
                        blue: .random(in: 0...1, using: &generator),
                        alpha: 1
                    )
                    context.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }

        let image = try #require(context.makeImage())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "control-\(UUID().uuidString).png")
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}
