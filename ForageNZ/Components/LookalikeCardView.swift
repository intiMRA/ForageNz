import DesignLibrary
import ForageCatalogue
import SwiftUI

/// One "can be confused with" card. Tapping it opens the lookalike's own page — every card
/// has one, because `LookalikeCardModel.destination` is a `SpeciesID`.
struct LookalikeCardView: View {
    let model: LookalikeCardModel

    var body: some View {
        NavigationLink(value: model.destination) {
            card
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(model.accessibilityIdentifier)
    }

    private var card: some View {
        HStack(alignment: .top, spacing: .xSmall) {
            VStack(alignment: .leading, spacing: .xxxSmall) {
                HStack(spacing: .xSmall) {
                    Text(model.name)
                        .font(.subheadline.weight(.semibold))

                    Text(model.risk.displayName)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, .xSmall)
                        .padding(.vertical, .xxxSmall)
                        .foregroundStyle(.white)
                        .background(model.risk.tintColor, in: Capsule())
                }

                if let scientificName = model.scientificName {
                    Text(scientificName)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }

                Text(model.howToTell)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, .xxxSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.all, .small)
        .background(.quaternary.opacity(Layout.cardBackgroundOpacity), in: Layout.cardShape)
        .contentShape(Layout.cardShape)
    }
}
