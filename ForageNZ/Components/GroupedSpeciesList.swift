import DesignLibrary
import SwiftUI

/// Species under a heading per app group, in `ForageGroup` order — the Field guide's layout,
/// shared with a list's page. Sits inside the screen's own `ScrollView`.
struct GroupedSpeciesList: View {
    let species: [ForageSpecies]

    var body: some View {
        let grouped = Dictionary(grouping: species, by: \.group)
        ForEach(ForageGroup.allCases) { group in
            if let items = grouped[group], !items.isEmpty {
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
    }
}
