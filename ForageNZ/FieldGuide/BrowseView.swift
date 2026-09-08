import ForageCatalogue
import SwiftUI

struct BrowseView: View {
    @Environment(SpeciesStore.self) private var store

    @State private var searchText = ""
    @State private var selectedCategory: ForageCategory?
    @State private var selectedOrigin: ForageOrigin?

    var body: some View {
        let results = filteredSpecies
        let grouped = Dictionary(grouping: results, by: \.category)

        List {
            if let selectedOrigin {
                Section {
                    Text(selectedOrigin.harvestGuidance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("originHarvestGuidance")
                }
            }

            ForEach(visibleCategories) { category in
                let items = grouped[category] ?? []
                if !items.isEmpty {
                    Section(category.displayName) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                SpeciesRow(species: item)
                            }
                        }
                    }
                }
            }

            if results.isEmpty {
                emptyState
            }
        }
        .navigationTitle("Field guide")
        .searchable(text: $searchText, prompt: "Search names or description")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
    }

    private var filteredSpecies: [ForageSpecies] {
        store.filter(query: searchText, category: selectedCategory, origin: selectedOrigin)
    }

    private var visibleCategories: [ForageCategory] {
        selectedCategory.map { [$0] } ?? ForageCategory.allCases
    }

    private var isFiltered: Bool {
        selectedCategory != nil || selectedOrigin != nil
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
            Section("Category") {
                Button {
                    selectedCategory = nil
                } label: {
                    Label(
                        "All categories",
                        systemImage: selectedCategory == nil ? "checkmark" : "square.grid.2x2"
                    )
                }

                ForEach(ForageCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Label(
                            category.displayName,
                            systemImage: selectedCategory == category ? "checkmark" : category.symbolName
                        )
                    }
                }
            }

            Section("Origin") {
                Button {
                    selectedOrigin = nil
                } label: {
                    Label(
                        "Any origin",
                        systemImage: selectedOrigin == nil ? "checkmark" : "circle.dashed"
                    )
                }

                ForEach(ForageOrigin.allCases) { origin in
                    Button {
                        selectedOrigin = origin
                    } label: {
                        Label(
                            origin.displayName,
                            systemImage: selectedOrigin == origin ? "checkmark" : origin.symbolName
                        )
                    }
                }
            }
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
