import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

import ForageCatalogue
import ForageCatalogueTooling

@Suite("Photo matcher")
struct PhotoMatcherTests {
    /// The real catalogue in the repo, located by walking up from this source file.
    private static var repoCatalogue: URL? {
        CatalogueLocator.search(from: URL(fileURLWithPath: #filePath))
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

    @Test("Building the index reads every shipped photo and carries each species' caution")
    func indexBuild() throws {
        let catalogue = try #require(Self.repoCatalogue)
        let species = try CatalogueFile.load(from: catalogue)
        let (index, unreadable) = PhotoIndex.build(
            species: species,
            photoDirectory: PhotoAudit.directory(forCatalogueAt: catalogue)
        )

        #expect(unreadable.isEmpty, "Photos failed to read: \(unreadable)")
        #expect(index.revision == PhotoMatcher.currentRevision)
        #expect(index.prototypes.count == species.filter { !$0.photos.isEmpty }.count)

        let cautions = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0.caution) })
        for prototype in index.prototypes {
            #expect(prototype.photoCount > 0)
            #expect(prototype.caution == cautions[prototype.speciesId])
        }
    }

    @Test("A photo that can't be read is named, and the species keeps what did read")
    func unreadablePhotoIsReported() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let good = try makeImage(kind: .solid(red: 0.2, green: 0.6, blue: 0.2))
        try FileManager.default.copyItem(at: good, to: directory.appending(path: "ok.png"))
        try Data([0, 1, 2]).write(to: directory.appending(path: "broken.png"))

        let species = ForageSpecies(
            id: "test", commonName: "Test", scientificName: "T. t.",
            category: .greens, origin: .introduced, caution: .careRequired,
            summary: "", habitat: "", identification: "", edibleParts: "", preparation: "",
            photos: [
                SpeciesPhoto(fileName: "ok.png", caption: "a", credit: "b"),
                SpeciesPhoto(fileName: "broken.png", caption: "a", credit: "b")
            ]
        )

        let (index, unreadable) = PhotoIndex.build(species: [species], photoDirectory: directory)

        #expect(unreadable.map(\.fileName) == ["broken.png"])
        #expect(index.prototypes.first?.photoCount == 1, "the prototype must report how many photos it is really built from")
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
