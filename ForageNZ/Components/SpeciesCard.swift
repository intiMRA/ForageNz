import DesignLibrary
import SwiftUI

/// The chrome every list card shares: a square thumbnail and a heading beside it, on a
/// rounded, shadowed background.
///
/// `SpeciesRow` and `LookalikeCardView` are the two, and they were the same twenty lines
/// twice — same padding, same radius, same shadow, same thumbnail frame, same two-line
/// heading. Only the background colour and what fills the columns differ, so those are the
/// parameters and the rest lives here. A third card should use these, not copy them.

/// The rounded, shadowed slab a list card sits on.
struct SpeciesCard<Content: View>: View {
    let background: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: .small) {
            content
        }
        .padding(.all, .xSmall)
        .frame(maxWidth: .infinity)
        .background {
            Layout.rowCardShape
                .fill(background)
                .shadow(color: .shadow, radius: Layout.cardShadowRadius)
        }
    }
}

/// The square photo at the leading edge of a list card. Falls back to `BundledPhoto`'s own
/// placeholder when the entry has no photo, which is most of the catalogue.
struct SpeciesThumbnail: View {
    let fileName: String?

    var body: some View {
        BundledPhoto(fileName: fileName ?? "", maxPixelSize: Layout.thumbnailDecodePixelSize)
            .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
            .clipShape(Layout.rowCardShape)
    }
}

/// A card's name and scientific name. The identifier goes on the common name because that is
/// the element the UI tests and a screen reader land on.
struct SpeciesCardTitle: View {
    let commonName: String
    let scientificName: String?
    let accessibilityIdentifier: String

    var body: some View {
        Group {
            Text(commonName)
                .font(.headline)
                .accessibilityIdentifier(accessibilityIdentifier)
                .foregroundStyle(.primary)

            Text(scientificName ?? "")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.bottom, .xSmall)
        }
    }
}
