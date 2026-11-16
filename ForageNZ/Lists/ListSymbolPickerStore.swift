import Dependencies
import Foundation
import Observation
import OSLog

/// What the icon picker shows: the catalogue, narrowed by the search and the chosen category.
@Observable
@MainActor
final class ListSymbolPickerStore {
    private(set) var catalogue: ListSymbolCatalogue?
    private(set) var loadState: LoadState = .idle
    var query = ""
    /// `nil` shows every category.
    var categoryKey: ListSymbolCatalogue.Category.ID?

    @ObservationIgnored @Dependency(\.listSymbolRepository) private var repository

    private static let logger = Logger(subsystem: Logging.subsystem, category: "list-symbols")

    var category: ListSymbolCatalogue.Category? {
        catalogue?.categories.first { $0.key == categoryKey }
    }

    var symbols: [String] {
        catalogue?.symbols(in: category, matching: query) ?? []
    }

    func loadIfNeeded() async {
        guard loadState.canStart else { return }
        loadState = .loading
        do {
            catalogue = try await repository.catalogue()
            loadState = .loaded
        } catch {
            Self.logger.error("List symbols load failed: \(String(describing: error), privacy: .public)")
            loadState = .failed(message: error.userMessage)
        }
    }
}
