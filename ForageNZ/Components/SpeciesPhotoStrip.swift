import DesignLibrary
import ForageCatalogue
import SwiftUI

/// Identification photos for one species, with the caption and credit each one carries.
///
/// Captions are shown rather than hidden behind a tap: "the stem base" is the whole reason
/// the photo is useful, and credits are a licence obligation.
struct SpeciesPhotoStrip: View {
    let species: ForageSpecies

    var body: some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: .small) {
                    ForEach(species.photos) { photo in
                        photoCard(photo)
                    }
                }
            }
            .scrollIndicators(.visible)

            if let url = species.moreImagesURL {
                Link(destination: url) {
                    Label("More photos on the web", systemImage: "safari")
                        .font(.subheadline)
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
                .font(.caption.weight(.medium))
                .lineLimit(3)

            Text(photo.credit)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(width: Layout.photoWidth)
    }
}

/// Loads a catalogue photo from the app bundle.
private struct BundledPhoto: View {
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

    /// Photos ship as a folder reference, so they resolve by name inside the bundle.
    private var loadedImage: UIImage? {
        guard let url = Bundle.main.url(
            forResource: fileName,
            withExtension: nil,
            subdirectory: CataloguePhotos.directoryName
        ) ?? Bundle.main.url(forResource: fileName, withExtension: nil) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
