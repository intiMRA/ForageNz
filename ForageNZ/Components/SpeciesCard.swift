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
    @Environment(\.colorScheme) private var colorScheme

    let background: CardFill
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: .small) {
            content
        }
        .padding(.all, .xSmall)
        .frame(maxWidth: .infinity)
        .background {
            switch background {
            case .tint(let color):
                Layout.rowCardShape
                    .fill(color)
                    .shadow(color: .shadow, radius: Layout.cardShadowRadius)

            case .ramp:
                // Two layers, and the opaque one underneath is the point. `shadow` is **white
                // at 50% in dark mode**, so drawn as a single layer that glow sits behind the
                // shape and shows straight *through* a translucent fill. On the psychoactive
                // ramp it was measurable: the card came out #A72EA5 at the top where the ramp
                // alone gives #7F017B, with a green channel of 46 that magenta #FF03F7 cannot
                // produce at all.
                //
                // The base is the list's own backdrop, so nothing changes except the shadow
                // going outside the card. Not `.background`, which is pure white in light mode
                // — brighter than the grouped background the list actually draws, and it
                // washed the light cards out in the other direction.
                //
                // The flat cases opt out on purpose. They have the same glow through them, but
                // it is part of how the owner's colours have always looked, and this is a fix
                // for the ramp, not a repaint of the catalogue.
                Layout.rowCardShape
                    .fill(Color(uiColor: .systemGroupedBackground))
                    .shadow(color: .shadow, radius: Layout.cardShadowRadius)
                    .overlay {
                        Layout.rowCardShape.fill(background.style(.card, in: colorScheme))
                    }
            }
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
