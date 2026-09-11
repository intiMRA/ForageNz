import ForageCatalogue
import SwiftUI

extension View {
    /// Installs the species destination on a `NavigationStack`. The only route to a page.
    func speciesDestination() -> some View {
        modifier(SpeciesDestination())
    }
}

private struct SpeciesDestination: ViewModifier {
    @Environment(\.speciesModels) private var factory

    func body(content: Content) -> some View {
        content.navigationDestination(for: SpeciesID.self) { id in
            if let model = factory.createInfoPageModel(id: id) {
                SpeciesDetailView(model: model)
            } else {
                ContentUnavailableView(
                    "Entry missing",
                    systemImage: "questionmark.folder",
                    description: Text("The guide has no page for “\(id.rawValue)” in this build.")
                )
            }
        }
    }
}
