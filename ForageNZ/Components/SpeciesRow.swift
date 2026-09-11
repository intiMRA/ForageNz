import DesignLibrary
import ForageCatalogue
import SwiftUI

struct SpeciesRow: View {
    let model: ListingRowModel

    var body: some View {
        HStack(alignment: .top, spacing: .small) {
            Image(systemName: model.categorySymbolName)
                .imageScale(.large)
                .foregroundStyle(model.caution.tintColor)
                .frame(width: Layout.rowIconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .xxxSmall) {
                Text(model.commonName)
                    .font(.headline)
                    .accessibilityIdentifier("speciesRow.\(model.speciesID.rawValue)")

                Text(model.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)

                Text(model.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: .xSmall) {
                    CautionBadge(level: model.caution)

                    Text(model.seasonDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if model.hasDeadlyLookalike {
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
