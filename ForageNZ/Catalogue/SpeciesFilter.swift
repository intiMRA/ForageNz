import Foundation

/// The search and facet filters every species screen shares. A `nil` facet means "don't
/// narrow on that dimension"; an empty query matches everything.
nonisolated struct SpeciesFilter: Equatable {
    var query = ""
    var group: ForageGroup?
    var origin: ForageOrigin?

    /// Whether a facet is set. The query has its own field on screen, so it does not count.
    var narrowsByFacet: Bool { group != nil || origin != nil }

    /// Case-insensitive search across names and summary, then the facets. Keeps the order given.
    func apply(to species: [ForageSpecies]) -> [ForageSpecies] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return species.filter { species in
            if !trimmed.isEmpty, !species.searchableText.contains(trimmed) { return false }
            if let group, species.group != group { return false }
            if let origin, species.origin != origin { return false }
            return true
        }
    }
}
