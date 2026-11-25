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
        let (search, results) = readingOrTyped
        ScrollView {
            LazyVStack {
                OriginGuidance(origin: filter.origin)
                if readingQuery == filter.query {
                    HStack(spacing: .xxSmall) {
                        Spacer()
                        ProgressView()
                        Text("Processing your search")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    plainWordsButton(foundNothing: results.isEmpty)
                    if let readingNote, readingNote.query == filter.query {
                        Text(readingNote.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityIdentifier("plainWordsNote")
                    }
                    SearchUnderstoodLine(search: search, isReading: currentReading != nil)
                }
                GroupedSpeciesList(species: results)

                if results.isEmpty {
                    SpeciesFilterEmptyState(query: filter.query)
                }
            }
            .padding(.horizontal, .xLarge)
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

    /// Offered once the query reads as a sentence, or whenever word search found nothing, and
    /// the query has not been read yet. A button rather than Return, which gives no hint that
    /// it searches differently from typing. Only offered where the on-device model can run.
    @ViewBuilder
    private func plainWordsButton(foundNothing: Bool) -> some View {
        let hasQuery = !filter.query.trimmingCharacters(in: .whitespaces).isEmpty
        if PlainWordsSearch.isAvailable, hasQuery,
           PlainWordsSearch.isWorthReading(filter.query) || foundNothing,
           currentReading == nil {
            Button(action: readPlainWords) {
                HStack(spacing: .xxSmall) {
                    Spacer()
                    Image(systemName: "sparkle.magnifyingglass")
                        .icon(size: .standard, color: .accent)
                    Text("Search in plain words")
                        .font(.caption)
                        .foregroundStyle(.accent)
                }
            }
            .accessibilityIdentifier("plainWordsButton")
        }
    }

    /// Asks the on-device model to read the query. The rows that come back are the guide's
    /// own; see `PlainWordsSearch`.
    private func readPlainWords() {
        let query = filter.query
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
    ///
    /// Returns the results with the search, so the catalogue is filtered once per draw.
    private var readingOrTyped: (search: SpeciesSearch, results: [ForageSpecies]) {
        let search = currentReading ?? filter.search(currentMonth: store.currentMonth)
        let results = filter.apply(to: store.species, using: search, index: store.searchIndex)
        if currentReading != nil, results.isEmpty, search.recognisesFacets, !search.terms.isEmpty {
            let filtersOnly = search.withoutTerms
            return (filtersOnly, filter.apply(to: store.species, using: filtersOnly, index: store.searchIndex))
        }
        return (search, results)
    }

    private var currentReading: SpeciesSearch? {
        guard let reading, reading.query == filter.query else { return nil }
        return reading.search
    }
}
