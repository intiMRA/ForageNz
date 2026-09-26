import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import ForageCatalogue

@Suite("Land status")
struct LandStatusMapTests {
    /// `LandStatusMap.groundTruth` holds the same places `Tools/build_land_status.py` checks
    /// after it rasterises. Asserting them here is the cross-language check: the Swift reader
    /// has to agree with the Python writer about which corner of the grid is north and where
    /// the bits live.
    @Test("the shipped raster agrees with the builder about known places")
    func shippedRasterMatchesGroundTruth() throws {
        let map = try #require(Self.shipped, "could not locate the shipped land-status raster")
        #expect(map.firstGroundTruthFailure() == nil)
    }

    @Test("a map that fails a known place is reported, not trusted")
    func groundTruthCatchesAWrongMap() throws {
        // Two pixels of nothing, spanning the globe: every known place reads as unrestricted,
        // so the two national parks must fail.
        let map = try Self.synthetic(pixels: [0, 0, 0, 0], degreesPerPixel: 180)
        #expect(map.firstGroundTruthFailure() == "Tongariro National Park")
    }

    @Test("coordinates outside New Zealand are not covered")
    func outsideCoverage() throws {
        let map = try #require(Self.shipped)

        #expect(!map.contains(latitude: -33.8688, longitude: 151.2093))  // Sydney
        #expect(map.status(latitude: -33.8688, longitude: 151.2093).isEmpty)
        #expect(map.contains(latitude: -41.2865, longitude: 174.7762))  // Wellington
    }

    @Test("both flags survive where layers overlap")
    func overlappingFlagsAreKept() throws {
        // Row 0 is the northern edge, so this is: top-left nothing, top-right conservation,
        // bottom-left reserve, bottom-right both.
        let map = try Self.synthetic(pixels: [
            0, 1,
            2, 3
        ])

        #expect(map.status(latitude: -0.5, longitude: 0.5) == [])
        #expect(map.status(latitude: -0.5, longitude: 1.5) == .conservation)
        #expect(map.status(latitude: -1.5, longitude: 0.5) == .marineReserve)
        #expect(map.status(latitude: -1.5, longitude: 1.5) == [.conservation, .marineReserve])
    }

    @Test("a raster whose size disagrees with its metadata is rejected")
    func sizeMismatchIsRejected() throws {
        let directory = try Self.temporaryDirectory()
        let raster = directory.appending(path: "raster.png")
        try Self.writeGrey(pixels: [0, 1, 2, 3], width: 2, height: 2, to: raster)

        let metadata = directory.appending(path: "grid.json")
        try Self.writeGrid(width: 4, height: 4, to: metadata)

        #expect(throws: LandStatusMap.Failure.sizeMismatch(expected: "4x4", actual: "2x2")) {
            try LandStatusMap(rasterURL: raster, metadataURL: metadata)
        }
    }

    @Test("a pixel outside the flag range is rejected, not folded into a flag")
    func unexpectedPixelValueIsRejected() throws {
        // Masking would turn 255 into "conservation AND marine reserve" — a confident,
        // plausible, wrong answer from a corrupted raster.
        #expect(throws: LandStatusMap.Failure.rasterUnreadable("unexpected pixel value 255")) {
            try Self.synthetic(pixels: [0, 1, 2, 255])
        }
    }

    @Test("metadata that assigns a flag to a different bit is refused")
    func flagMismatchIsRefused() throws {
        let directory = try Self.temporaryDirectory()
        let raster = directory.appending(path: "raster.png")
        try Self.writeGrey(pixels: [0, 1, 2, 3], width: 2, height: 2, to: raster)
        let metadata = directory.appending(path: "grid.json")
        try Data("""
        {"minLongitude": 0.0, "maxLongitude": 2.0, "minLatitude": -2.0, "maxLatitude": 0.0,
         "degreesPerPixel": 1.0, "width": 2, "height": 2,
         "flags": { "conservation": 2, "marineReserve": 1 }}
        """.utf8).write(to: metadata)

        let thrown = #expect(throws: LandStatusMap.Failure.self) {
            try LandStatusMap(rasterURL: raster, metadataURL: metadata)
        }
        guard case .flagMismatch = thrown else {
            Issue.record("expected .flagMismatch, got \(String(describing: thrown))"); return
        }
    }

    @Test("a missing raster is reported rather than silently empty")
    func missingRasterIsReported() throws {
        let directory = try Self.temporaryDirectory()
        let metadata = directory.appending(path: "grid.json")
        try Self.writeGrid(width: 2, height: 2, to: metadata)

        #expect(throws: LandStatusMap.Failure.rasterUnreadable("absent.png")) {
            try LandStatusMap(rasterURL: directory.appending(path: "absent.png"), metadataURL: metadata)
        }
    }
}

// MARK: - Fixtures

extension LandStatusMapTests {
    /// The raster the app ships, found next to the catalogue in the repo. Loaded once —
    /// decoding 29 million pixels per test is the slowest thing in this suite.
    static let shipped: LandStatusMap? = {
        guard let catalogue = CatalogueLocator.resolve() else { return nil }
        let directory = catalogue.deletingLastPathComponent()
        return try? LandStatusMap(
            rasterURL: directory.appending(path: "\(LandStatusMap.shippedResourceName).png"),
            metadataURL: directory.appending(path: "\(LandStatusMap.shippedResourceName).json")
        )
    }()

    /// A 2x2 map anchored at longitude 0 and latitude 0, running east and south.
    static func synthetic(pixels: [UInt8], degreesPerPixel: Double = 1) throws -> LandStatusMap {
        let directory = try temporaryDirectory()
        let raster = directory.appending(path: "raster.png")
        let metadata = directory.appending(path: "grid.json")
        try writeGrey(pixels: pixels, width: 2, height: 2, to: raster)
        try writeGrid(width: 2, height: 2, degreesPerPixel: degreesPerPixel, to: metadata)
        return try LandStatusMap(rasterURL: raster, metadataURL: metadata)
    }

    static func temporaryDirectory() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func writeGrey(pixels: [UInt8], width: Int, height: Int, to url: URL) throws {
        var pixels = pixels
        let image = try #require(
            pixels.withUnsafeMutableBytes { buffer in
                CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                )?.makeImage()
            }
        )
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    static func writeGrid(width: Int, height: Int, degreesPerPixel: Double = 1, to url: URL) throws {
        let grid = """
        {
          "minLongitude": 0.0,
          "maxLongitude": \(Double(width) * degreesPerPixel),
          "minLatitude": \(-Double(height) * degreesPerPixel),
          "maxLatitude": 0.0,
          "degreesPerPixel": \(degreesPerPixel),
          "width": \(width),
          "height": \(height),
          "flags": { "conservation": 1, "marineReserve": 2 }
        }
        """
        try Data(grid.utf8).write(to: url)
    }
}
