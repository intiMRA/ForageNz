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
        Badge(image: Image(systemName: "questionmark.circle"), title: "Unverified", size: size)
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
    
    let image: Image
    let title: LocalizedStringResource
    let size: Size
    var color: Color = .standardbadge
    var forgroundColor: Color = .primary
    var fontWeight: Font.Weight = .semibold
    
    var body: some View {
        HStack(spacing: .xxSmall) {
                image
                    .icon(size: size.iconSize, color: .primary)
                Text(title)
                .font(size.font.weight(fontWeight))
        }
        .padding(.all, .xSmall)
        .foregroundStyle(forgroundColor)
        .background(color)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
