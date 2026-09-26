import SwiftUI

extension View {
    /// Installs the app's routes on a `NavigationStack`. The only place a `Destination`
    /// becomes a screen.
    func speciesDestination() -> some View {
        modifier(SpeciesDestination())
    }
}

private struct SpeciesDestination: ViewModifier {
    @Environment(\.speciesModels) private var factory

    func body(content: Content) -> some View {
        content.navigationDestination(for: Destination.self) { destination in
            switch destination {
            case .species(let id):
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
}
