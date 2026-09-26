//
//  BundledPhoto.swift
//  ForageNZ
//
//  Created by Inti Albuquerque on 22/09/2026.
//


/// Loads a catalogue photo from the app bundle.

import SwiftUI

struct BundledPhoto: View {
    let fileName: String

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
    private var loadedImage: UIImage? {
        guard let url = Bundle.main.url(
            forResource: fileName,
            withExtension: nil,
            subdirectory: CataloguePhotos.directoryName
        ) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
