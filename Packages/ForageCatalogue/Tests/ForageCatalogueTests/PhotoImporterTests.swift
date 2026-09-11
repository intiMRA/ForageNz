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

    // MARK: - Fixtures

    private static func temporaryDirectory() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
