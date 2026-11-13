import SwiftUI

struct RootView: View {
    @State private var store = SpeciesStore()
    @State private var whereYouAre = WhereYouAreStore()
    @State private var lists = ListsStore()
    @State private var finds = FindsStore()

    // One router per tab, so the stacks stay independent and each keeps its place when
    // the user switches away and back — the behaviour the implicit stacks had.
    @State private var inSeasonRouter = Router()
    @State private var fieldGuideRouter = Router()
    @State private var listsRouter = Router()
    @State private var mapRouter = Router()
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
        .task {
            await lists.loadIfNeeded()
        }
        .task {
            await finds.loadIfNeeded()
        }
        .listNamePrompt()
        .environment(store)
        .environment(whereYouAre)
        .environment(lists)
        .environment(finds)
        .environment(\.speciesModels, CatalogueSpeciesModelFactory(store: store))
        .debugDrawer(store: store)
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

            Tab("Lists", systemImage: "bookmark") {
                NavigationStack(path: $listsRouter.path) {
                    ListsView().speciesDestination()
                }
                .environment(\.router, listsRouter)
            }

            Tab("Map", systemImage: "map") {
                NavigationStack(path: $mapRouter.path) {
                    FindsMapView().speciesDestination()
                }
                .environment(\.router, mapRouter)
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

