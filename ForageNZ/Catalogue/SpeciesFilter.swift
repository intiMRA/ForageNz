import Foundation

/// The search and facet filters every species screen shares. A `nil` facet means "don't
/// narrow on that dimension"; an empty query matches everything.
nonisolated struct SpeciesFilter: Equatable {
    var query = ""
    var group: ForageGroup?
    var origin: ForageOrigin?
    /// Matches an entry listing this habitat among its `habitats`, wherever it falls in them.
    var habitat: Habitat?

    /// Whether a facet is set. The query has its own field on screen, so it does not count.
    var narrowsByFacet: Bool { group != nil || origin != nil || habitat != nil }

    /// The facets, then the query (see `SpeciesSearch`): best match first, ties in the order
    /// given. `currentMonth` is what "in season" in the query means.
    /// `index` is the catalogue's text already folded (`SpeciesStore.searchIndex`); screens
    /// pass it so typing does not fold every entry again.
    func apply(
        to species: [ForageSpecies],
        currentMonth: @autoclosure () -> ForageMonth = .containing(.now),
        index: SpeciesSearch.Index = .empty
    ) -> [ForageSpecies] {
        apply(to: species, using: search(currentMonth: currentMonth()), index: index)
    }

    /// The facets, then `search` in place of the typed query — for a query the on-device model
    /// has read (`PlainWordsSearch`).
    func apply(
        to species: [ForageSpecies],
        using search: SpeciesSearch,
        index: SpeciesSearch.Index = .empty
    ) -> [ForageSpecies] {
        let narrowed = species.filter { species in
            if let group, species.group != group { return false }
            if let origin, species.origin != origin { return false }
            if let habitat, !species.habitats.contains(habitat) { return false }
            return true
        }
        return search.results(from: narrowed, index: index)
    }

    func search(currentMonth: @autoclosure () -> ForageMonth = .containing(.now)) -> SpeciesSearch {
        SpeciesSearch(query, currentMonth: currentMonth())
    }
}
