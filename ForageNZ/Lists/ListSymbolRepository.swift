import Foundation

/// The SF Symbols a list can take as its icon, in the SF Symbols app's order. iOS cannot list
/// its own symbols, so `Tools/build_symbol_catalogue.py` writes them to the bundle.
nonisolated struct ListSymbolCatalogue: Sendable, Equatable, Decodable {
    nonisolated struct Category: Sendable, Equatable, Decodable, Identifiable {
        let key: String
        let title: String
        /// `nil` when the SF Symbols app's icon for the category is not one the app can show.
        let symbol: String?
        let symbols: [String]

        var id: String { key }
    }

    let symbols: [String]
    let categories: [Category]

    static let shippedResourceName = "list-symbols"

    /// The symbols in `category` (every symbol when `nil`) whose name holds each word of `query`.
    /// Dots count as spaces, so "leaf circle" finds `leaf.circle.fill`.
    func symbols(in category: Category?, matching query: String) -> [String] {
        let pool = category?.symbols ?? symbols
        let words = query.lowercased().split { $0 == " " || $0 == "." }
        guard !words.isEmpty else { return pool }
        return pool.filter { name in words.allSatisfy { name.contains($0) } }
    }
}

protocol ListSymbolRepository: Sendable {
    func catalogue() async throws(ListSymbolRepositoryError) -> ListSymbolCatalogue
}

nonisolated enum ListSymbolRepositoryError: Error, Sendable, Equatable {
    case catalogueMissing(resourceName: String)
    case catalogueUnreadable(description: String)

    var userMessage: String {
        switch self {
        case .catalogueMissing:
            "The icons are missing from this build of the app."
        case .catalogueUnreadable:
            "The icons could not be read."
        }
    }
}

actor BundledListSymbolRepository: ListSymbolRepository {
    private let bundle: Bundle
    private let resourceName: String

    private var cached: ListSymbolCatalogue?

    init(bundle: Bundle = .main, resourceName: String = ListSymbolCatalogue.shippedResourceName) {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func catalogue() async throws(ListSymbolRepositoryError) -> ListSymbolCatalogue {
        if let cached { return cached }

        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw .catalogueMissing(resourceName: resourceName)
        }

        let catalogue: ListSymbolCatalogue
        do {
            catalogue = try JSONDecoder().decode(ListSymbolCatalogue.self, from: Data(contentsOf: url))
        } catch {
            throw .catalogueUnreadable(description: String(describing: error))
        }

        cached = catalogue
        return catalogue
    }
}
