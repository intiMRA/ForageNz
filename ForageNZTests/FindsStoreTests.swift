import Dependencies
import Foundation
import Testing

@testable import ForageNZ

private struct StubLocations: LocationProvider {
    let coordinate: Coordinate
    func currentCoordinate() async throws(LocationError) -> Coordinate { coordinate }
}

private struct FailingLocations: LocationProvider {
    let error: LocationError
    func currentCoordinate() async throws(LocationError) -> Coordinate { throw error }
}

private struct StubError: Error {}

private let foundAt = Date(timeIntervalSince1970: 1_763_000_000)
private let bush = Coordinate(latitude: -41.29, longitude: 174.78)

/// Built inside `withDependencies` because `@Dependency` binds the context at construction.
@MainActor
private func makeStore(
    repository: any FindsRepository = InMemoryUserDataRepository(),
    locations: any LocationProvider = FailingLocations(error: .unavailable)
) -> FindsStore {
    withDependencies {
        $0.findsRepository = repository
        $0.locationProvider = locations
        $0.date = .constant(foundAt)
    } operation: {
        FindsStore()
    }
}

@Suite("FindsStore")
@MainActor
struct FindsStoreTests {
    @Test("Loading reads the stored finds")
    func load() async {
        let stored = FindSnapshot(id: UUID(), speciesIDRaw: "hemlock", coordinate: bush, foundAt: foundAt)
        let store = makeStore(repository: InMemoryUserDataRepository(finds: [stored]))

        await store.loadIfNeeded()

        #expect(store.loadState == .loaded)
        #expect(store.finds == [stored])
    }

    @Test("Saving records the species, the place and today's date")
    func save() async {
        let store = makeStore()
        await store.loadIfNeeded()

        let find = await store.saveFind(of: .wildFennel, at: bush)

        #expect(find?.speciesID == .wildFennel)
        #expect(find?.coordinate == bush)
        #expect(find?.foundAt == foundAt)
        #expect(store.finds.map(\.id) == [find?.id])
    }

    @Test("A failed save adds nothing and reports why")
    func failedSave() async {
        let reason = UserDataError.saveFailed(underlying: StubError())
        let store = makeStore(repository: UnavailableUserDataRepository(reason: reason))

        let find = await store.saveFind(of: .wildFennel, at: bush)

        #expect(find == nil)
        #expect(store.finds.isEmpty)
        #expect(store.errorMessage == reason.userMessage)
    }

    @Test("Deleting removes the find")
    func delete() async throws {
        let store = makeStore()
        await store.loadIfNeeded()
        let find = try #require(await store.saveFind(of: .hemlock, at: bush))

        await store.deleteFind(find.id)

        #expect(store.finds.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test("A find whose species left the guide still loads, with no species id")
    func missingSpecies() async {
        let stored = FindSnapshot(id: UUID(), speciesIDRaw: "gone-plant", coordinate: bush, foundAt: foundAt)
        let store = makeStore(repository: InMemoryUserDataRepository(finds: [stored]))

        await store.loadIfNeeded()

        #expect(store.finds.count == 1)
        #expect(store.finds.first?.speciesID == nil)
    }

    @Test("The current location comes from the location provider")
    func currentLocation() async {
        let store = makeStore(locations: StubLocations(coordinate: bush))

        let coordinate = await store.currentLocation()

        #expect(coordinate == bush)
        #expect(!store.isLocating)
    }

    @Test("A denied permission gives no location and says why")
    func locationDenied() async {
        let store = makeStore(locations: FailingLocations(error: .denied))

        let coordinate = await store.currentLocation()

        #expect(coordinate == nil)
        #expect(store.errorMessage == LocationError.denied.userMessage)
        #expect(!store.isLocating)
    }
}
