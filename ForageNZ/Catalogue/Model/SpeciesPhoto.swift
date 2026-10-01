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

public nonisolated enum CataloguePhotos {
    /// Directory holding the shipped photos, relative to the repo root.
    public static let directoryName = "Photos"

    /// Longest edge, in pixels.
    ///
    /// Sized against what the app actually draws, not against what a photo could hold. The
    /// detail strip decodes at `Layout.photoDecodePixelSize` (720) and the list thumbnails at
    /// 360; there is no zoom gesture and no full-screen viewer, so 1000 leaves ~1.4× headroom
    /// for a larger iPad layout or a zoom view added later, and every pixel above that is
    /// decoded away unseen.
    ///
    /// Previously 1400, which was the direct cause of the catalogue not fitting: full coverage
    /// at that size is ~230 MB against a 180 MB budget. **This constant is what buys full
    /// coverage — the budget was never the obstacle.**
    ///
    /// Measured by re-encoding a 40-file random sample of the staging pool at each size, not
    /// estimated. Bytes do **not** scale with pixel count the way a first guess suggests —
    /// HEIC keeps more than the area ratio predicts, so 1000 px is 0.68× of 1400 px, not the
    /// 0.51× that (1000/1400)² implies. Assume measurement, not arithmetic, before changing it:
    ///
    ///     px    mean    1,366 photos
    ///     1400  169 KB  230 MB
    ///     1100  125 KB  171 MB
    ///     1000  113 KB  154 MB   ← here
    ///      900   99 KB  135 MB
    ///      800   85 KB  116 MB
    ///
    /// 154 MB leaves ~26 MB of headroom, about 230 more photos or 57 more entries. If the
    /// catalogue grows much past 337, drop to 900 — still 1.25× the 720 px ever rendered.
    ///
    /// The 225 photos already in the catalogue are left at their original sizes (768–1400).
    /// Re-encoding them would be lossy-on-lossy for 15 MB, the source downloads are gone, and
    /// mixed sizes were already the norm.
    public static let maximumPixelSize = 1000

    /// HEIC quality. Lossless is not an option for photographs — see the budget below.
    public static let compressionQuality = 0.62

    /// Per-file ceiling. A photo over this has been mis-encoded.
    ///
    /// Deliberately **not** lowered alongside `maximumPixelSize`. It is a defect detector, not
    /// a size lever: at 1000 px the mean is ~84 KB, so 220 KB is still 2.6× mean and catches a
    /// genuinely bad encode, while lowering it would flag the 225 correctly-encoded 1400 px
    /// photos already shipped as if something were wrong with them.
    public static let maximumBytesPerPhoto = 220_000

    /// Total ceiling for every photo in the catalogue, since they ship in the app.
    ///
    /// This is a **download-size** limit, and nothing else. It is deliberately not a limit on
    /// how many entries get photographed: `recommendedCount` says every entry wants four, so
    /// coverage follows the size of the catalogue. A total that bites before then would make
    /// the next question "which species goes without photos", which is the wrong question for
    /// an offline guide — the embedded photo is all the user will ever have in a gully.
    ///
    /// Sized from the one real threshold rather than from whatever was in the folder. Apple
    /// permits 4 GB uncompressed, and since iOS 13 there is no hard cellular cap — but the
    /// App Store's default "Ask If Over 200 MB" setting prompts above 200 MB, and a prompt is
    /// a download people abandon. 180 MB leaves room beneath that line for everything else the
    /// app ships, which is small: land-status raster 220 KB, `Assets.car` 300 KB,
    /// `species.json` 1 MB, DesignLibrary 600 KB. The release download is photos plus ~3 MB.
    ///
    /// **Full coverage fits, and the figure to check it against is `maximumPixelSize`, not this
    /// one.** `recommendedCount` wants 1,366 photos (4 per entry, 6 for the 9 with a deadly
    /// lookalike, over 337 entries); at 1000 px that measures ~154 MB. An earlier version of
    /// this comment claimed the same coverage at "~160 MB, mean 119 KB" — that mean was stale,
    /// dragged down by an early batch encoded at 768–1024 px, and the real figure at the
    /// then-current 1400 px was ~230 MB. If coverage stops fitting again, the pixel size is the
    /// lever; raising this number walks into the download prompt.
    ///
    /// Previously 40 MB, itself raised from 24 MB — both set by what the catalogue happened to
    /// hold at the time, so the constant tripped whenever the catalogue got *more complete*
    /// rather than when anything was wrong. `maximumBytesPerPhoto` is the check that catches a
    /// real defect; this one only guards the download.
    public static let totalByteBudget = 180_000_000

    /// How many photos an entry wants before it is genuinely identifiable.
    ///
    /// Higher for anything with a deadly lookalike. There is no signal in a gully, so the
    /// embedded photos are all the user will ever have — a link to more is a desk
    /// affordance, not a field one. The harder the call, the more the guide must carry.
    public static func recommendedCount(hasDeadlyLookalike: Bool) -> Int {
        hasDeadlyLookalike ? 6 : 4
    }

    /// What counts as a photo on disk — for orphan detection and evaluation sets alike, so
    /// the two cannot disagree about whether a `.webp` is a photo.
    public static let imageExtensions: Set<String> = ["heic", "heif", "jpg", "jpeg", "png", "webp"]

    public static func isImageFile(_ name: String) -> Bool {
        imageExtensions.contains(URL(fileURLWithPath: name).pathExtension.lowercased())
    }

    public static func fileName(speciesId: String, index: Int) -> String {
        "\(speciesId)-\(index).heic"
    }
}
