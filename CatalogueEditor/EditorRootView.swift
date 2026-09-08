import ForageCatalogue
import SwiftUI

struct EditorRootView: View {
    let store: CatalogueStore

    @State private var selectedId: String?
    @State private var search = ""
    @State private var unverifiedOnly = false
    @State private var isAddingSpecies = false
    @State private var newName = ""
    @State private var addError: String?
    @State private var pendingDeletion: ForageSpecies?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let species = store.species.first(where: { $0.id == selectedId }) {
                SpeciesEditorView(
                    species: species,
                    photoDirectory: store.photoDirectory
                ) { store.update($0) }
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
                Button("Add species", systemImage: "plus") { startAdding() }
                    .keyboardShortcut("n")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save", systemImage: "square.and.arrow.down") { store.save() }
                    .disabled(!store.hasUnsavedChanges)
                    .keyboardShortcut("s")
            }
        }
        .sheet(isPresented: $isAddingSpecies) { addSheet }
        .alert("Delete this entry?", isPresented: .init(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { species in
            Button("Delete", role: .destructive) {
                if selectedId == species.id { selectedId = nil }
                store.delete(id: species.id)
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { species in
            Text("\(species.commonName) will be removed from the catalogue when you save.")
        }
    }

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add a species")
                .font(.headline)
            Text("The identifier is derived from the name and can't be changed afterwards, so get the name right first.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Common name", text: $newName)
                .onSubmit(commitAdd)

            if !newName.isEmpty {
                LabeledContent("Identifier") {
                    Text(ForageSpecies.makeIdentifier(from: newName))
                        .monospaced()
                }
            }
            if let addError {
                Label(addError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Text("It starts as “care required” with the missing fields listed, so it can't be shipped claiming to be safe before you've filled it in.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") { isAddingSpecies = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { commitAdd() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func startAdding() {
        newName = ""
        addError = nil
        isAddingSpecies = true
    }

    private func commitAdd() {
        switch store.addSpecies(commonName: newName) {
        case .success(let id):
            selectedId = id
            isAddingSpecies = false
        case .failure(.nameEmpty):
            addError = "Give it a name with at least one letter or digit."
        case .failure(.duplicate(let id)):
            addError = "“\(id)” is already in the catalogue."
        }
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
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Unverified only", isOn: $unverifiedOnly)
                Text(store.displayPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .textSelection(.enabled)
                    .help(store.displayPath)
            }
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
            if !species.isPublishable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .help("\(species.blockingIssues.count) thing(s) still to fill in")
            }
            if store.editedIds.contains(species.id) {
                Circle()
                    .fill(.orange)
                    .frame(width: 7, height: 7)
                    .help("Edited, not yet saved")
            }
        }
        .contextMenu {
            Button("Delete \(species.commonName)…", role: .destructive) {
                pendingDeletion = species
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
            HStack(spacing: 10) {
                Text("\(store.unverified.count) of \(store.species.count) unverified")
                    .foregroundStyle(.secondary)
                if !store.unpublishable.isEmpty {
                    Label("\(store.unpublishable.count) incomplete", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
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
