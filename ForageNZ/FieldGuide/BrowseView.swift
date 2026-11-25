import SwiftUI
import DesignLibrary

struct BrowseView: View {
    @Environment(SpeciesStore.self) private var store

    @State private var filter = SpeciesFilter()
    /// The on-device model's reading of the query it was asked about, while the query still
    /// says the same thing. Editing the query drops it.
    @State private var reading: (query: String, search: SpeciesSearch)?
    /// The read in flight, kept so asking again cancels it.
    @State private var readingTask: Task<Void, Never>?
    /// The query being read. The spinner shows only while the field still says it, so editing
    /// the query mid-read puts the word matches straight back.
    @State private var readingQuery: String?
    /// Set when a sentence could not be read, so the user knows why nothing changed.
    @State private var readingNote: (query: String, text: LocalizedStringResource)?

    var body: some View {
        let search = readingOrTyped
        let results = filter.apply(to: store.species, using: search)
        ScrollView {
            LazyVStack {
                OriginGuidance(origin: filter.origin)
                if readingQuery == filter.query {
                    ProgressView("Reading your search…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    plainWordsButton
                    SearchUnderstoodLine(search: search, isReading: currentReading != nil)
                    if let readingNote, readingNote.query == filter.query {
                        Label {
                            Text(readingNote.text)
                        } icon: {
                            Image(systemName: "sparkle.magnifyingglass")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("plainWordsNote")
                    }
                }
                GroupedSpeciesList(species: results)

                if results.isEmpty {
                    SpeciesFilterEmptyState(query: filter.query)
                }
            }
            .padding(.horizontal, .medium)
        }
        .navigationTitle("Field guide")
        // The placement is explicit because `.automatic` renders nothing here: from iOS 26 a
        // `.searchable` inside a `TabView` is hoisted towards the tab bar, and with no
        // `Tab(role: .search)` to land in it disappears entirely — the field guide shipped
        // without a search box until a UI test caught it.
        .searchable(
            text: $filter.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search names, months or habitats"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SpeciesFilterMenu(filter: $filter)
            }
        }
    }

    /// Offered once the query reads as a sentence and has not been read yet. A button rather
    /// than Return, which gives no hint that it searches differently from typing. Shown even
    /// where the model cannot run, so tapping it can say why.
    @ViewBuilder
    private var plainWordsButton: some View {
        if PlainWordsSearch.isWorthReading(filter.query), currentReading == nil {
            Button(action: readPlainWords) {
                Label("Search in plain words", systemImage: "sparkle.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("plainWordsButton")
        }
    }

    /// Asks the on-device model to read the query. The rows that come back are the guide's
    /// own; see `PlainWordsSearch`.
    private func readPlainWords() {
        let query = filter.query
        if let reason = PlainWordsSearch.unavailableReason {
            readingNote = (query, reason)
            return
        }
        readingNote = nil
        readingTask?.cancel()
        readingQuery = query
        readingTask = Task {
            let search = await PlainWordsSearch.read(query, currentMonth: store.currentMonth)
            guard !Task.isCancelled else { return }
            readingQuery = nil
            guard filter.query == query else { return }
            if let search, !search.isEmpty {
                reading = (query, search)
            } else {
                readingNote = (query, "Couldn't read that as a search. Showing word matches.")
            }
        }
    }

    /// What the list shows: the model's reading of the query while it still applies, else the
    /// typed search. A reading whose words match nothing falls back to its filters alone —
    /// "plants in season that grow on grass" should not come back empty because no entry says
    /// "plants".
    private var readingOrTyped: SpeciesSearch {
        guard let reading = currentReading else { return filter.search(currentMonth: store.currentMonth) }
        if reading.recognisesFacets, !reading.terms.isEmpty,
           filter.apply(to: store.species, using: reading).isEmpty {
            return reading.withoutTerms
        }
        return reading
    }

    private var currentReading: SpeciesSearch? {
        guard let reading, reading.query == filter.query else { return nil }
        return reading.search
    }
}
