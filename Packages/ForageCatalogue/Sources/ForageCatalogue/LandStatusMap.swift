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
/// Deliberately coarse: roughly 300 m per pixel, generalised from DOC's own layers. It
/// answers "you are probably on conservation land, check before you pick" — never a legal
/// determination, and every caller must present it that way. Boundaries are approximate and
/// holes inside conservation land are not modelled, so it errs towards saying a permit may
/// be needed, which is the safe direction.
public struct LandStatusMap: Sendable {
    /// Base name of the two bundled files, `<name>.png` and `<name>.json`.
    public static let shippedResourceName = "land-status"

    /// What to tell a user the map's resolution is. The builder emits 0.0025° ≈ 278 m; this is
    /// that figure rounded up, because "about 300 m" is honest and "278 m" implies a precision
    /// the raster does not have.
    public static let approximateResolutionMetres = 300

    public struct Grid: Codable, Sendable, Hashable {
        public let minLongitude: Double
        public let maxLongitude: Double
        public let minLatitude: Double
        public let maxLatitude: Double
        public let degreesPerPixel: Double
        public let width: Int
        public let height: Int
        /// The bit each flag occupies, as the builder wrote it. Checked against `LandStatus`
        /// on load so the two sides of the contract cannot drift silently.
        public let flags: Flags

        public struct Flags: Codable, Sendable, Hashable {
            public let conservation: UInt8
            public let marineReserve: UInt8
        }

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
        /// The builder assigned a flag to a different bit than this code expects.
        case flagMismatch(String)
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

        guard grid.flags.conservation == LandStatus.conservation.rawValue,
              grid.flags.marineReserve == LandStatus.marineReserve.rawValue else {
            throw .flagMismatch(
                "metadata says conservation=\(grid.flags.conservation) marineReserve=\(grid.flags.marineReserve); "
                + "this build expects \(LandStatus.conservation.rawValue) and \(LandStatus.marineReserve.rawValue)"
            )
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
            let value = grey[index]
            guard value != 0 else { continue }
            // Masking instead would fold an unexpected value into a plausible flag set —
            // 255 would read as "conservation land AND marine reserve" — which is exactly
            // the pipeline corruption this type claims to catch, made invisible.
            guard value <= pixelMask else {
                throw .rasterUnreadable("unexpected pixel value \(value)")
            }
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
    ///
    /// Every flag needs a point of its own. A check that only looks at `conservation` leaves
    /// `marineReserve` guarded by nothing, and the reserve bit is the one carrying the
    /// absolute prohibition.
    public static let groundTruth: [(name: String, latitude: Double, longitude: Double, expected: LandStatus)] = [
        ("Tongariro National Park", -39.2800, 175.5600, .conservation),
        ("Fiordland National Park", -45.4000, 167.7000, .conservation),
        ("Poor Knights Islands", -35.4667, 174.7333, .marineReserve),
        ("Goat Island", -36.2686, 174.7967, [.conservation, .marineReserve]),
        ("Wellington CBD", -41.2865, 174.7762, []),
        ("Hamilton CBD", -37.7870, 175.2793, [])
    ]

    /// The first known place this map gets wrong, or `nil` if it gets them all right.
    /// Only meaningful for the shipped New Zealand raster.
    public func firstGroundTruthFailure() -> String? {
        Self.groundTruth.first { point in
            status(latitude: point.latitude, longitude: point.longitude) != point.expected
        }?.name
    }
}
