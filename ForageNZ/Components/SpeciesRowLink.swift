import ForageCatalogue
import SwiftUI

/// A list row for a species that navigates to its page — the one way every list does it.
struct SpeciesRowLink: View {
    let species: ForageSpecies

    @Environment(\.speciesModels) private var models

    var body: some View {
        if let id = species.typedID, let model = models.createListingRowModel(id: id) {
            NavigationLink(value: id) {
                SpeciesRow(model: model)
            }
        }
    }
}
