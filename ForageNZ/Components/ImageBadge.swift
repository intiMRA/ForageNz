import DesignLibrary
import SwiftUI

/// Marks an entry nobody has finished checking. Only ever on screen in a debug build, where
/// the drawer's "Show unverified entries" flag has let the drafts out of `SpeciesStore` —
/// so it is the one badge that does not describe the species, but the state of its page.
///
/// Deliberately not a caution colour: it is a claim about the entry, not about the plant.
struct UnverifiedBadge: View {
    var size: Badge.Size = .small

    var body: some View {
        Badge(image: .tinted(Image(systemName: "questionmark.circle")), title: "Unverified", size: size)
    }
}

/// Marks a draft whose remaining prose cannot be found online — the web has been searched and
/// had nothing usable, so it is waiting on a printed page rather than on someone's time.
///
/// Sits beside `UnverifiedBadge` and under the same rule: debug builds only, and a claim about
/// the entry rather than about the plant, so it takes no caution colour.
struct BookOnlyBadge: View {
    var size: Badge.Size = .small

    var body: some View {
        Badge(image: .tinted(Image(systemName: "book.closed")), title: "Book only", size: size)
    }
}

struct Badge: View {
    enum Size {
        case small, medium, large
        
        var font: Font {
            switch self {
            case .small:
                return .caption
            case .medium:
                    return .subheadline
            case .large:
                return .body
            }
        }
        
        var iconSize: IconSize {
            switch self {
            case .small:
                return .small
            case .medium:
                return .standard
            case .large:
                return .large
            }
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme

    let image: BadgeIcon
    let title: LocalizedStringResource
    let size: Size
    /// A flat colour draws at full strength, exactly as it always has; only a ramp is dimmed
    /// to badge strength, and `psychoactive` is the only one there is.
    var color: CardFill = .tint(.standardbadge)
    var forgroundColor: Color = .primary
    var fontWeight: Font.Weight = .semibold

    var body: some View {
        HStack(spacing: .xxSmall) {
                switch image {
                case .tinted(let image):
                    image.icon(size: size.iconSize, color: .primary)
                case .original(let image):
                    // Same box as `icon(size:color:)` gives, without its `renderingMode(.template)`
                    // — that is the modifier that would flatten the drawing to one colour.
                    // `foregroundStyle` below does not reach a non-template image, so the
                    // artwork survives the badge's own tinting too.
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.iconSize.value(), height: size.iconSize.value())
                }
                Text(title)
                .font(size.font.weight(fontWeight))
        }
        .padding(.all, .xSmall)
        .foregroundStyle(forgroundColor)
        .background(color.style(.badge, in: colorScheme))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
