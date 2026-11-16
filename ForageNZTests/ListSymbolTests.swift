import Dependencies
import Foundation
import Testing
import UIKit

@testable import ForageNZ

private let nature = ListSymbolCatalogue.Category(
    key: "nature",
    title: "Nature",
    symbol: "leaf",
    symbols: ["leaf", "leaf.circle.fill", "tree"]
)

private let sample = ListSymbolCatalogue(
    symbols: ["star", "leaf", "leaf.circle.fill", "tree", "star.circle"],
    categories: [nature]
)

private struct StubSymbolRepository: ListSymbolRepository {
    let result: Result<ListSymbolCatalogue, ListSymbolRepositoryError>

    func catalogue() async throws(ListSymbolRepositoryError) -> ListSymbolCatalogue {
        try result.get()
    }
}

@MainActor
private func makeStore(_ result: Result<ListSymbolCatalogue, ListSymbolRepositoryError>) -> ListSymbolPickerStore {
    withDependencies { $0.listSymbolRepository = StubSymbolRepository(result: result) } operation: {
        ListSymbolPickerStore()
    }
}

@Suite("List symbol catalogue")
struct ListSymbolCatalogueTests {
    @Test("With no search, a category gives its own symbols and no category gives them all")
    func noQuery() {
        #expect(sample.symbols(in: nil, matching: "") == sample.symbols)
        #expect(sample.symbols(in: nature, matching: "  ") == nature.symbols)
    }

    @Test("Every word of the search has to be in the name, with dots read as spaces")
    func search() {
        #expect(sample.symbols(in: nil, matching: "Circle") == ["leaf.circle.fill", "star.circle"])
        #expect(sample.symbols(in: nil, matching: "leaf circle") == ["leaf.circle.fill"])
        #expect(sample.symbols(in: nil, matching: "leaf.circle") == ["leaf.circle.fill"])
        #expect(sample.symbols(in: nature, matching: "star").isEmpty)
    }

    @Test("The shipped catalogue loads and every symbol in it is one iOS can draw")
    func shippedCatalogue() async throws {
        let catalogue = try await BundledListSymbolRepository().catalogue()

        #expect(catalogue.symbols.count > 1000)
        #expect(Set(catalogue.symbols).count == catalogue.symbols.count)
        let undrawable = catalogue.symbols.filter { UIImage(systemName: $0) == nil }
        #expect(undrawable.isEmpty, "Not system symbols: \(undrawable.prefix(10))")

        let known = Set(catalogue.symbols)
        for category in catalogue.categories {
            #expect(!category.symbols.isEmpty, "\(category.title) is empty")
            #expect(category.symbols.allSatisfy(known.contains), "\(category.title) holds symbols the picker lacks")
            if let symbol = category.symbol {
                #expect(known.contains(symbol), "\(category.title)'s icon is not a selectable symbol")
            }
        }
    }

    @Test("A missing catalogue says so")
    func missing() async {
        let repository = BundledListSymbolRepository(resourceName: "no-such-symbols")

        await #expect(throws: ListSymbolRepositoryError.catalogueMissing(resourceName: "no-such-symbols")) {
            try await repository.catalogue()
        }
    }
}

@Suite("ListSymbolPickerStore")
@MainActor
struct ListSymbolPickerStoreTests {
    @Test("Loading shows every symbol, then the category and search narrow them")
    func narrowing() async {
        let store = makeStore(.success(sample))

        await store.loadIfNeeded()
        #expect(store.loadState == .loaded)
        #expect(store.symbols == sample.symbols)

        store.categoryKey = nature.id
        #expect(store.category == nature)
        #expect(store.symbols == nature.symbols)

        store.query = "circle"
        #expect(store.symbols == ["leaf.circle.fill"])

        store.categoryKey = nil
        #expect(store.symbols == ["leaf.circle.fill", "star.circle"])
    }

    @Test("A failed load shows its message and nothing to pick")
    func loadFails() async {
        let reason = ListSymbolRepositoryError.catalogueUnreadable(description: "bad json")
        let store = makeStore(.failure(reason))

        await store.loadIfNeeded()

        #expect(store.loadState == .failed(message: reason.userMessage))
        #expect(store.symbols.isEmpty)
    }
}
