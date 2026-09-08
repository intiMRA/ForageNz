import ForageCatalogue
import Foundation
import Observation
import OSLog

/// Shared catalogue state. Loaded once at launch and filtered by the screens that read it.
@Observable
@MainActor
final class SpeciesStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    private(set) var species: [ForageSpecies] = []
    private(set) var loadState: LoadState = .idle

    private let repository: any SpeciesRepository

    private static let logger = Logger(subsystem: "nz.co.intialbuquerque.ForageNZ", category: "catalogue")

    init(repository: any SpeciesRepository = BundledSpeciesRepository()) {
        self.repository = repository
    }

    /// Loads the catalogue unless it is already loaded or in flight. A failed load may retry.
    func loadIfNeeded() async {
        guard loadState == .idle || isFailed else { return }

        loadState = .loading
        do {
            let loaded = try await repository.loadSpecies()
            species = loaded.sorted { lhs, rhs in
                // Tie-break on id: `sort` is not stable, so equal names would otherwise
                // order arbitrarily between runs.
                let comparison = lhs.commonName.localizedCaseInsensitiveCompare(rhs.commonName)
                return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
            }
            loadState = .loaded
        } catch {
            species = []
            let repositoryError = error as? SpeciesRepositoryError
            Self.logger.error("Catalogue load failed: \(String(describing: error), privacy: .public)")
            loadState = .failed(message: repositoryError?.userMessage ?? "The field guide could not be loaded.")
        }
    }

    private var isFailed: Bool {
        if case .failed = loadState { return true }
        return false
    }

    // MARK: - Derived views

    /// Species worth looking for in `month`, excluding entries that exist only as warnings.
    func inSeason(for month: ForageMonth) -> [ForageSpecies] {
        species.filter { $0.caution != .doNotEat && $0.isInSeason(in: month) }
    }

    /// Entries that exist so the user can recognise and avoid them.
    var doNotEat: [ForageSpecies] {
        species.filter { $0.caution == .doNotEat }
    }

    /// Every species that has at least one lookalike that can kill.
    var withDeadlyLookalikes: [ForageSpecies] {
        species.filter { $0.highestLookalikeRisk == .deadly && $0.caution != .doNotEat }
    }

    /// Case-insensitive search across names and summary. An empty query returns everything.
    func search(_ query: String) -> [ForageSpecies] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return species }
        return species.filter { $0.searchableText.contains(trimmed) }
    }

    /// Search plus the browse filters. A `nil` filter means "don't narrow on that dimension".
    func filter(
        query: String = "",
        category: ForageCategory? = nil,
        origin: ForageOrigin? = nil
    ) -> [ForageSpecies] {
        search(query).filter { species in
            if let category, species.category != category { return false }
            if let origin, species.origin != origin { return false }
            return true
        }
    }
}
