import ForageCatalogue
import Foundation
import SwiftUI
import Testing

@testable import ForageNZ

private struct StubMapRepository: LandStatusRepository {
    let map: LandStatusMap
    func loadMap() async throws(LandStatusRepositoryError) -> LandStatusMap { map }
}

private struct FailingMapRepository: LandStatusRepository {
    let error: LandStatusRepositoryError
    func loadMap() async throws(LandStatusRepositoryError) -> LandStatusMap { throw error }
}

private struct StubLocations: LocationProvider {
    let coordinate: Coordinate
    func currentCoordinate() async throws(LocationError) -> Coordinate { coordinate }
}

private struct FailingLocations: LocationProvider {
    let error: LocationError
    func currentCoordinate() async throws(LocationError) -> Coordinate { throw error }
}

/// Refuses to give a fix, and records whether it was ever asked for one.
private actor RecordingLocations: LocationProvider {
    private(set) var wasAsked = false

    func currentCoordinate() async throws(LocationError) -> Coordinate {
        await record()
        throw .unavailable
    }

    private func record() { wasAsked = true }
}

@Suite("Where you are")
@MainActor
struct WhereYouAreStoreTests {
    /// The shipped map, so these read real boundaries rather than a fixture that could
    /// agree with a broken reader. Loaded once: decoding 29 million pixels per test turned
    /// a one-second suite into a ten-second one.
    private static let cached: LandStatusMap? = {
        guard let catalogue = CatalogueLocator.resolve() else { return nil }
        let directory = catalogue.deletingLastPathComponent()
        return try? LandStatusMap(
            rasterURL: directory.appending(path: "land-status.png"),
            metadataURL: directory.appending(path: "land-status.json")
        )
    }()

    static func shippedMap() throws -> LandStatusMap {
        try #require(cached, "could not locate the shipped land-status raster")
    }

    static func store(at coordinate: Coordinate) throws -> WhereYouAreStore {
        WhereYouAreStore(
            repository: StubMapRepository(map: try shippedMap()),
            locations: StubLocations(coordinate: coordinate)
        )
    }

    @Test("inside a national park it reports conservation land")
    func insideAPark() async throws {
        let store = try Self.store(at: Coordinate(latitude: -39.2800, longitude: 175.5600))
        await store.check()
        #expect(store.state == .read(.inside(.conservation)))
    }

    @Test("in the middle of a city it reports nothing recorded")
    func inACity() async throws {
        let store = try Self.store(at: Coordinate(latitude: -41.2865, longitude: 174.7762))
        await store.check()
        #expect(store.state == .read(.inside([])))
    }

    @Test("beyond the map it says so rather than reporting nothing recorded")
    func outsideCoverage() async throws {
        let store = try Self.store(at: Coordinate(latitude: -33.8688, longitude: 151.2093))
        await store.check()
        #expect(store.state == .read(.outsideCoverage))
    }

    @Test("a denied fix surfaces the reason it was denied")
    func deniedLocation() async throws {
        let store = WhereYouAreStore(
            repository: StubMapRepository(map: try Self.shippedMap()),
            locations: FailingLocations(error: .denied)
        )
        await store.check()
        #expect(store.state == .failed(message: LocationError.denied.userMessage))
    }

    @Test("a broken map is reported before anyone is asked for their location")
    func mapFailsBeforeAskingForLocation() async throws {
        let locations = RecordingLocations()
        let store = WhereYouAreStore(
            repository: FailingMapRepository(error: .mapImplausible(place: "Tongariro National Park")),
            locations: locations
        )

        await store.check()

        #expect(store.state == .failed(message: LandStatusRepositoryError.mapImplausible(place: "").userMessage))
        // Prompting for location and then admitting there is no map to check it against
        // spends the user's permission on nothing.
        #expect(await locations.wasAsked == false)
    }

    @Test("checking twice ends in a reading, not stuck mid-check")
    func repeatedChecks() async throws {
        let store = try Self.store(at: Coordinate(latitude: -45.4000, longitude: 167.7000))
        await store.check()
        await store.check()
        #expect(store.state == .read(.inside(.conservation)))
    }
}

@Suite("Where you are — what the user is told")
@MainActor
struct WhereYouAreVerdictTests {
    @Test("a coastal reserve inside a park reports both restrictions, the absolute one first")
    func bothRestrictions() {
        let verdicts = WhereYouAreSection.verdicts(
            for: .inside([.conservation, .marineReserve])
        )

        #expect(verdicts.count == 2)
        // A permit is obtainable; a marine reserve is not negotiable, so it leads.
        #expect(verdicts.first?.title == "Probably a marine reserve")
        #expect(verdicts.last?.title == "Probably conservation land")
    }

    @Test("nothing recorded is never dressed up as permission")
    func unrestrictedIsNotGreen() {
        let verdicts = WhereYouAreSection.verdicts(for: .inside([]))

        #expect(verdicts.count == 1)
        // Green is the catalogue's "straightforward". This map cannot earn it: it knows
        // about two restrictions and nothing about who owns the ground.
        #expect(verdicts.first?.tint != Color(.cautionSafe))
    }

    @Test("every reading produces something to show")
    func everyReadingIsCovered() {
        let readings: [WhereYouAreStore.Reading] = [
            .outsideCoverage,
            .inside([]),
            .inside(.conservation),
            .inside(.marineReserve),
            .inside([.conservation, .marineReserve])
        ]

        for reading in readings {
            let verdicts = WhereYouAreSection.verdicts(for: reading)
            #expect(!verdicts.isEmpty, "\(reading) produced no verdict")
            #expect(verdicts.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
        }
    }
}
