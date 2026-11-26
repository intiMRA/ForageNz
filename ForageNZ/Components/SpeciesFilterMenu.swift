import SwiftUI

/// The toolbar menu that narrows a species screen by group, origin, habitat and use.
struct SpeciesFilterMenu: View {
    @Binding var filter: SpeciesFilter
    @Environment(SpeciesStore.self) private var store

    var body: some View {
        Menu {
            facetSection(
                "Group",
                clearTitle: "All groups",
                clearSymbol: "square.grid.2x2",
                selection: $filter.group
            )

            facetSection(
                "Origin",
                clearTitle: "Any origin",
                clearSymbol: "circle.dashed",
                selection: $filter.origin
            )

            facetSection(
                "Habitat",
                clearTitle: "Any habitat",
                clearSymbol: "map",
                selection: $filter.habitat
            )

            if !store.useKinds.isEmpty {
                facetSection(
                    "Other uses",
                    clearTitle: "Any use",
                    clearSymbol: "fork.knife",
                    selection: $filter.use,
                    facets: store.useKinds
                )
            }
        } label: {
            Label(
                "Filter",
                systemImage: filter.narrowsByFacet
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }

    /// One "pick a classification, or clear it" menu section. Group, origin and habitat are the
    /// same control over different enums, so they are the same code over a `CatalogueFacet`.
    ///
    /// A checkmark replaces the facet's own drawing when it is the current choice, which is
    /// the only way a `Menu` row can show selection.
    private func facetSection<Facet: CatalogueFacet>(
        _ title: LocalizedStringKey,
        clearTitle: LocalizedStringKey,
        clearSymbol: String,
        selection: Binding<Facet?>,
        facets: [Facet] = Array(Facet.allCases)
    ) -> some View {
        Section(title) {
            Button {
                selection.wrappedValue = nil
            } label: {
                Label(clearTitle, systemImage: selection.wrappedValue == nil ? "checkmark" : clearSymbol)
            }

            ForEach(facets) { facet in
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
}

/// The harvest guidance for the origin being filtered on, if any.
struct OriginGuidance: View {
    let origin: ForageOrigin?

    var body: some View {
        if let origin {
            Text(origin.harvestGuidance)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("originHarvestGuidance")
        }
    }
}

/// The facets the search field's words were read as — "Fungi · March" for "fungi in march" —
/// so a word taken as a filter is never a silent surprise. Nothing when no word named a facet.
///
/// For a query the on-device model read (`isReading`), the words it kept are shown too, in
/// quotes. They are always the user's own words: `SearchReading` drops any other.
struct SearchUnderstoodLine: View {
    let search: SpeciesSearch
    var isReading = false

    var body: some View {
        if search.recognisesFacets || (isReading && !search.terms.isEmpty) {
            Label(labels.joined(separator: " · "), systemImage: isReading ? "sparkle.magnifyingglass" : "text.magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("searchUnderstood")
        }
    }

    private var labels: [String] {
        let groups: [String] = ForageGroup.allCases.filter(search.groups.contains).map { String(localized: $0.displayName) }
        let origins: [String] = ForageOrigin.allCases.filter(search.origins.contains).map { String(localized: $0.displayName) }
        let habitats: [String] = Habitat.allCases.filter(search.habitats.contains).map { String(localized: $0.shortLabel) }
        let months: [String] = ForageMonth.allCases.filter(search.months.contains).map(\.displayName)
        let words: [String] = isReading ? search.terms.map { "“\($0)”" } : []
        return groups + origins + habitats + months + words
    }
}

/// What a filtered species screen shows when nothing matches.
struct SpeciesFilterEmptyState: View {
    let query: String

    var body: some View {
        if query.isEmpty {
            ContentUnavailableView(
                "Nothing matches",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("No species match the current filters.")
            )
        } else {
            ContentUnavailableView.search(text: query)
        }
    }
}
