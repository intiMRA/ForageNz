import SwiftUI
import DesignLibrary

struct InSeasonView: View {
    @Environment(SpeciesStore.self) private var store

    var body: some View {
        let month = store.currentMonth
        let species = store.inSeason(for: month)
        ScrollView {
            LazyVStack(alignment: .leading) {
                Section {
                    if species.isEmpty {
                        Text("Nothing in the guide is at its peak this month.")
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
    }

}
