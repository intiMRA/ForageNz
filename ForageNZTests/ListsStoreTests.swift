import Dependencies
import Foundation
import Testing

@testable import ForageNZ

/// Built inside `withDependencies` because `@Dependency` binds the context at construction.
@MainActor
private func makeStore(repository: any SpeciesListsRepository) -> ListsStore {
    withDependencies { $0.speciesListsRepository = repository } operation: { ListsStore() }
}

private struct StubError: Error {}

/// Creates lists but refuses to add to them: a change that fails halfway.
private actor AddFailingRepository: SpeciesListsRepository {
    private let inner = InMemoryUserDataRepository()

    func lists() async throws(UserDataError) -> [SpeciesListSnapshot] { try await inner.lists() }
    func createList(named name: String) async throws(UserDataError) -> SpeciesListSnapshot {
        try await inner.createList(named: name)
    }
    func renameList(_ id: SpeciesListSnapshot.ID, to name: String) async throws(UserDataError) {
        try await inner.renameList(id, to: name)
    }
    func deleteList(_ id: SpeciesListSnapshot.ID) async throws(UserDataError) { try await inner.deleteList(id) }
    func add(_ species: SpeciesID, toList id: SpeciesListSnapshot.ID) async throws(UserDataError) {
        throw .saveFailed(underlying: StubError())
    }
    func remove(speciesIDRaw: String, fromList id: SpeciesListSnapshot.ID) async throws(UserDataError) {
        try await inner.remove(speciesIDRaw: speciesIDRaw, fromList: id)
    }
}

@Suite("ListsStore")
@MainActor
struct ListsStoreTests {
    @Test("Loading reads the stored lists")
    func load() async {
        let stored = SpeciesListSnapshot(id: UUID(), name: "Wanted", createdAt: .now, speciesIDsRaw: ["hemlock"])
        let store = makeStore(repository: InMemoryUserDataRepository(lists: [stored]))

        await store.loadIfNeeded()

        #expect(store.loadState == .loaded)
        #expect(store.lists == [stored])
    }

    @Test("An unavailable store fails the load with its message and can be retried")
    func loadFails() async {
        let reason = UserDataError.storeUnavailable(underlying: StubError())
        let store = makeStore(repository: UnavailableUserDataRepository(reason: reason))

        await store.loadIfNeeded()

        #expect(store.loadState == .failed(message: reason.userMessage))
    }

    @Test("Creating trims the name and can add the species it was made from")
    func createAddingSpecies() async {
        let store = makeStore(repository: InMemoryUserDataRepository())
        await store.loadIfNeeded()

        let list = await store.createList(named: "  Near the bach ", adding: .wildFennel)

        #expect(list?.name == "Near the bach")
        #expect(list?.contains(.wildFennel) == true)
        #expect(store.lists.map(\.name) == ["Near the bach"])
        #expect(store.isListed(.wildFennel))
        #expect(!store.isListed(.hemlock))
    }

    @Test("A blank name is refused", arguments: ["", "   "])
    func blankNameRefused(name: String) async {
        let store = makeStore(repository: InMemoryUserDataRepository())
        await store.loadIfNeeded()

        let list = await store.createList(named: name)

        #expect(list == nil)
        #expect(store.lists.isEmpty)
        #expect(store.errorMessage == UserDataError.emptyListName.userMessage)
    }

    @Test("A name already taken, in any case, is refused")
    func duplicateNameRefused() async {
        let store = makeStore(repository: InMemoryUserDataRepository())
        await store.loadIfNeeded()
        await store.createList(named: "Wanted")

        let duplicate = await store.createList(named: "wanted")

        #expect(duplicate == nil)
        #expect(store.lists.count == 1)
        #expect(store.errorMessage == UserDataError.duplicateListName.userMessage)
    }

    @Test("Renaming keeps the members; renaming to its own name in another case is allowed")
    func rename() async throws {
        let store = makeStore(repository: InMemoryUserDataRepository())
        await store.loadIfNeeded()
        let list = await store.createList(named: "Wanted", adding: .hemlock)
        let id = try #require(list?.id)

        await store.renameList(id, to: "WANTED")

        #expect(store.list(id: id)?.name == "WANTED")
        #expect(store.list(id: id)?.contains(.hemlock) == true)
        #expect(store.errorMessage == nil)
    }

    @Test("Renaming to another list's name is refused")
    func renameToTakenName() async throws {
        let store = makeStore(repository: InMemoryUserDataRepository())
        await store.loadIfNeeded()
        await store.createList(named: "Wanted")
        let other = try #require(await store.createList(named: "Found"))

        await store.renameList(other.id, to: "Wanted")

        #expect(store.list(id: other.id)?.name == "Found")
        #expect(store.errorMessage == UserDataError.duplicateListName.userMessage)
    }

    @Test("Toggling adds a species, and toggling again takes it out")
    func toggle() async throws {
        let store = makeStore(repository: InMemoryUserDataRepository())
        await store.loadIfNeeded()
        let id = try #require(await store.createList(named: "Wanted")).id

        await store.toggle(.wildFennel, inList: id)
        #expect(store.list(id: id)?.speciesIDsRaw == ["wild-fennel"])

        await store.toggle(.wildFennel, inList: id)
        #expect(store.list(id: id)?.speciesIDsRaw == [])
    }

    @Test("Deleting removes the list")
    func delete() async throws {
        let store = makeStore(repository: InMemoryUserDataRepository())
        await store.loadIfNeeded()
        let id = try #require(await store.createList(named: "Wanted", adding: .hemlock)).id

        await store.deleteList(id)

        #expect(store.lists.isEmpty)
        #expect(!store.isListed(.hemlock))
    }

    @Test("An entry for a species the guide no longer has can be removed by its raw id")
    func removeMissingEntry() async {
        let id = UUID()
        let stored = SpeciesListSnapshot(id: id, name: "Old", createdAt: .now, speciesIDsRaw: ["gone-plant", "hemlock"])
        let store = makeStore(repository: InMemoryUserDataRepository(lists: [stored]))
        await store.loadIfNeeded()

        await store.remove(speciesIDRaw: "gone-plant", fromList: id)

        #expect(store.list(id: id)?.speciesIDsRaw == ["hemlock"])
    }

    @Test("A failed change keeps the lists as they were and reports why")
    func failedChange() async {
        let reason = UserDataError.saveFailed(underlying: StubError())
        let store = makeStore(repository: UnavailableUserDataRepository(reason: reason))

        await store.createList(named: "Wanted")

        #expect(store.lists.isEmpty)
        #expect(store.errorMessage == reason.userMessage)
    }

    @Test("A change that fails halfway still shows what was stored")
    func halfFailedCreate() async {
        let store = makeStore(repository: AddFailingRepository())
        await store.loadIfNeeded()

        await store.createList(named: "Wanted", adding: .hemlock)

        #expect(store.lists.map(\.name) == ["Wanted"])
        #expect(!store.isListed(.hemlock))
        #expect(store.errorMessage != nil)
    }
}
