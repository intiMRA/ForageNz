import Foundation

@testable import ForageNZ

/// Lists and finds held in memory, for tests. Same behaviour as the SwiftData store, without
/// SwiftData.
actor InMemoryUserDataRepository: SpeciesListsRepository, FindsRepository {
    private var storedLists: [SpeciesListSnapshot]
    private var storedFinds: [FindSnapshot]

    init(lists: [SpeciesListSnapshot] = [], finds: [FindSnapshot] = []) {
        self.storedLists = lists
        self.storedFinds = finds
    }

    func lists() async throws(UserDataError) -> [SpeciesListSnapshot] { storedLists }

    func createList(named name: String) async throws(UserDataError) -> SpeciesListSnapshot {
        let list = SpeciesListSnapshot(id: UUID(), name: name, createdAt: .now, speciesIDsRaw: [])
        storedLists.append(list)
        return list
    }

    func renameList(_ id: SpeciesListSnapshot.ID, to name: String) async throws(UserDataError) {
        try update(id) { SpeciesListSnapshot(id: $0.id, name: name, createdAt: $0.createdAt, speciesIDsRaw: $0.speciesIDsRaw) }
    }

    func deleteList(_ id: SpeciesListSnapshot.ID) async throws(UserDataError) {
        guard storedLists.contains(where: { $0.id == id }) else { throw .listNotFound }
        storedLists.removeAll { $0.id == id }
    }

    func add(_ species: SpeciesID, toList id: SpeciesListSnapshot.ID) async throws(UserDataError) {
        try update(id) { list in
            guard !list.contains(species) else { return list }
            return list.replacingMembers(list.speciesIDsRaw + [species.rawValue])
        }
    }

    func remove(speciesIDRaw: String, fromList id: SpeciesListSnapshot.ID) async throws(UserDataError) {
        try update(id) { $0.replacingMembers($0.speciesIDsRaw.filter { $0 != speciesIDRaw }) }
    }

    func finds() async throws(UserDataError) -> [FindSnapshot] { storedFinds }

    func saveFind(
        of species: SpeciesID,
        at coordinate: Coordinate,
        on date: Date
    ) async throws(UserDataError) -> FindSnapshot {
        let find = FindSnapshot(id: UUID(), speciesIDRaw: species.rawValue, coordinate: coordinate, foundAt: date)
        storedFinds.append(find)
        return find
    }

    func deleteFind(_ id: FindSnapshot.ID) async throws(UserDataError) {
        guard storedFinds.contains(where: { $0.id == id }) else { throw .findNotFound }
        storedFinds.removeAll { $0.id == id }
    }

    private func update(
        _ id: SpeciesListSnapshot.ID,
        _ transform: (SpeciesListSnapshot) -> SpeciesListSnapshot
    ) throws(UserDataError) {
        guard let index = storedLists.firstIndex(where: { $0.id == id }) else { throw .listNotFound }
        storedLists[index] = transform(storedLists[index])
    }
}

private extension SpeciesListSnapshot {
    func replacingMembers(_ members: [String]) -> SpeciesListSnapshot {
        SpeciesListSnapshot(id: id, name: name, createdAt: createdAt, speciesIDsRaw: members)
    }
}
