import ForageCatalogue
import SwiftUI

struct InSeasonView: View {
    @Environment(SpeciesStore.self) private var store

    var body: some View {
        let month = ForageMonth.containing(.now)
        let species = store.inSeason(for: month)

        List {
            Section {
                if species.isEmpty {
                    Text("Nothing in the guide is at its peak this month.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(species) { item in
                        NavigationLink(value: item) {
                            SpeciesRow(species: item)
                        }
                    }
                }
            } header: {
                Text("\(species.count) to look for in \(month.displayName)")
            } footer: {
                Text("Year-round species are always included. Seasons are indicative and shift with region and altitude.")
            }
        }
        .navigationTitle("In season")
    }
}
