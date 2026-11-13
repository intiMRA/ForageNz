import Dependencies
import Foundation
import Observation
import OSLog

/// The user's lists, as the screens show them. The repository does the storing; this holds
/// what is on screen and turns failures into a message.
@Observable
@MainActor
final class ListsStore {
    /// Asks the one name prompt `RootView` hosts to open. A list row can scroll away while the
    /// prompt is up, so the prompt cannot live on the row.
    enum NameRequest: Equatable, Identifiable {
        case create(adding: SpeciesID?)
        case rename(SpeciesListSnapshot.ID, currentName: String)

        var id: String {
            switch self {
            case .create(let species): "create.\(species?.rawValue ?? "")"
            case .rename(let id, _): "rename.\(id.uuidString)"
            }
        }
    }

    /// Oldest first.
    private(set) var lists: [SpeciesListSnapshot] = []
    private(set) var loadState: LoadState = .idle
    /// The last change that failed, for the screen to show and clear.
    var errorMessage: String?
    var nameRequest: NameRequest?

    @ObservationIgnored @Dependency(\.speciesListsRepository) private var repository

    private static let logger = Logger(subsystem: Logging.subsystem, category: "lists")

    func loadIfNeeded() async {
        guard loadState.canStart else { return }
        loadState = .loading
        do {
            lists = try await repository.lists()
            loadState = .loaded
        } catch {
            Self.logger.error("Lists load failed: \(String(describing: error), privacy: .public)")
            loadState = .failed(message: error.userMessage)
        }
    }

    func list(id: SpeciesListSnapshot.ID) -> SpeciesListSnapshot? {
        lists.first { $0.id == id }
    }

    func isListed(_ species: SpeciesID) -> Bool {
        lists.contains { $0.contains(species) }
    }

    /// Creates a list and, when given one, puts `species` in it — the "New list…" route from a card.
    @discardableResult
    func createList(named rawName: String, adding species: SpeciesID? = nil) async -> SpeciesListSnapshot? {
        var created: SpeciesListSnapshot?
        await perform { () async throws(UserDataError) in
            let list = try await repository.createList(named: try validatedName(rawName, renaming: nil))
            if let species {
                try await repository.add(species, toList: list.id)
            }
            created = list
        }
        guard let created else { return nil }
        return list(id: created.id)
    }

    func renameList(_ id: SpeciesListSnapshot.ID, to rawName: String) async {
        await perform { () async throws(UserDataError) in
            try await repository.renameList(id, to: try validatedName(rawName, renaming: id))
        }
    }

    func deleteList(_ id: SpeciesListSnapshot.ID) async {
        await perform { () async throws(UserDataError) in
            try await repository.deleteList(id)
        }
    }

    /// Adds `species` to the list, or takes it out if it is already there.
    func toggle(_ species: SpeciesID, inList id: SpeciesListSnapshot.ID) async {
        let isMember = list(id: id)?.contains(species) ?? false
        await perform { () async throws(UserDataError) in
            if isMember {
                try await repository.remove(speciesIDRaw: species.rawValue, fromList: id)
            } else {
                try await repository.add(species, toList: id)
            }
        }
    }

    /// Takes the raw id so an entry the guide no longer has can be removed.
    func remove(speciesIDRaw: String, fromList id: SpeciesListSnapshot.ID) async {
        await perform { () async throws(UserDataError) in
            try await repository.remove(speciesIDRaw: speciesIDRaw, fromList: id)
        }
    }

    /// Runs a change, then re-reads the lists so the screen shows what was stored.
    private func perform(_ change: () async throws(UserDataError) -> Void) async {
        do {
            try await change()
            lists = try await repository.lists()
        } catch {
            Self.logger.error("Lists change failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.userMessage
            // A change can fail halfway (a list created, the species not added), so show what
            // was stored. If even the re-read fails, the screen keeps what it had.
            do {
                lists = try await repository.lists()
            } catch {
                Self.logger.error("Lists re-read failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func validatedName(
        _ rawName: String,
        renaming id: SpeciesListSnapshot.ID?
    ) throws(UserDataError) -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw .emptyListName }
        let taken = lists.contains {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
        guard !taken else { throw .duplicateListName }
        return name
    }
}
