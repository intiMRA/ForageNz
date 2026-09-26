import SwiftUI

struct RootView: View {
    @State private var store = SpeciesStore()
    @State private var whereYouAre = WhereYouAreStore()

    // One router per tab, so the three stacks stay independent and each keeps its place when
    // the user switches away and back — the behaviour the implicit stacks had.
    @State private var inSeasonRouter = Router()
    @State private var fieldGuideRouter = Router()
    @State private var safetyRouter = Router()

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
                NavigationStack(path: $inSeasonRouter.path) {
                    InSeasonView().speciesDestination()
                }
                .environment(\.router, inSeasonRouter)
            }

            Tab("Field guide", systemImage: "book") {
                NavigationStack(path: $fieldGuideRouter.path) {
                    BrowseView().speciesDestination()
                }
                .environment(\.router, fieldGuideRouter)
            }

            Tab("Safety", systemImage: "exclamationmark.shield") {
                NavigationStack(path: $safetyRouter.path) {
                    SafetyView().speciesDestination()
                }
                .environment(\.router, safetyRouter)
            }
        }
    }
}

