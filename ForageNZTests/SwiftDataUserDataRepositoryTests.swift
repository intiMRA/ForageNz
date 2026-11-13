import Foundation
import SwiftData
import Testing

@testable import ForageNZ

/// The real store, in memory: what SwiftData does with the models, which the in-memory
/// repository cannot show.
@Suite("SwiftData user data repository")
struct SwiftDataUserDataRepositoryTests {
    private static func makeRepository() throws -> SwiftDataUserDataRepository {
        SwiftDataUserDataRepository(modelContainer: try UserDataContainer.make(syncEnabled: false, inMemory: true))
    }

    @Test("A list keeps its members in the order they were added, once each")
    func listRoundTrip() async throws {
        let repository = try Self.makeRepository()
        let list = try await repository.createList(named: "Wanted")

        try await repository.add(.wildFennel, toList: list.id)
        try await repository.add(.hemlock, toList: list.id)
        try await repository.add(.wildFennel, toList: list.id)

        let lists = try await repository.lists()
        #expect(lists.map(\.name) == ["Wanted"])
        #expect(lists.first?.speciesIDsRaw == ["wild-fennel", "hemlock"])
    }

    @Test("Renaming and removing change only what they name")
    func renameAndRemove() async throws {
        let repository = try Self.makeRepository()
        let list = try await repository.createList(named: "Wanted")
        try await repository.add(.wildFennel, toList: list.id)
        try await repository.add(.hemlock, toList: list.id)

        try await repository.renameList(list.id, to: "Found")
        try await repository.remove(speciesIDRaw: "wild-fennel", fromList: list.id)

        let stored = try #require(try await repository.lists().first)
        #expect(stored.name == "Found")
        #expect(stored.speciesIDsRaw == ["hemlock"])
    }

    @Test("Deleting a list deletes its entries with it")
    func cascadeDelete() async throws {
        let container = try UserDataContainer.make(syncEnabled: false, inMemory: true)
        let repository = SwiftDataUserDataRepository(modelContainer: container)
        let list = try await repository.createList(named: "Wanted")
        try await repository.add(.hemlock, toList: list.id)

        try await repository.deleteList(list.id)

        #expect(try await repository.lists().isEmpty)
        let entries = try ModelContext(container).fetchCount(FetchDescriptor<StoredListEntry>())
        #expect(entries == 0)
    }

    @Test("A change to a list that does not exist says so")
    func missingList() async throws {
        let repository = try Self.makeRepository()

        await #expect {
            try await repository.add(.hemlock, toList: UUID())
        } throws: { error in
            guard case UserDataError.listNotFound = error else { return false }
            return true
        }
    }

    @Test("A stored entry for a species the catalogue no longer has still loads")
    func unknownSpeciesLoads() async throws {
        let container = try UserDataContainer.make(syncEnabled: false, inMemory: true)
        let context = ModelContext(container)
        let list = StoredSpeciesList(name: "Old", createdAt: .now)
        let entry = StoredListEntry(speciesIDRaw: "gone-plant", addedAt: .now)
        context.insert(list)
        context.insert(entry)
        entry.list = list
        context.insert(StoredFind(
            speciesIDRaw: "gone-plant",
            coordinate: Coordinate(latitude: -41, longitude: 174),
            foundAt: .now
        ))
        try context.save()
        let repository = SwiftDataUserDataRepository(modelContainer: container)

        #expect(try await repository.lists().first?.speciesIDsRaw == ["gone-plant"])
        let find = try #require(try await repository.finds().first)
        #expect(find.speciesIDRaw == "gone-plant")
        #expect(find.speciesID == nil)
    }

    @Test("A find keeps its species, place and date, and can be deleted")
    func findRoundTrip() async throws {
        let repository = try Self.makeRepository()
        let coordinate = Coordinate(latitude: -45.87, longitude: 170.5)
        let date = Date(timeIntervalSince1970: 1_763_000_000)

        let saved = try await repository.saveFind(of: .wildFennel, at: coordinate, on: date)
        #expect(try await repository.finds() == [saved])
        #expect(saved.speciesID == .wildFennel)
        #expect(saved.coordinate == coordinate)
        #expect(saved.foundAt == date)

        try await repository.deleteFind(saved.id)
        #expect(try await repository.finds().isEmpty)
    }
}
