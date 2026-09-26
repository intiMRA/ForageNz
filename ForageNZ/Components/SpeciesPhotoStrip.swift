import DesignLibrary
import SwiftUI

/// Identification photos for one species, with the caption and credit each one carries.
///
/// Captions are shown rather than hidden behind a tap: "the stem base" is the whole reason
/// the photo is useful, and credits are a licence obligation.
struct SpeciesPhotoStrip: View {
    let species: ForageSpecies

    var body: some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            if !species.photos.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: .small) {
                        ForEach(species.photos) { photo in
                            photoCard(photo)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if let url = species.moreImagesURL {
                VStack(alignment: .leading, spacing: .xxxSmall) {
                    Link(destination: url) {
                        HStack(spacing: .xxSmall) {
                            Image(systemName: "safari")
                                .icon(size: .small, color: .accent)
                            VStack(alignment: .leading, spacing: .empty) {
                                Text("More photos on the web")
                                    .font(.caption)
                                
                                Text("Requires internet connection.")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func photoCard(_ photo: SpeciesPhoto) -> some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            BundledPhoto(fileName: photo.fileName)
                .frame(width: Layout.photoWidth, height: Layout.photoHeight)
                .clipShape(Layout.cardShape)

            Text(photo.caption)
                .font(.caption)
                .lineLimit(3)

            Text(photo.credit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
                .lineLimit(3)
        }
        .frame(width: Layout.photoWidth)
    }
}
