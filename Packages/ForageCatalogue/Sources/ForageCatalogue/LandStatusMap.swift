import CoreGraphics
import Foundation
import ImageIO

/// What the law says about taking things where you are standing.
public struct LandStatus: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// DOC public conservation land — harvesting plant material needs a permit.
    public static let conservation = LandStatus(rawValue: 1)
    /// Marine reserve — no taking of anything, ever.
    public static let marineReserve = LandStatus(rawValue: 2)
}

/// Offline lookup of land status from a bundled raster.
///
/// Deliberately coarse: roughly 280 m per pixel, generalised from DOC's own layers. It
/// answers "you are probably on conservation land, check before you pick" — never a legal
/// determination, and every caller must present it that way. Boundaries are approximate and
/// holes inside conservation land are not modelled, so it errs towards saying a permit may
/// be needed, which is the safe direction.
public struct LandStatusMap: Sendable {
    public struct Grid: Codable, Sendable, Hashable {
        public let minLongitude: Double
        public let maxLongitude: Double
        public let minLatitude: Double
        public let maxLatitude: Double
        public let degreesPerPixel: Double
        public let width: Int
        public let height: Int

        /// Image row 0 is the northern edge, so latitude is flipped.
        func pixel(latitude: Double, longitude: Double) -> (x: Int, y: Int)? {
            guard longitude >= minLongitude, longitude < maxLongitude,
                  latitude > minLatitude, latitude <= maxLatitude else { return nil }
            let x = Int((longitude - minLongitude) / degreesPerPixel)
            let y = Int((maxLatitude - latitude) / degreesPerPixel)
            guard x >= 0, x < width, y >= 0, y < height else { return nil }
            return (x, y)
        }
    }

    public enum Failure: Error, Sendable, Equatable {
        case metadataUnreadable(String)
        case rasterUnreadable(String)
        case sizeMismatch(expected: String, actual: String)
    }

    public let grid: Grid
    /// Two bits per pixel, four pixels per byte — the decoded 8-bit form would be ~29 MB.
    private let packed: [UInt8]

    private static let pixelsPerByte = 4
    private static let bitsPerPixel = 2
    private static let pixelMask: UInt8 = 0b11

    public init(rasterURL: URL, metadataURL: URL) throws(Failure) {
        let grid: Grid
        do {
            grid = try JSONDecoder().decode(Grid.self, from: Data(contentsOf: metadataURL))
        } catch {
            throw .metadataUnreadable(String(describing: error))
        }

        guard let source = CGImageSourceCreateWithURL(rasterURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw .rasterUnreadable(rasterURL.lastPathComponent)
        }
        guard image.width == grid.width, image.height == grid.height else {
            throw .sizeMismatch(
                expected: "\(grid.width)x\(grid.height)",
                actual: "\(image.width)x\(image.height)"
            )
        }

        self.grid = grid
        self.packed = try Self.pack(image: image, grid: grid)
    }

    /// Redraws into an 8-bit grey buffer, then packs to two bits per pixel and drops it.
    private static func pack(image: CGImage, grid: Grid) throws(Failure) -> [UInt8] {
        let count = grid.width * grid.height
        var grey = [UInt8](repeating: 0, count: count)

        let drawn: Bool = grey.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress,
                  let context = CGContext(
                      data: base,
                      width: grid.width,
                      height: grid.height,
                      bitsPerComponent: 8,
                      bytesPerRow: grid.width,
                      space: CGColorSpaceCreateDeviceGray(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: grid.width, height: grid.height))
            return true
        }
        guard drawn else { throw .rasterUnreadable("could not rasterise") }

        var packed = [UInt8](repeating: 0, count: (count + pixelsPerByte - 1) / pixelsPerByte)
        for index in 0..<count {
            let value = grey[index] & pixelMask
            guard value != 0 else { continue }
            let shift = (index % pixelsPerByte) * bitsPerPixel
            packed[index / pixelsPerByte] |= value << UInt8(shift)
        }
        return packed
    }

    /// Status at a coordinate. Empty both for "nothing applies" and for anywhere outside
    /// New Zealand — the caller should check `contains` if it needs to tell them apart.
    public func status(latitude: Double, longitude: Double) -> LandStatus {
        guard let (x, y) = grid.pixel(latitude: latitude, longitude: longitude) else { return [] }
        let index = y * grid.width + x
        let shift = (index % Self.pixelsPerByte) * Self.bitsPerPixel
        return LandStatus(rawValue: (packed[index / Self.pixelsPerByte] >> UInt8(shift)) & Self.pixelMask)
    }

    /// Whether a coordinate falls inside the raster's coverage at all.
    public func contains(latitude: Double, longitude: Double) -> Bool {
        grid.pixel(latitude: latitude, longitude: longitude) != nil
    }

    // MARK: - Ground truth

    /// Places whose status is not in doubt, mirroring the builder's own smoke test.
    ///
    /// The raster travels through Xcode's asset pipeline and ImageIO before anyone reads it,
    /// and either could quietly re-map values or flip an axis. A map that is upside down
    /// still answers every query — with the wrong answer — so it has to be caught.
    public static let groundTruth: [(name: String, latitude: Double, longitude: Double, expected: LandStatus)] = [
        ("Tongariro National Park", -39.2800, 175.5600, .conservation),
        ("Fiordland National Park", -45.4000, 167.7000, .conservation),
        ("Wellington CBD", -41.2865, 174.7762, []),
        ("Hamilton CBD", -37.7870, 175.2793, [])
    ]

    /// The first known place this map gets wrong, or `nil` if it gets them all right.
    /// Only meaningful for the shipped New Zealand raster.
    public func firstGroundTruthFailure() -> String? {
        Self.groundTruth.first { point in
            status(latitude: point.latitude, longitude: point.longitude)
                .contains(.conservation) != point.expected.contains(.conservation)
        }?.name
    }
}
