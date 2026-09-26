import SwiftUI

/// A list row for a species that routes to its page — the one way every list does it.
///
/// A `Button` that asks the router to go, rather than a `NavigationLink`: the route lives in
/// `Router.path`, so navigation is state something can read and drive, not a side effect
/// buried in a link. `.buttonStyle(.plain)` keeps `SpeciesRow`'s own text visible to the
/// accessibility tree, which is how the UI tests find a row.
struct SpeciesRowButton: View {
    let species: ForageSpecies

    @Environment(\.speciesModels) private var models
    @Environment(\.router) private var router

    var body: some View {
        if let id = species.typedID, let model = models.createListingRowModel(id: id) {
            Button {
                router.push(.species(id))
            } label: {
                // A `NavigationLink` row stretches to the width of the list; a `Button`
                // label sizes to fit, which squeezed the text columns to ~100pt and made
                // every row wrap to 522pt tall. `contentShape` keeps the whole row tappable
                // rather than just the text.
                SpeciesRow(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // A `Button` folds its label into one accessibility element, where the
            // `NavigationLink` this replaced kept the children addressable. `.contain` puts
            // them back, which is what lets a screen reader read the row's parts separately —
            // and what the UI tests use to find a row by `speciesRow.<id>`.
            .accessibilityElement(children: .contain)
        }
    }
}
