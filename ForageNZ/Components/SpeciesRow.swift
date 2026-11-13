import DesignLibrary
import SwiftUI

/// `belowPhoto` and `besideBadge` are for cards that carry a little more than the listing —
/// the map's find card puts its date and delete button there. Lists leave them empty.
struct SpeciesRow<BelowPhoto: View, BesideBadge: View>: View {
    let model: ListingRowModel
    @ViewBuilder var belowPhoto: BelowPhoto
    @ViewBuilder var besideBadge: BesideBadge

    var body: some View {
        SpeciesCard(background: model.caution.rowBackground) {
            leftView
            rightView
        }
    }

    var leftView: some View {
        VStack(alignment: .leading) {
            SpeciesThumbnail(fileName: model.photoFileName)
            belowPhoto
            Spacer()
            groupView
        }
    }
    
    var rightView: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                infoView
                Spacer()
                HStack(alignment: .top, spacing: .xxSmall) {
                    VStack(alignment: .trailing, spacing: .xxSmall) {
                        Badge(
                            image: model.caution.badgeIcon,
                            title: model.caution.shortLabel,
                            size: .small,
                            color: model.caution.tintColor,
                            forgroundColor: model.caution.badgeForeground
                        )
                        // Debug builds only — a shipped row is never unverified.
                        if model.isUnverified {
                            UnverifiedBadge()
                        }
                        if model.needsBookSource {
                            BookOnlyBadge()
                        }
                    }
                    besideBadge
                }
            }
            
            Spacer()
            
            HStack(alignment: .top) {
                seasonView
                Spacer()
                habitatView
            }
        }
    }
    
    var groupView: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            Text("Group:")
                .bold()
                .font(.footnote)
            model.group.image
                .icon(size: .standard, color: .primary)
        }
        
    }
    
    /// Nothing at all for an unclassified entry — an empty space where a line belongs reads
    /// as a missing value, so the label goes with the icons.
    @ViewBuilder
    var habitatView: some View {
        if !model.habitats.isEmpty {
            VStack(alignment: .leading, spacing: .xxxSmall) {
                Text("Habitat:")
                    .bold()
                    .font(.footnote)
                HabitatView(habitats: model.habitats, layoutDirection: .rightToLeft)
            }
        }
    }

    var seasonView: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            Text("Season:")
                .bold()
                .font(.footnote)
            Text(model.seasonDescription)
                .font(model.seasonDescription.contains(",") ? .caption2 : .footnote)
                .foregroundStyle(.secondary)
                .italic()
        }
    }
    
    var infoView: some View {
        VStack(alignment: .leading, spacing: .empty) {
            SpeciesCardTitle(
                commonName: model.commonName,
                scientificName: model.scientificName,
                accessibilityIdentifier: "speciesRow.\(model.speciesID.rawValue)"
            )

            Text(model.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .padding(.bottom, .medium)
        }
    }
}

extension SpeciesRow where BelowPhoto == EmptyView, BesideBadge == EmptyView {
    init(model: ListingRowModel) {
        self.init(model: model, belowPhoto: { EmptyView() }, besideBadge: { EmptyView() })
    }
}
