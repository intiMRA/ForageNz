import SwiftUI
import DesignLibrary

struct BrowseView: View {
    @Environment(SpeciesStore.self) private var store

    @State private var filter = SpeciesFilter()

    var body: some View {
        let results = filter.apply(to: store.species)
        ScrollView {
            LazyVStack {
                OriginGuidance(origin: filter.origin)
                GroupedSpeciesList(species: results)

                if results.isEmpty {
                    SpeciesFilterEmptyState(query: filter.query)
                }
            }
            .padding(.horizontal, .medium)
        }
        .navigationTitle("Field guide")
        // The placement is explicit because `.automatic` renders nothing here: from iOS 26 a
        // `.searchable` inside a `TabView` is hoisted towards the tab bar, and with no
        // `Tab(role: .search)` to land in it disappears entirely — the field guide shipped
        // without a search box until a UI test caught it.
        .searchable(
            text: $filter.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search names or description"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SpeciesFilterMenu(filter: $filter)
            }
        }
    }
}
