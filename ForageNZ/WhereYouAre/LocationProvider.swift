import CoreLocation
import Foundation

/// A single fix, in degrees. Keeps CoreLocation out of the store and the tests.
nonisolated struct Coordinate: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
}

nonisolated enum LocationError: Error, Sendable, Equatable {
    case denied
    case restricted
    case unavailable

    var userMessage: String {
        switch self {
        case .denied:
            "Location is turned off for ForageNZ. Turn it on in Settings to check where you are."
        case .restricted:
            "Location is restricted on this device."
        case .unavailable:
            "Could not get a location fix. Under heavy bush this can take a few tries."
        }
    }
}

protocol LocationProvider: Sendable {
    func currentCoordinate() async throws(LocationError) -> Coordinate
}

/// One fix, then stop. The app has no reason to track anyone — it answers a question the
/// user asked, and location never leaves the device.
struct DeviceLocationProvider: LocationProvider {
    func currentCoordinate() async throws(LocationError) -> Coordinate {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    throw LocationError.denied
                }
                if update.authorizationRestricted {
                    throw LocationError.restricted
                }
                if let location = update.location {
                    return Coordinate(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                }
            }
        } catch {
            // A plain `catch` and a downcast, not `catch let error as …`: a typed catch
            // binding in an async function crashes swift-frontend on the pinned toolchain.
            guard let error = error as? LocationError else { throw .unavailable }
            throw error
        }
        throw .unavailable
    }
}
