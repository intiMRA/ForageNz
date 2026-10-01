import DesignLibrary
import SwiftUI
import SwiftUINavigation

/// Everything this window can put in front of the catalogue, as one value.
///
/// It replaces four separate `@State` properties — a `Bool` for the sheet plus the two fields
/// that were its payload, and an optional for the alert. One optional enum makes two things
/// true that a comment used to have to promise: the add form cannot open holding the last
/// attempt's name or error, and the sheet and the alert cannot both be up at once.
@CasePathable
private enum Destination {
    case adding(AddDraft)
    case deleting(ForageSpecies)
    case reloading(ReloadWarning)
}

/// The add form's own state, so it lives and dies with the presentation.
private struct AddDraft: Identifiable {
    let id = UUID()
    var name = ""
    var error: String?
}

/// Why a reload is being confirmed rather than just done.
///
/// Carries the count because the alert has to say what is at stake — "3 entries" is the
/// difference between a confirmation someone reads and one they dismiss by reflex.
private struct ReloadWarning: Identifiable {
    let id = UUID()
    let editedCount: Int
}

/// A property of an entry the sidebar can narrow to.
///
/// The four are genuinely different queues and the words for them are easy to confuse, which
/// is why all four are here rather than one toggle called "unverified": `isVerified` only asks
/// whether an entry cites a *source*, and every entry does, so that filter alone is always
/// empty. What there is a backlog of is drafts, and what blocks a draft from shipping is a
/// validation issue. `needsBook` cuts across all three — it says the remaining work cannot be
/// done at a keyboard, which is the one thing the others cannot tell you.
enum EntryFilter: String, CaseIterable, Identifiable {
    /// Cites no source. Currently none — kept so the number is visible rather than assumed.
    case unsourced
    /// Hidden from the app. The large queue: sourced, but not finished.
    case drafts
    /// Carries a blocking validation issue — the specific reason a draft cannot be promoted.
    case incomplete
    /// Searched online and found nothing usable, so the rest has to come off a printed page.
    case needsBook

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unsourced: "Unsourced"
        case .drafts: "Drafts"
        case .incomplete: "Incomplete"
        case .needsBook: "Book only"
        }
    }

    var help: String {
        switch self {
        case .unsourced: "Cites no source at all."
        case .drafts: "Marked draft, so the app never lists it."
        case .incomplete: "Has at least one blocking validation issue."
        case .needsBook: "Searched online and found nothing — take it to a book."
        }
    }

    func matches(_ species: ForageSpecies) -> Bool {
        switch self {
        case .unsourced: !species.isVerified
        case .drafts: species.draft
        case .incomplete: !species.isPublishable
        case .needsBook: species.needsBookSource
        }
    }
}

struct EditorRootView: View {
    let store: CatalogueStore

    @State private var selectedId: String?
    @State private var search = ""
    /// Empty means show everything. Several at once **narrow** — "Drafts" and "Incomplete"
    /// together is the drafts that still fail validation, which is the queue worth working.
    @State private var filters: Set<EntryFilter> = []
    @State private var destination: Destination?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let species = store.species.first(where: { $0.id == selectedId }) {
                VStack(spacing: .empty) {
                    SpeciesEditorView(
                        species: species,
                        photoDirectory: store.photoDirectory,
                        stagingDirectory: store.stagingDirectory,
                        catalogueURL: store.fileURL,
                        onChange: { store.update($0) },
                        onRemovePhoto: { store.schedulePhotoDeletion($0) }
                    )
                    saveBar
                }
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
                Button("Sync", systemImage: "arrow.clockwise") { startReloading() }
                    .keyboardShortcut("r")
                    .help("Re-read species.json from disk — picks up catalogue-tool, the Python tools, or a git pull (⌘R)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save", systemImage: "square.and.arrow.down") { store.save() }
                    .disabled(!store.hasUnsavedChanges)
                    .keyboardShortcut("s")
            }
        }
        .sheet(item: $destination.adding) { $draft in
            addSheet(draft: $draft)
        }
        .alert(item: $destination.deleting) { _ in
            Text("Delete this entry?")
        } actions: { species in
            Button("Delete", role: .destructive) {
                if selectedId == species.id { selectedId = nil }
                store.delete(id: species.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { species in
            Text("\(species.commonName) will be removed from the catalogue when you save.")
        }
        .alert(item: $destination.reloading) { _ in
            Text("Discard unsaved changes?")
        } actions: { _ in
            Button("Discard and reload", role: .destructive) { store.load() }
            Button("Cancel", role: .cancel) {}
        } message: { warning in
            Text(
                "\(warning.editedCount) \(warning.editedCount == 1 ? "entry has" : "entries have") "
                + "unsaved changes. Reloading reads species.json from disk and those edits are lost."
            )
        }
    }

    private func addSheet(draft: Binding<AddDraft>) -> some View {
        VStack(alignment: .leading, spacing: .medium) {
            Text("Add a species")
                .font(.headline)
            Text("The identifier is derived from the name and can't be changed afterwards, so get the name right first.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Common name", text: draft.name)
                .onSubmit { commitAdd(draft: draft) }

            if !draft.wrappedValue.name.isEmpty {
                LabeledContent("Identifier") {
                    Text(ForageSpecies.makeIdentifier(from: draft.wrappedValue.name))
                        .monospaced()
                }
            }
            if let error = draft.wrappedValue.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Text("It starts as “care required” with the missing fields listed, so it can't be shipped claiming to be safe before you've filled it in.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") { destination = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { commitAdd(draft: draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.wrappedValue.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.all, .large)
        .frame(width: EditorLayout.addSheetWidth)
    }

    private func startAdding() {
        // A fresh draft each time, so there is nothing to reset by hand.
        destination = .adding(AddDraft())
    }

    /// Re-read the catalogue, confirming first only when there is something to lose.
    ///
    /// The catalogue is written by more than this editor — `catalogue-tool --normalise`, the
    /// Python tools under `Tools/`, and a plain `git pull` all rewrite `species.json` under a
    /// running editor, which then holds a stale copy and would overwrite them on the next save.
    ///
    /// No confirmation when nothing is edited: a reload is then invisible and asking would train
    /// the habit of dismissing the alert that *does* matter. `CatalogueStore.load()` also clears
    /// `pendingPhotoDeletions`, which is correct rather than a leak — those files were never
    /// deleted (that happens on save) and the catalogue on disk still references them, so the
    /// reloaded entry points at photos that are genuinely still there.
    private func startReloading() {
        guard store.hasUnsavedChanges else {
            store.load()
            return
        }
        destination = .reloading(ReloadWarning(editedCount: store.editedIds.count))
    }

    private func commitAdd(draft: Binding<AddDraft>) {
        do {
            selectedId = try store.addSpecies(commonName: draft.wrappedValue.name)
            destination = nil
        } catch {
            switch error {
            case .nameEmpty:
                draft.wrappedValue.error = "Give it a name with at least one letter or digit."
            case .duplicate(let id):
                draft.wrappedValue.error = "“\(id)” is already in the catalogue."
            }
        }
    }

    private static func unsavedLabel(_ count: Int) -> String {
        "\(count) unsaved \(count == 1 ? "entry" : "entries")"
    }

    private var saveBar: some View {
        VStack(spacing: .empty) {
            Divider()
            HStack(spacing: .small) {
                Group {
                    switch store.status {
                    case .edited(let count):
                        Label(Self.unsavedLabel(count), systemImage: "pencil.circle.fill")
                        .foregroundStyle(.orange)
                    case .saved(let date):
                        Label(
                            "Saved \(date.formatted(date: .omitted, time: .shortened))",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                    case .failed(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    case .clean:
                        Text("No unsaved changes")
                            .foregroundStyle(.secondary)
                    }
                    if store.needsRebuildForSpeciesIDs {
                        Label("SpeciesID regenerated — rebuild before picking new species as a lookalike page", systemImage: "hammer")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.callout)

                Spacer(minLength: CommonPadding.xSmall.rawValue)

                Button("Save changes") { store.save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s")
                    .disabled(!store.hasUnsavedChanges)
                    .help("Write the catalogue to species.json (⌘S)")
            }
            .padding(.horizontal, .medium)
            .padding(.vertical, .small)
        }
        .background(.bar)
    }

    private var sidebar: some View {
        VStack(spacing: .empty) {
            List(selection: $selectedId) {
                ForEach(tiers) { group in
                    Section(header: Text("\(group.tier.title) · \(group.species.count)")) {
                        ForEach(group.species) { species in
                            row(species).tag(species.id)
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Search species")

            Divider()
            VStack(alignment: .leading, spacing: .xSmall) {
                // The count sits on the toggle so an empty result is explained before you flip
                // it — "Unsourced 0" says what the old "Unverified only" could not.
                ForEach(EntryFilter.allCases) { filter in
                    Toggle(isOn: binding(for: filter)) {
                        HStack(spacing: .xxSmall) {
                            Text(filter.label)
                            Text("\(store.species.count(where: filter.matches))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .help(filter.help)
                }

                Text(store.displayPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .textSelection(.enabled)
                    .help(store.displayPath)
            }
            .padding(.all, .xSmall)
        }
        .frame(minWidth: EditorLayout.sidebarMinimumWidth)
    }

    private func row(_ species: ForageSpecies) -> some View {
        HStack(spacing: .xSmall) {
            Image(systemName: species.isVerified ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle(species.isVerified ? .green : .secondary)
            VStack(alignment: .leading, spacing: .xxxSmall) {
                Text(species.commonName)
                Text(species.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: CommonPadding.xxSmall.rawValue)
            if !species.isPublishable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    // The reasons, not a tally. A count sends you opening tabs one by one
                    // looking for where the issue lives, and an issue whose tab you are not
                    // on is otherwise invisible.
                    .help(blockingSummary(for: species))
            }
            if store.editedIds.contains(species.id) {
                Circle()
                    .fill(.orange)
                    .frame(width: EditorLayout.editedDotSize, height: EditorLayout.editedDotSize)
                    .help("Edited, not yet saved")
            }
        }
        .contextMenu {
            Button("Delete \(species.commonName)…", role: .destructive) {
                destination = .deleting(species)
            }
        }
    }

    private struct TierGroup: Identifiable {
        let tier: ReviewTier
        let species: [ForageSpecies]
        var id: ReviewTier { tier }
    }

    /// Every blocking issue, tagged with the tab that owns it so the tooltip says where to go.
    private func blockingSummary(for species: ForageSpecies) -> String {
        species.blockingIssues
            .map { "\(EditorTab.tab(owning: $0.field).title): \($0.message)" }
            .joined(separator: "\n")
    }

    private func binding(for filter: EntryFilter) -> Binding<Bool> {
        Binding(
            get: { filters.contains(filter) },
            set: { isOn in
                if isOn { filters.insert(filter) } else { filters.remove(filter) }
            }
        )
    }

    private var tiers: [TierGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = store.species.filter { species in
            guard filters.allSatisfy({ $0.matches(species) }) else { return false }
            guard !query.isEmpty else { return true }
            return species.searchableText.contains(query)
        }

        return ReviewTier.allCases.compactMap { tier in
            let members = filtered
                .filter { $0.reviewTier == tier }
                .sorted(by: ForageSpecies.displayOrder)
            return members.isEmpty ? nil : TierGroup(tier: tier, species: members)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch store.status {
        case .clean:
            HStack(spacing: .small) {
                Text("\(store.unverified.count) of \(store.species.count) unverified")
                    .foregroundStyle(.secondary)
                if !store.unpublishable.isEmpty {
                    Label("\(store.unpublishable.count) incomplete", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        case .edited(let count):
            Text(Self.unsavedLabel(count))
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
