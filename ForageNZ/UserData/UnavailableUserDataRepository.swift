import Foundation

/// What the app gets when the store cannot be opened: every call fails with the reason, so the
/// screens say the feature is unavailable instead of the app crashing over user data.
struct UnavailableUserDataRepository: SpeciesListsRepository, FindsRepository {
    let reason: UserDataError

    func lists() async throws(UserDataError) -> [SpeciesListSnapshot] { throw reason }
    func createList(named name: String) async throws(UserDataError) -> SpeciesListSnapshot { throw reason }
    func renameList(_ id: SpeciesListSnapshot.ID, to name: String) async throws(UserDataError) { throw reason }
    func deleteList(_ id: SpeciesListSnapshot.ID) async throws(UserDataError) { throw reason }
    func add(_ species: SpeciesID, toList id: SpeciesListSnapshot.ID) async throws(UserDataError) { throw reason }
    func remove(speciesIDRaw: String, fromList id: SpeciesListSnapshot.ID) async throws(UserDataError) { throw reason }
    func finds() async throws(UserDataError) -> [FindSnapshot] { throw reason }
    func saveFind(of species: SpeciesID, at coordinate: Coordinate, on date: Date) async throws(UserDataError) -> FindSnapshot {
        throw reason
    }
    func deleteFind(_ id: FindSnapshot.ID) async throws(UserDataError) { throw reason }
}
