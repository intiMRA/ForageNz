import ForageCatalogue
import SwiftUI

struct RootView: View {
    @State private var store = SpeciesStore()

    var body: some View {
        Group {
            switch store.loadState {
            case .idle, .loading:
                ProgressView("Loading the field guide…")
            case .failed(let message):
                ContentUnavailableView {
                    Label("Field guide unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") {
                        Task { await store.loadIfNeeded() }
                    }
                }
            case .loaded:
                tabs
            }
        }
        .task {
            await store.loadIfNeeded()
        }
        .environment(store)
    }

    private var tabs: some View {
        TabView {
            Tab("In season", systemImage: "calendar") {
                NavigationStack {
                    InSeasonView()
                        .navigationDestination(for: ForageSpecies.self) { species in
                            SpeciesDetailView(species: species)
                        }
                }
            }

            Tab("Field guide", systemImage: "book") {
                NavigationStack {
                    BrowseView()
                        .navigationDestination(for: ForageSpecies.self) { species in
                            SpeciesDetailView(species: species)
                        }
                }
            }

            Tab("Safety", systemImage: "exclamationmark.shield") {
                NavigationStack {
                    SafetyView()
                        .navigationDestination(for: ForageSpecies.self) { species in
                            SpeciesDetailView(species: species)
                        }
                }
            }
        }
    }
}
