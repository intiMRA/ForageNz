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
        .searchable(text: $searchText, prompt: "Search names or description")
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
            Section("Group") {
                Button {
                    selectedGroup = nil
                } label: {
                    Label(
                        "All groups",
                        systemImage: selectedGroup == nil ? "checkmark" : "square.grid.2x2"
                    )
                }

                ForEach(ForageGroup.allCases) { group in
                    Button {
                        selectedGroup = group
                    } label: {
                        Label {
                            Text(group.displayName)
                        } icon: {
                            if selectedGroup == group {
                                Image(systemName: "checkmark")
                            } else {
                                group.image
                            }
                        }
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
                        Label {
                            Text(origin.displayName)
                        } icon: {
                            if selectedOrigin == origin {
                                Image(systemName: "checkmark")
                            } else {
                                origin.image
                            }
                        }
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
