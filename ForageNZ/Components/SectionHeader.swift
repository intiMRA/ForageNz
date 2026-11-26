import DesignLibrary
import SwiftUI

/// The icon-and-title line that opens each section of a species page and of its recipes.
struct SectionHeader: View {
    let image: Image
    let title: LocalizedStringResource
    var subTitle: String?
    /// Where the icon sits against a two-line title. Centred by default; `.top` lines it up
    /// with the title rather than between title and subtitle.
    var alignment: VerticalAlignment = .center

    var body: some View {
        HStack(alignment: alignment, spacing: .xxSmall) {
            image
                .icon(size: .small, color: .primary)
            VStack(alignment: .leading, spacing: .empty) {
                Text(title)
                    .font(.callout)
                    .bold()
                if let subTitle {
                    Text(subTitle)
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
