import DesignLibrary
import SwiftUI

/// One "can be confused with" card. Tapping it opens the lookalike's own page — every card
/// has one, because `LookalikeCardModel.destination` is a `SpeciesID`.
struct LookalikeCardView: View {
    let model: LookalikeCardModel

    @Environment(\.router) private var router

    var body: some View {
        Button {
            router.push(.species(model.destination))
        } label: {
            card
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(model.accessibilityIdentifier)
    }

    var card: some View {
        SpeciesCard(background: model.risk.backgroundColor) {
            VStack(alignment: .leading) {
                SpeciesThumbnail(fileName: model.photoFileName)
                Spacer()
                Badge(
                    image: model.risk.image,
                    title: model.risk.displayName,
                    size: .small,color: model.risk.tintColor,
                    forgroundColor: .white,
                    fontWeight: .regular
                )
            }

            infoView
                .padding(.bottom, .xxSmall)
        }
    }

    var infoView: some View {
        VStack(alignment: .leading, spacing: .empty) {
            SpeciesCardTitle(
                commonName: model.name,
                scientificName: model.scientificName,
                accessibilityIdentifier: model.id
            )

            Text(model.howToTell)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
