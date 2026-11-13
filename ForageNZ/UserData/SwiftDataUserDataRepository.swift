import Foundation
import SwiftData

// Every property has a default and every relationship is optional, with no unique
// constraints: the shape CloudKit requires, so the iCloud setting is a configuration switch
// rather than a migration.

@Model
final class StoredSpeciesList {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \StoredListEntry.list)
    var entries: [StoredListEntry]? = []

    init(name: String, createdAt: Date) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class StoredListEntry {
    var id: UUID = UUID()
    /// The raw string, not `SpeciesID`: were the enum the attribute type, removing a species
    /// from the catalogue would make every fetch touching an old row fail to decode.
    var speciesIDRaw: String = ""
    var addedAt: Date = Date.now
    var list: StoredSpeciesList?

    init(speciesIDRaw: String, addedAt: Date) {
        self.speciesIDRaw = speciesIDRaw
        self.addedAt = addedAt
    }
}

@Model
final class StoredFind {
    var id: UUID = UUID()
    var speciesIDRaw: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var foundAt: Date = Date.now

    init(speciesIDRaw: String, coordinate: Coordinate, foundAt: Date) {
        self.speciesIDRaw = speciesIDRaw
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.foundAt = foundAt
    }
}

nonisolated enum UserDataContainer {
    static func make(syncEnabled: Bool, inMemory: Bool) throws(UserDataError) -> ModelContainer {
        let schema = Schema([StoredSpeciesList.self, StoredListEntry.self, StoredFind.self])
        // `.none` must be explicit: the configuration's default is `.automatic`, which syncs
        // as soon as the app has an iCloud container.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: syncEnabled ? .automatic : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            throw .storeUnavailable(underlying: error)
        }
    }
}

/// The real store for lists and finds. An actor because a `ModelContext` is not `Sendable`;
/// the stored models never leave it.
@ModelActor
actor SwiftDataUserDataRepository: SpeciesListsRepository, FindsRepository {
    // MARK: Lists

    func lists() async throws(UserDataError) -> [SpeciesListSnapshot] {
        try fetch(FetchDescriptor<StoredSpeciesList>(sortBy: [SortDescriptor(\.createdAt)]))
            .map(SpeciesListSnapshot.init)
    }

    func createList(named name: String) async throws(UserDataError) -> SpeciesListSnapshot {
        let list = StoredSpeciesList(name: name, createdAt: .now)
        modelContext.insert(list)
        try save()
        return SpeciesListSnapshot(list)
    }

    func renameList(_ id: SpeciesListSnapshot.ID, to name: String) async throws(UserDataError) {
        try storedList(id).name = name
        try save()
    }

    func deleteList(_ id: SpeciesListSnapshot.ID) async throws(UserDataError) {
        modelContext.delete(try storedList(id))
        try save()
    }

    func add(_ species: SpeciesID, toList id: SpeciesListSnapshot.ID) async throws(UserDataError) {
        let list = try storedList(id)
        guard !(list.entries ?? []).contains(where: { $0.speciesIDRaw == species.rawValue }) else { return }
        let entry = StoredListEntry(speciesIDRaw: species.rawValue, addedAt: .now)
        modelContext.insert(entry)
        entry.list = list
        try save()
    }

    func remove(speciesIDRaw: String, fromList id: SpeciesListSnapshot.ID) async throws(UserDataError) {
        let list = try storedList(id)
        for entry in (list.entries ?? []) where entry.speciesIDRaw == speciesIDRaw {
            modelContext.delete(entry)
        }
        try save()
    }

    // MARK: Finds

    func finds() async throws(UserDataError) -> [FindSnapshot] {
        try fetch(FetchDescriptor<StoredFind>(sortBy: [SortDescriptor(\.foundAt)]))
            .map(FindSnapshot.init)
    }

    func saveFind(
        of species: SpeciesID,
        at coordinate: Coordinate,
        on date: Date
    ) async throws(UserDataError) -> FindSnapshot {
        let find = StoredFind(speciesIDRaw: species.rawValue, coordinate: coordinate, foundAt: date)
        modelContext.insert(find)
        try save()
        return FindSnapshot(find)
    }

    func deleteFind(_ id: FindSnapshot.ID) async throws(UserDataError) {
        var descriptor = FetchDescriptor<StoredFind>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let find = try fetch(descriptor).first else { throw .findNotFound }
        modelContext.delete(find)
        try save()
    }

    // MARK: Helpers

    private func storedList(_ id: SpeciesListSnapshot.ID) throws(UserDataError) -> StoredSpeciesList {
        var descriptor = FetchDescriptor<StoredSpeciesList>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let list = try fetch(descriptor).first else { throw .listNotFound }
        return list
    }

    private func fetch<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>
    ) throws(UserDataError) -> [Model] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw .fetchFailed(underlying: error)
        }
    }

    private func save() throws(UserDataError) {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw .saveFailed(underlying: error)
        }
    }
}

private extension SpeciesListSnapshot {
    init(_ list: StoredSpeciesList) {
        self.init(
            id: list.id,
            name: list.name,
            createdAt: list.createdAt,
            speciesIDsRaw: (list.entries ?? []).sorted { $0.addedAt < $1.addedAt }.map(\.speciesIDRaw)
        )
    }
}

private extension FindSnapshot {
    init(_ find: StoredFind) {
        self.init(
            id: find.id,
            speciesIDRaw: find.speciesIDRaw,
            coordinate: Coordinate(latitude: find.latitude, longitude: find.longitude),
            foundAt: find.foundAt
        )
    }
}
