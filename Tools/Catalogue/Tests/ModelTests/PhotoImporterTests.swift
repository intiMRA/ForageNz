import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

import ForageCatalogue

/// The one encoder both the editor and `--attach` go through. If it lets an oversized or
/// unreadable file past, the photo budget is a suggestion.
@Suite("Photo importer")
struct PhotoImporterTests {
    @Test("An image lands as HEIC under the per-photo ceiling with the next free name")
    func importsWithinBudget() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try Self.writePNG(size: 2000, to: directory.appending(path: "big.png"))

        let photo = try PhotoImporter.importPhoto(
            from: source, speciesId: "puha", existing: [], into: directory,
            caption: "leaf", credit: "me"
        )

        #expect(photo.fileName == CataloguePhotos.fileName(speciesId: "puha", index: 1))
        #expect(photo.caption == "leaf")
        #expect(photo.credit == "me")
        let written = directory.appending(path: photo.fileName)
        let bytes = try #require(try FileManager.default.attributesOfItem(atPath: written.path)[.size] as? Int)
        #expect(bytes > 0 && bytes <= CataloguePhotos.maximumBytesPerPhoto)
        let image = try #require(CGImageSourceCreateWithURL(written as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        #expect(max(image.width, image.height) <= CataloguePhotos.maximumPixelSize, "must be downscaled on the way in")
    }

    @Test("A name already on disk is skipped even if the entry does not list it")
    func skipsNamesTakenOnDisk() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data([0]).write(to: directory.appending(path: CataloguePhotos.fileName(speciesId: "puha", index: 1)))
        let existing = [SpeciesPhoto(fileName: CataloguePhotos.fileName(speciesId: "puha", index: 2), caption: "a", credit: "b")]
        let source = try Self.writePNG(size: 300, to: directory.appending(path: "small.png"))

        let photo = try PhotoImporter.importPhoto(from: source, speciesId: "puha", existing: existing, into: directory)

        #expect(photo.fileName == CataloguePhotos.fileName(speciesId: "puha", index: 3))
        #expect(photo.caption.isEmpty && photo.credit.isEmpty, "blank by design so validation flags them")
    }

    @Test("A file that is not an image is refused, not written")
    func refusesNonImage() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bogus = directory.appending(path: "notes.txt")
        try Data("hello".utf8).write(to: bogus)

        #expect(throws: PhotoImporter.Failure.unreadable("notes.txt")) {
            try PhotoImporter.importPhoto(from: bogus, speciesId: "puha", existing: [], into: directory)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: CataloguePhotos.fileName(speciesId: "puha", index: 1)).path))
    }

    @Test("Deleting a file that is not there is an error, not a shrug")
    func deleteMissingReports() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: PhotoImporter.Failure.self) {
            try PhotoImporter.deleteFile(for: SpeciesPhoto(fileName: "ghost.heic", caption: "", credit: ""), in: directory)
        }
    }

    @Test("An already-encoded staged file is copied byte for byte, not re-encoded")
    func copiesCompliantHEIC() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let staged = try Self.writeHEIC(size: 800, to: directory.appending(path: "staged.heic"))
        let original = try Data(contentsOf: staged)

        let photo = try PhotoImporter.attachEncoded(
            from: staged, speciesId: "weraroa", existing: [], into: directory,
            credit: "(c) Someone (CC BY)", sourceURL: URL(string: "https://example.test/1")
        )

        #expect(photo.fileName == CataloguePhotos.fileName(speciesId: "weraroa", index: 1))
        #expect(photo.credit == "(c) Someone (CC BY)")
        #expect(photo.caption.isEmpty, "blank by design so validation flags it")
        let written = try Data(contentsOf: directory.appending(path: photo.fileName))
        #expect(written == original, "a second lossy pass would soften exactly the detail the frame was kept for")
    }

    @Test("Anything not already compliant still goes through the encoder")
    func reEncodesNonCompliant() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try Self.writePNG(size: 2000, to: directory.appending(path: "big.png"))

        let photo = try PhotoImporter.attachEncoded(
            from: source, speciesId: "puha", existing: [], into: directory
        )

        let written = directory.appending(path: photo.fileName)
        let bytes = try #require(try FileManager.default.attributesOfItem(atPath: written.path)[.size] as? Int)
        #expect(bytes <= CataloguePhotos.maximumBytesPerPhoto)
        let image = try #require(CGImageSourceCreateWithURL(written as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        #expect(max(image.width, image.height) <= CataloguePhotos.maximumPixelSize)
    }

    @Test("A HEIC over the per-file ceiling is re-encoded rather than copied through")
    func refusesOversizedHEIC() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let staged = directory.appending(path: "huge.heic")
        var padded = try Data(contentsOf: try Self.writeHEIC(size: 800, to: directory.appending(path: "seed.heic")))
        padded.append(Data(count: CataloguePhotos.maximumBytesPerPhoto))
        try padded.write(to: staged)

        let photo = try PhotoImporter.attachEncoded(
            from: staged, speciesId: "puha", existing: [], into: directory
        )

        let written = directory.appending(path: photo.fileName)
        let bytes = try #require(try FileManager.default.attributesOfItem(atPath: written.path)[.size] as? Int)
        #expect(bytes <= CataloguePhotos.maximumBytesPerPhoto, "the budget cannot be bypassed by naming a file .heic")
    }

    @Test("A staged copy takes the next free name, same as an import")
    func copyTakesNextFreeName() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let staged = try Self.writeHEIC(size: 400, to: directory.appending(path: "staged.heic"))
        let existing = [SpeciesPhoto(fileName: CataloguePhotos.fileName(speciesId: "puha", index: 1), caption: "a", credit: "b")]

        let photo = try PhotoImporter.attachEncoded(
            from: staged, speciesId: "puha", existing: existing, into: directory
        )

        #expect(photo.fileName == CataloguePhotos.fileName(speciesId: "puha", index: 2))
    }

    // MARK: - Fixtures

    private static func temporaryDirectory() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A HEIC already within budget, standing in for what the photo fetcher stages.
    private static func writeHEIC(size: Int, to url: URL) throws -> URL {
        let png = try writePNG(size: size, to: url.deletingPathExtension().appendingPathExtension("png"))
        let source = try #require(CGImageSourceCreateWithURL(png as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: CataloguePhotos.compressionQuality
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    /// Noisy content so the HEIC is not trivially tiny.
    private static func writePNG(size: Int, to url: URL) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        var generator = SystemRandomNumberGenerator()
        for x in stride(from: 0, to: size, by: 25) {
            for y in stride(from: 0, to: size, by: 25) {
                context.setFillColor(red: .random(in: 0...1, using: &generator), green: .random(in: 0...1, using: &generator), blue: .random(in: 0...1, using: &generator), alpha: 1)
                context.fill(CGRect(x: x, y: y, width: 25, height: 25))
            }
        }
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}
