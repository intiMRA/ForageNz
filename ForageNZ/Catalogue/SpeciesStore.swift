import Dependencies
import Foundation
import Observation
import OSLog

/// Shared catalogue state. Loaded once at launch and filtered by the screens that read it.
@Observable
@MainActor
final class SpeciesStore {
    /// What the screens read: the catalogue minus the unfinished entries.
    private(set) var species: [ForageSpecies] = []
    private(set) var loadState: LoadState = .idle

    /// Everything the file holds, drafts included, in display order. Kept so the visible list
    /// can be recomputed when `includesUnverified` flips without re-reading the bundle.
    private var catalogue: [ForageSpecies] = []

    /// Lists the unfinished entries alongside the finished ones. Off in every build the user
    /// sees: the only thing that writes it is the debug drawer, which is compiled out of a
    /// release build. Half an entry is worse than none in the field, which is why the default
    /// stands.
    var includesUnverified = false {
        didSet {
            guard oldValue != includesUnverified else { return }
            applyVisibility()
        }
    }

    /// How many entries the catalogue is hiding. For the debug drawer to report; nothing the
    /// user sees depends on it.
    var unverifiedCount: Int { catalogue.count { $0.draft } }

    /// How many of those are waiting on a printed book rather than on someone's time. Debug
    /// reporting only, like `unverifiedCount`.
    var needsBookCount: Int { catalogue.count { $0.needsBookSource } }

    @ObservationIgnored @Dependency(\.speciesRepository) private var repository

    /// The month the guide is currently showing. It reads the clock through the dependency
    /// context rather than `Date.now`, so a test can put the app in February without waiting
    /// for February. `@Observable` cannot track a property wrapper, hence `@ObservationIgnored`
    /// on both — neither is state the views need to observe.
    @ObservationIgnored @Dependency(\.date) private var date

    var currentMonth: ForageMonth { ForageMonth.containing(date.now) }

    private static let logger = Logger(subsystem: Logging.subsystem, category: "catalogue")

    /// Loads the catalogue unless it is already loaded or in flight. A failed load may retry.
    func loadIfNeeded() async {
        guard loadState.canStart else { return }

        loadState = .loading
        do {
            catalogue = try await repository.loadSpecies().sorted(by: ForageSpecies.displayOrder)
            applyVisibility()
            loadState = .loaded
        } catch {
            catalogue = []
            species = []
            Self.logger.error("Catalogue load failed: \(String(describing: error), privacy: .public)")
            loadState = .failed(message: error.userMessage)
        }
    }

    private func applyVisibility() {
        species = includesUnverified ? catalogue : catalogue.filter { !$0.draft }
    }

    // MARK: - Derived views

    /// Species worth looking for in `month`, excluding entries that exist only as warnings.
    func inSeason(for month: ForageMonth) -> [ForageSpecies] {
        species.filter { $0.caution.isHarvestable && $0.isInSeason(in: month) }
    }

    /// Entries that exist so the user can recognise and avoid them.
    var doNotEat: [ForageSpecies] {
        species.filter { $0.caution == .doNotEat }
    }

    /// Entries whose reason to leave them alone is the law, not poisoning. Kept out of
    /// `doNotEat` so the Safety tab can say which of the two it means.
    var psychoactive: [ForageSpecies] {
        species.filter { $0.caution == .psychoactive }
    }

    /// Every species that has at least one lookalike that can kill.
    var withDeadlyLookalikes: [ForageSpecies] {
        species.filter(\.hasDeadlyLookalikeAsEdible)
    }

    /// Case-insensitive search across names and summary. An empty query returns everything.
    func search(_ query: String) -> [ForageSpecies] {
        SpeciesFilter(query: query).apply(to: species)
    }

    /// The entry for a compile-time species id. `nil` for a draft, unless the debug drawer
    /// has asked for them, or if the enum and the catalogue have drifted, which
    /// `CatalogueTests` does not allow to ship.
    func species(for id: SpeciesID) -> ForageSpecies? {
        species.first { $0.id == id.rawValue }
    }

    /// Search plus the browse filters. A `nil` filter means "don't narrow on that dimension".
    func filter(
        query: String = "",
        group: ForageGroup? = nil,
        origin: ForageOrigin? = nil
    ) -> [ForageSpecies] {
        SpeciesFilter(query: query, group: group, origin: origin).apply(to: species)
    }

    /// A list's members split into the ones the guide shows, in display order, and the raw ids
    /// it does not (a species since removed, or a draft the debug drawer has hidden again).
    func members(of list: SpeciesListSnapshot) -> ListMembers {
        let listed = Set(list.speciesIDsRaw)
        let present = species.filter { listed.contains($0.id) }
        let shown = Set(present.map(\.id))
        return ListMembers(
            species: present,
            missingIDsRaw: list.speciesIDsRaw.filter { !shown.contains($0) }
        )
    }
}

nonisolated struct ListMembers: Equatable {
    let species: [ForageSpecies]
    let missingIDsRaw: [String]
}
