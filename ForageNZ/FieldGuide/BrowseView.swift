import SwiftUI
import DesignLibrary

struct BrowseView: View {
    @Environment(SpeciesStore.self) private var store

    @State private var searchText = ""
    @State private var selectedGroup: ForageGroup?
    @State private var selectedOrigin: ForageOrigin?

    var body: some View {
        let results = filteredSpecies
        let grouped = Dictionary(grouping: results, by: \.group)
        ScrollView {
            LazyVStack {
                if let selectedOrigin {
                    Section {
                        Text(selectedOrigin.harvestGuidance)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("originHarvestGuidance")
                    }
                }
                
                ForEach(visibleGroups) { group in
                    let items = grouped[group] ?? []
                    if !items.isEmpty {
                        LazyVStack(alignment: .leading) {
                            Text(group.displayName)
                                .bold()
                                .font(.headline)
                                .padding(.vertical, .xSmall)
                            ForEach(items) { item in
                                SpeciesRowButton(species: item)
                            }
                        }
                    }
                }
                
                if results.isEmpty {
                    emptyState
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
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search names or description"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
    }

    private var filteredSpecies: [ForageSpecies] {
        store.filter(query: searchText, group: selectedGroup, origin: selectedOrigin)
    }

    private var visibleGroups: [ForageGroup] {
        selectedGroup.map { [$0] } ?? ForageGroup.allCases
    }

    private var isFiltered: Bool {
        selectedGroup != nil || selectedOrigin != nil
    }

    /// One "pick a classification, or clear it" menu section. Group and origin are the same
    /// control over different enums, so they are the same code over a `CatalogueFacet`.
    ///
    /// A checkmark replaces the facet's own drawing when it is the current choice, which is
    /// the only way a `Menu` row can show selection.
    private func facetSection<Facet: CatalogueFacet>(
        _ title: LocalizedStringKey,
        clearTitle: LocalizedStringKey,
        clearSymbol: String,
        selection: Binding<Facet?>
    ) -> some View {
        Section(title) {
            Button {
                selection.wrappedValue = nil
            } label: {
                Label(clearTitle, systemImage: selection.wrappedValue == nil ? "checkmark" : clearSymbol)
            }

            ForEach(Array(Facet.allCases)) { facet in
                Button {
                    selection.wrappedValue = facet
                } label: {
                    Label {
                        Text(facet.displayName)
                    } icon: {
                        if selection.wrappedValue == facet {
                            Image(systemName: "checkmark")
                        } else {
                            facet.image
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if searchText.isEmpty {
            ContentUnavailableView(
                "Nothing matches",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("No species match the current filters.")
            )
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private var filterMenu: some View {
        Menu {
            facetSection(
                "Group",
                clearTitle: "All groups",
                clearSymbol: "square.grid.2x2",
                selection: $selectedGroup
            )

            facetSection(
                "Origin",
                clearTitle: "Any origin",
                clearSymbol: "circle.dashed",
                selection: $selectedOrigin
            )
        } label: {
            Label(
                "Filter",
                systemImage: isFiltered
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }

}
