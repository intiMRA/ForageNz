import DesignLibrary
import SwiftUI

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
