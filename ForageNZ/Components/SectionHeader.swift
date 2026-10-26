import DesignLibrary
import SwiftUI

/// The icon-and-title line that opens each section of a species page and of its recipes.
struct SectionHeader: View {
    let image: Image
    let title: LocalizedStringResource
    var subTitle: String?

    var body: some View {
        HStack(spacing: .xxSmall) {
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
