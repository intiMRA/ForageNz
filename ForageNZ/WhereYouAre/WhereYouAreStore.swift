import ForageCatalogue
import Foundation
import Observation
import OSLog

/// Answers "what are the rules where I am standing" from a bundled map, with the radio off.
///
/// Everything it reports is advisory. The map is a roughly 300 m raster generalised from DOC's
/// published boundaries, so it exists to tell a forager when to stop and check, not to
/// decide anything. The view must never phrase a reading as permission.
@Observable
@MainActor
final class WhereYouAreStore {
    enum Reading: Equatable {
        case outsideCoverage
        case inside(LandStatus)
    }

    enum State: Equatable {
        case idle
        case checking
        case read(Reading)
        case failed(message: String)
    }

    private(set) var state: State = .idle

    private let repository: any LandStatusRepository
    private let locations: any LocationProvider

    private static let logger = Logger(subsystem: Logging.subsystem, category: "land-status")

    init(
        repository: any LandStatusRepository = BundledLandStatusRepository(),
        locations: any LocationProvider = DeviceLocationProvider()
    ) {
        self.repository = repository
        self.locations = locations
    }

    var isChecking: Bool { state == .checking }

    func check() async {
        guard !isChecking else { return }
        state = .checking

        do {
            // The map first: a permission prompt the user then can't act on is worse than
            // finding out up front that this build has no map to read.
            let map = try await repository.loadMap()
            let coordinate = try await locations.currentCoordinate()

            guard map.contains(latitude: coordinate.latitude, longitude: coordinate.longitude) else {
                state = .read(.outsideCoverage)
                return
            }
            state = .read(.inside(
                map.status(latitude: coordinate.latitude, longitude: coordinate.longitude)
            ))
        } catch {
            if let error = error as? LandStatusRepositoryError {
                Self.logger.error("Land map load failed: \(String(describing: error), privacy: .public)")
                state = .failed(message: error.userMessage)
            } else if let error = error as? LocationError {
                // Not logged: a denial is a choice, not a fault, and a fix is personal.
                state = .failed(message: error.userMessage)
            } else {
                Self.logger.error("Land status check failed: \(String(describing: error), privacy: .public)")
                state = .failed(message: "Could not work out where you are.")
            }
        }
    }
}
