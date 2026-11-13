import Dependencies
import Foundation

// The app's injectable collaborators, each behind a protocol and registered here so a test can
// substitute one without an initialiser parameter threaded through every caller.
//
// Only `liveValue` is given, deliberately. swift-dependencies then reports a loud test issue
// the moment a test reaches a dependency it has not overridden, rather than quietly handing
// it the real bundle or the real GPS. That is the same stance as
// `UnconfiguredSpeciesModelFactory`: a missing wire should fail, not silently half-work.
//
// This file is app-side on purpose. `ForageNZ/Catalogue/Model/` is also compiled by the root
// `Package.swift`, which has no access to these packages, so nothing under `Model/` may
// import Dependencies.

extension DependencyValues {
    var speciesRepository: any SpeciesRepository {
        get { self[SpeciesRepositoryKey.self] }
        set { self[SpeciesRepositoryKey.self] = newValue }
    }

    var landStatusRepository: any LandStatusRepository {
        get { self[LandStatusRepositoryKey.self] }
        set { self[LandStatusRepositoryKey.self] = newValue }
    }

    var locationProvider: any LocationProvider {
        get { self[LocationProviderKey.self] }
        set { self[LocationProviderKey.self] = newValue }
    }

    var speciesListsRepository: any SpeciesListsRepository {
        get { self[SpeciesListsRepositoryKey.self] }
        set { self[SpeciesListsRepositoryKey.self] = newValue }
    }

    var findsRepository: any FindsRepository {
        get { self[FindsRepositoryKey.self] }
        set { self[FindsRepositoryKey.self] = newValue }
    }
}

private enum SpeciesRepositoryKey: DependencyKey {
    static let liveValue: any SpeciesRepository = BundledSpeciesRepository()
}

private enum LandStatusRepositoryKey: DependencyKey {
    static let liveValue: any LandStatusRepository = BundledLandStatusRepository()
}

private enum LocationProviderKey: DependencyKey {
    static let liveValue: any LocationProvider = DeviceLocationProvider()
}

private enum SpeciesListsRepositoryKey: DependencyKey {
    static let liveValue: any SpeciesListsRepository = UserDataSettings.liveRepository
}

private enum FindsRepositoryKey: DependencyKey {
    static let liveValue: any FindsRepository = UserDataSettings.liveRepository
}
