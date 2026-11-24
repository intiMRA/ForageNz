import DesignLibrary
import SwiftUI

/// One "Grows with" card. Tapping it opens the partner's own page.
///
/// Lookalike cards are tinted by risk; these are not, because a partner is not a hazard by
/// being one. The slab and badge come from the partner's caution instead, so a poisonous
/// partner looks exactly as poisonous here as it does in a list.
struct AssociationCardView: View {
    let model: AssociationCardModel
    /// Runs before the partner's page opens — the partners sheet closes itself here, since a
    /// push lands on the stack behind it.
    var onOpen: () -> Void = {}

    @Environment(\.router) private var router

    var body: some View {
        Button {
            onOpen()
            router.push(.species(model.destination), dropStack: true)
        } label: {
            card
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(model.accessibilityIdentifier)
    }

    private var card: some View {
        SpeciesCard(background: model.caution.rowBackground) {
            VStack(alignment: .leading) {
                SpeciesThumbnail(fileName: model.photoFileName)
                Spacer()
                if !model.caution.isHarvestable {
                    Badge(
                        image: model.caution.badgeIcon,
                        title: model.caution.displayName,
                        size: .small,
                        color: model.caution.tintColor,
                        forgroundColor: model.caution.badgeForeground,
                        fontWeight: .regular
                    )
                }
            }

            VStack(alignment: .leading, spacing: .empty) {
                SpeciesCardTitle(
                    commonName: model.name,
                    scientificName: model.scientificName,
                    accessibilityIdentifier: model.id
                )

                Text(model.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, .xxSmall)

            Spacer()
        }
    }
}
