import Foundation

/// One of the user's lists, as it crosses the repository boundary. The stored model never
/// leaves the repository.
nonisolated struct SpeciesListSnapshot: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    /// The members as stored, oldest first. Raw strings rather than `SpeciesID`, because a
    /// species can leave the catalogue after it was listed and the list must still load.
    let speciesIDsRaw: [String]

    func contains(_ species: SpeciesID) -> Bool {
        speciesIDsRaw.contains(species.rawValue)
    }
}

/// A species the user saved at a place on the map.
nonisolated struct FindSnapshot: Sendable, Equatable, Identifiable {
    let id: UUID
    /// Raw for the same reason as `SpeciesListSnapshot.speciesIDsRaw`.
    let speciesIDRaw: String
    let coordinate: Coordinate
    let foundAt: Date

    /// `nil` once the species has left the guide.
    var speciesID: SpeciesID? { SpeciesID(rawValue: speciesIDRaw) }
}

protocol SpeciesListsRepository: Sendable {
    /// Oldest first.
    func lists() async throws(UserDataError) -> [SpeciesListSnapshot]
    func createList(named name: String) async throws(UserDataError) -> SpeciesListSnapshot
    func renameList(_ id: SpeciesListSnapshot.ID, to name: String) async throws(UserDataError)
    /// Deletes the list and its memberships, never the species.
    func deleteList(_ id: SpeciesListSnapshot.ID) async throws(UserDataError)
    /// Adding a species the list already holds changes nothing.
    func add(_ species: SpeciesID, toList id: SpeciesListSnapshot.ID) async throws(UserDataError)
    /// Takes the raw id so an entry for a species the guide no longer has can still go.
    func remove(speciesIDRaw: String, fromList id: SpeciesListSnapshot.ID) async throws(UserDataError)
}

protocol FindsRepository: Sendable {
    /// Oldest first.
    func finds() async throws(UserDataError) -> [FindSnapshot]
    func saveFind(
        of species: SpeciesID,
        at coordinate: Coordinate,
        on date: Date
    ) async throws(UserDataError) -> FindSnapshot
    func deleteFind(_ id: FindSnapshot.ID) async throws(UserDataError)
}
