import Foundation

/// One identification photo shipped with the app.
///
/// The caption is not decoration: a photo without "this is the stem base" or "gills at
/// maturity" is close to useless for identification, which is the whole reason these are
/// here. The credit is a licence obligation — CC BY requires attribution, and the app
/// displays it.
public nonisolated struct SpeciesPhoto: Codable, Sendable, Hashable, Identifiable {
    /// File name inside the catalogue's photo directory. Not a path — the app resolves it
    /// against its bundle, the editor against the repo.
    public let fileName: String
    /// Which feature this photo shows.
    public let caption: String
    /// Attribution as it must be displayed, e.g. "© Jane Doe, some rights reserved (CC BY)".
    public let credit: String
    /// Where the photo came from, for licence provenance.
    public let sourceURL: URL?

    public var id: String { fileName }

    public init(fileName: String, caption: String, credit: String, sourceURL: URL? = nil) {
        self.fileName = fileName
        self.caption = caption
        self.credit = credit
        self.sourceURL = sourceURL
    }
}

public enum CataloguePhotos {
    /// Directory holding the shipped photos, relative to the repo root.
    public static let directoryName = "Photos"

    /// Longest edge, in pixels. Enough to zoom into a leaf margin; not enough to bloat.
    public static let maximumPixelSize = 1400

    /// HEIC quality. Lossless is not an option for photographs — see the budget below.
    public static let compressionQuality = 0.62

    /// Per-file ceiling. A photo over this has been mis-encoded.
    public static let maximumBytesPerPhoto = 220_000

    /// Total ceiling for every photo in the catalogue, since they ship in the app.
    public static let totalByteBudget = 24_000_000

    /// How many photos an entry wants before it is genuinely identifiable.
    public static let recommendedCount = 4

    public static func fileName(speciesId: String, index: Int) -> String {
        "\(speciesId)-\(index).heic"
    }
}
