import SwiftUI

/// The toolbar menu that narrows a species screen by group and origin.
struct SpeciesFilterMenu: View {
    @Binding var filter: SpeciesFilter

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
        } label: {
            Label(
                "Filter",
                systemImage: filter.narrowsByFacet
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
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
