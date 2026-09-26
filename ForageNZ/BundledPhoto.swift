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
    /// `loadedImage` for why this is not simply the file's own size.
    var maxPixelSize: Int = Layout.photoDecodePixelSize

    var body: some View {
        if let image = loadedImage {
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

    /// Photos ship as a folder reference; `CatalogueTests` asserts that layout, so there is
    /// no second place to look.
    ///
    /// Decoded as a downsampled thumbnail rather than with `UIImage(contentsOfFile:)`, for a
    /// correctness reason before a performance one. Every shipped photo is a **grid-tiled**
    /// HEIC, and decoding one whole opens a VideoToolbox tile session, which intermittently
    /// fails with "Format description changes not supported in tile sessions" and hands back
    /// a **black frame instead of an error**. `UIImage` is non-nil, so the placeholder below
    /// never runs and the slot renders solid black — which is exactly what it looked like.
    /// `CGImageSourceCreateThumbnailAtIndex` downsamples without that session.
    ///
    /// It is also far cheaper: a 100pt slot was decoding four tiles of a 1024px image.
    private var loadedImage: UIImage? {
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
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}
