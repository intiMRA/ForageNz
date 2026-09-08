import DesignLibrary
import ForageCatalogue
import SwiftUI

struct SpeciesRow: View {
    let species: ForageSpecies

    var body: some View {
        HStack(alignment: .top, spacing: .small) {
            Image(systemName: species.category.symbolName)
                .imageScale(.large)
                .foregroundStyle(species.caution.tintColor)
                .frame(width: Layout.rowIconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .xxxSmall) {
                Text(species.commonName)
                    .font(.headline)

                Text(species.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)

                Text(species.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: .xSmall) {
                    CautionBadge(level: species.caution)

                    Text(species.seasonDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if species.highestLookalikeRisk == .deadly, species.caution != .doNotEat {
                        Label("Deadly lookalike", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LookalikeRisk.deadly.tintColor)
                    }
                }
                .padding(.top, .xxxSmall)
            }
        }
        .padding(.vertical, .xxSmall)
    }
}
