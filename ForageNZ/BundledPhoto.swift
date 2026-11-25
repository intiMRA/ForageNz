//
//  BundledPhoto.swift
//  ForageNZ
//
//  Created by Inti Albuquerque on 22/09/2026.
//

/// Loads a catalogue photo from the app bundle.

import ImageIO
import SwiftUI
import UIKit

struct BundledPhoto: View {
    let fileName: String

    /// Longest edge to decode, in pixels. Sized to the slot the photo lands in — see
    /// `image(named:maxPixelSize:)` for why this is not simply the file's own size.
    var maxPixelSize: Int = Layout.photoDecodePixelSize

    var body: some View {
        // Cached, so a redraw or a re-shown row does not decode the HEIC again. Decoded on
        // the main thread on a miss: decoding every row off it, each landing as its own state
        // change, flooded the app on long lists until it stopped responding.
        if let image = Self.image(named: fileName, maxPixelSize: maxPixelSize) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Layout.cardShape
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }

    /// The decode behind the view, also used directly by the zoomable full-screen viewer,
    /// which needs a `UIImage` rather than a view. Cached, so a photo seen once is not
    /// decoded again.
    ///
    /// Photos ship as a folder reference; `CatalogueTests` asserts that layout, so there is
    /// no second place to look.
    ///
    /// Decoded as a downsampled thumbnail rather than with `UIImage(contentsOfFile:)`, for a
    /// correctness reason before a performance one. Every shipped photo is a **grid-tiled**
    /// HEIC, and decoding one whole opens a VideoToolbox tile session, which intermittently
    /// fails with "Format description changes not supported in tile sessions" and hands back
    /// a **black frame instead of an error**. `UIImage` is non-nil, so the placeholder
    /// never runs and the slot renders solid black — which is exactly what it looked like.
    /// `CGImageSourceCreateThumbnailAtIndex` downsamples without that session.
    ///
    /// It is also far cheaper: a 100pt slot was decoding four tiles of a 1024px image.
    nonisolated static func image(named fileName: String, maxPixelSize: Int) -> UIImage? {
        let key = BundledPhotoCache.Key(fileName: fileName, maxPixelSize: maxPixelSize)
        if let cached = BundledPhotoCache.shared.image(for: key) {
            return cached
        }
        guard
            let url = Bundle.main.url(
                forResource: fileName,
                withExtension: nil,
                subdirectory: CataloguePhotos.directoryName
            ),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else {
            return nil
        }

        let options: [CFString: Any] = [
            // Always build from the full image: an embedded thumbnail, where one exists, is
            // too small for a card and carries no orientation guarantee.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            // Decode now, so the cached image is already decoded and never decoded again at
            // draw time.
            kCGImageSourceShouldCacheImmediately: true,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        BundledPhotoCache.shared.insert(image, for: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}

/// Decoded catalogue photos, so a photo is decoded once per size rather than every time its
/// row is drawn. Bounded by decoded bytes; the system also empties it under memory pressure.
///
/// `@unchecked Sendable` because `NSCache` is documented as thread-safe but not annotated,
/// and `image(named:maxPixelSize:)` may be called from any thread.
nonisolated final class BundledPhotoCache: @unchecked Sendable {
    static let shared = BundledPhotoCache()

    /// One photo at one decode size — a thumbnail and a full-screen decode are different
    /// images.
    struct Key: Hashable, Sendable {
        let fileName: String
        let maxPixelSize: Int
    }

    private let cache = NSCache<KeyBox, UIImage>()

    /// About 60 list thumbnails plus a few full-screen photos.
    private static let costLimit = 64 * 1024 * 1024

    init() {
        cache.totalCostLimit = Self.costLimit
    }

    func image(for key: Key) -> UIImage? {
        cache.object(forKey: KeyBox(key))
    }

    func insert(_ image: UIImage, for key: Key, cost: Int) {
        cache.setObject(image, forKey: KeyBox(key), cost: cost)
    }

    /// `NSCache` keys must be objects, and compare by `isEqual(_:)` and `hash`.
    private final class KeyBox: NSObject {
        let key: Key

        init(_ key: Key) {
            self.key = key
        }

        override func isEqual(_ object: Any?) -> Bool {
            (object as? KeyBox)?.key == key
        }

        override var hash: Int { key.hashValue }
    }
}
