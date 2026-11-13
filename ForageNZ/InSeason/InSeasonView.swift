import SwiftUI
import DesignLibrary

struct InSeasonView: View {
    @Environment(SpeciesStore.self) private var store

    @State private var filter = SpeciesFilter()

    var body: some View {
        let month = store.currentMonth
        let species = filter.apply(to: store.inSeason(for: month))
        ScrollView {
            LazyVStack(alignment: .leading) {
                Section {
                    OriginGuidance(origin: filter.origin)
                    if species.isEmpty {
                        Text(filter.narrowsByFacet
                             ? "Nothing in season matches the current filters."
                             : "Nothing in the guide is at its peak this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(species) { item in
                            SpeciesRowButton(species: item)
                        }
                    }
                } footer: {
                    Text("Year-round species are always included. Seasons are indicative and shift with region and altitude.")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, .medium)
        }
        .navigationTitle("In season")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SpeciesFilterMenu(filter: $filter)
            }
        }
    }
}
