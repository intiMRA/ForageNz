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
        HStack(alignment: .top, spacing: .small) {
            VStack(alignment: .leading) {
                BundledPhoto(fileName: model.photoFileName ?? "")
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .padding(.all, .xSmall)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(model.risk.backgroundColor)
                .shadow(color: .shadow, radius: 2)
        }
    }
    

    
    var infoView: some View {
        VStack(alignment: .leading, spacing: .empty) {
            Text(model.name)
                .font(.headline)
                .accessibilityIdentifier(model.id)
                .foregroundStyle(.primary)
            
            Text(model.scientificName ?? "")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.bottom, .xSmall)
            
            Text(model.howToTell)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
