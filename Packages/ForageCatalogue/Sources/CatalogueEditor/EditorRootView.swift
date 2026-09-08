import ForageCatalogue
import SwiftUI

struct EditorRootView: View {
    let store: CatalogueStore

    @State private var selectedId: String?
    @State private var search = ""
    @State private var unverifiedOnly = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let species = store.species.first(where: { $0.id == selectedId }) {
                SpeciesEditorView(species: species) { store.update($0) }
            } else {
                ContentUnavailableView(
                    "Pick a species",
                    systemImage: "leaf",
                    description: Text("Lethal claims are listed first — those are the ones worth checking against a book.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .status) { statusLabel }
            ToolbarItem(placement: .primaryAction) {
                Button("Save", systemImage: "square.and.arrow.down") { store.save() }
                    .disabled(!store.hasUnsavedChanges)
                    .keyboardShortcut("s")
            }
        }
        .navigationTitle("Forage Catalogue")
        .navigationSubtitle(store.fileURL.path(percentEncoded: false))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedId) {
                ForEach(tiers, id: \.tier) { group in
                    Section(header: Text("\(group.label) · \(group.species.count)")) {
                        ForEach(group.species) { species in
                            row(species).tag(species.id)
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Search species")

            Divider()
            Toggle("Unverified only", isOn: $unverifiedOnly)
                .padding(8)
        }
        .frame(minWidth: 260)
    }

    private func row(_ species: ForageSpecies) -> some View {
        HStack(spacing: 8) {
            Image(systemName: species.isVerified ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle(species.isVerified ? .green : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(species.commonName)
                Text(species.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if store.editedIds.contains(species.id) {
                Circle()
                    .fill(.orange)
                    .frame(width: 7, height: 7)
                    .help("Edited, not yet saved")
            }
        }
    }

    private struct TierGroup: Identifiable {
        let tier: Int
        let label: String
        let species: [ForageSpecies]
        var id: Int { tier }
    }

    private var tiers: [TierGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = store.species.filter { species in
            if unverifiedOnly && species.isVerified { return false }
            guard !query.isEmpty else { return true }
            return species.searchableText.contains(query)
        }

        return [(1, "Lethal claims"), (2, "Care required"), (3, "Straightforward")].compactMap { tier, label in
            let members = filtered
                .filter { $0.reviewTier == tier }
                .sorted { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }
            return members.isEmpty ? nil : TierGroup(tier: tier, label: label, species: members)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch store.status {
        case .clean:
            Text("\(store.unverified.count) of \(store.species.count) unverified")
                .foregroundStyle(.secondary)
        case .edited(let count):
            Text("\(count) unsaved \(count == 1 ? "entry" : "entries")")
                .foregroundStyle(.orange)
        case .saved(let date):
            Text("Saved \(date.formatted(date: .omitted, time: .standard))")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .help(message)
        }
    }
}
