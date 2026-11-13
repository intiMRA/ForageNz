import Dependencies
import Foundation
import Observation
import OSLog

/// The user's finds: species saved at a place on the map. Coordinates are never logged —
/// a foraging spot is the user's to keep.
@Observable
@MainActor
final class FindsStore {
    /// Oldest first.
    private(set) var finds: [FindSnapshot] = []
    private(set) var loadState: LoadState = .idle
    private(set) var isLocating = false
    /// The last action that failed, for the screen to show and clear.
    var errorMessage: String?

    @ObservationIgnored @Dependency(\.findsRepository) private var repository
    @ObservationIgnored @Dependency(\.locationProvider) private var locations
    @ObservationIgnored @Dependency(\.date) private var date

    private static let logger = Logger(subsystem: Logging.subsystem, category: "finds")

    func loadIfNeeded() async {
        guard loadState.canStart else { return }
        loadState = .loading
        do {
            finds = try await repository.finds()
            loadState = .loaded
        } catch {
            Self.logger.error("Finds load failed: \(String(describing: error), privacy: .public)")
            loadState = .failed(message: error.userMessage)
        }
    }

    func find(id: FindSnapshot.ID) -> FindSnapshot? {
        finds.first { $0.id == id }
    }

    /// The saved find, or `nil` with `errorMessage` set.
    func saveFind(of species: SpeciesID, at coordinate: Coordinate) async -> FindSnapshot? {
        do {
            let find = try await repository.saveFind(of: species, at: coordinate, on: date.now)
            finds.append(find)
            return find
        } catch {
            Self.logger.error("Saving a find failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.userMessage
            return nil
        }
    }

    func deleteFind(_ id: FindSnapshot.ID) async {
        do {
            try await repository.deleteFind(id)
            finds.removeAll { $0.id == id }
        } catch {
            Self.logger.error("Deleting a find failed: \(String(describing: error), privacy: .public)")
            errorMessage = error.userMessage
        }
    }

    /// One fix for placing a find, or `nil` with `errorMessage` set.
    func currentLocation() async -> Coordinate? {
        guard !isLocating else { return nil }
        isLocating = true
        defer { isLocating = false }
        do {
            return try await locations.currentCoordinate()
        } catch {
            errorMessage = error.userMessage
            return nil
        }
    }
}
