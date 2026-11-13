import Foundation
import OSLog

nonisolated enum UserDataSettings {
    /// `UserDefaults` key for the iCloud setting. Off unless the user turns it on.
    static let syncKey = "userData.syncWithICloud"

    /// Passed by the UI tests so a run never reads or leaves the user's real lists and finds.
    static let inMemoryLaunchArgument = "-UserDataInMemory"

    /// Read once: the store is opened at launch, so a change applies the next time the app opens.
    static let isSyncEnabledAtLaunch = UserDefaults.standard.bool(forKey: syncKey)

    static var isStoredInMemoryOnly: Bool {
        ProcessInfo.processInfo.arguments.contains(inMemoryLaunchArgument)
    }

    /// The one store behind both the lists and the finds dependency.
    static let liveRepository: any SpeciesListsRepository & FindsRepository = {
        do throws(UserDataError) {
            let container = try UserDataContainer.make(
                syncEnabled: isSyncEnabledAtLaunch,
                inMemory: isStoredInMemoryOnly
            )
            return SwiftDataUserDataRepository(modelContainer: container)
        } catch {
            Logger(subsystem: Logging.subsystem, category: "userData")
                .error("User data store unavailable: \(String(describing: error), privacy: .public)")
            return UnavailableUserDataRepository(reason: error)
        }
    }()
}
