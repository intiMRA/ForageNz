import DesignLibrary
import SwiftUI

/// Picks the species for a new find.
struct SpeciesPickerView: View {
    let onPick: (SpeciesID) -> Void

    @Environment(SpeciesStore.self) private var store
    @Environment(\.speciesModels) private var models
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(SpeciesFilter(query: query).apply(to: store.species)) { species in
                if let id = species.typedID, let model = models.createListingRowModel(id: id) {
                    Button {
                        onPick(id)
                        dismiss()
                    } label: {
                        HStack(spacing: .small) {
                            model.group.image.icon(size: .standard, color: .primary)
                            VStack(alignment: .leading) {
                                Text(model.commonName)
                                    .foregroundStyle(.primary)
                                Text(model.scientificName)
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("pickSpecies.\(id.rawValue)")
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search names or description"
            )
            .navigationTitle("What did you find?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
