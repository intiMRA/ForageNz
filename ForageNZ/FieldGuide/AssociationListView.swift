import DesignLibrary
import SwiftUI

/// Every partner of one species, for a page whose "Grows With" strip stops at
/// `InfoPageModel.associationStripLimit` cards. The same cards as the strip, stacked, so a
/// partner reads the same in both places.
struct AssociationListView: View {
    let speciesName: String
    let cards: [AssociationCardModel]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .xSmall) {
                ForEach(cards) { card in
                    AssociationCardView(model: card) { dismiss() }
                }
            }
            .padding(.all, .medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("\(speciesName) grows with")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .accessibilityIdentifier("associationList")
    }
}
