import ForageCatalogue
import Foundation

protocol LandStatusRepository: Sendable {
    func loadMap() async throws(LandStatusRepositoryError) -> LandStatusMap
}

nonisolated enum LandStatusRepositoryError: Error, Sendable, Equatable {
    case mapMissing(resourceName: String)
    case mapUnreadable(description: String)
    case mapImplausible(place: String)

    var userMessage: String {
        switch self {
        case .mapMissing:
            "The land map is missing from this build of the app."
        case .mapUnreadable:
            "The land map could not be read."
        case .mapImplausible:
            "The land map in this build is wrong, so it is not being used."
        }
    }
}

actor BundledLandStatusRepository: LandStatusRepository {
    private let bundle: Bundle
    private let resourceName: String

    private var cached: LandStatusMap?

    init(bundle: Bundle = .main, resourceName: String = "land-status") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    /// Decoding and packing the raster costs a beat, so it happens once, off the main actor,
    /// and only when someone actually asks where they are.
    func loadMap() async throws(LandStatusRepositoryError) -> LandStatusMap {
        if let cached { return cached }

        guard let raster = bundle.url(forResource: resourceName, withExtension: "png"),
              let metadata = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw .mapMissing(resourceName: resourceName)
        }

        let map: LandStatusMap
        do {
            map = try LandStatusMap(rasterURL: raster, metadataURL: metadata)
        } catch {
            throw .mapUnreadable(description: String(describing: error))
        }

        // Xcode re-encodes bundled PNGs and ImageIO colour-matches on decode. Both preserve
        // these values today; neither promises to. A silently re-mapped or flipped raster
        // answers every question confidently and wrongly, so refuse to use one.
        if let place = map.firstGroundTruthFailure() {
            throw .mapImplausible(place: place)
        }

        cached = map
        return map
    }
}
