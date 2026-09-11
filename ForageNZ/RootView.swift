import ForageCatalogue
import SwiftUI

struct RootView: View {
    @State private var store = SpeciesStore()
    @State private var whereYouAre = WhereYouAreStore()

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
        .environment(whereYouAre)
        .environment(\.speciesModels, CatalogueSpeciesModelFactory(store: store))
    }

    private var tabs: some View {
        TabView {
            Tab("In season", systemImage: "calendar") {
                NavigationStack { InSeasonView().speciesDestination() }
            }

            Tab("Field guide", systemImage: "book") {
                NavigationStack { BrowseView().speciesDestination() }
            }

            Tab("Safety", systemImage: "exclamationmark.shield") {
                NavigationStack { SafetyView().speciesDestination() }
            }
        }
    }
}

