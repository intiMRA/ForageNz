import ForageCatalogue
import Foundation

protocol SpeciesRepository: Sendable {
    func loadSpecies() async throws(SpeciesRepositoryError) -> [ForageSpecies]
}

nonisolated enum SpeciesRepositoryError: Error, Sendable, Equatable {
    case catalogueMissing(resourceName: String)
    case catalogueUnreadable(description: String)

    var userMessage: String {
        switch self {
        case .catalogueMissing:
            "The field guide is missing from this build of the app."
        case .catalogueUnreadable:
            "The field guide could not be read."
        }
    }
}

actor BundledSpeciesRepository: SpeciesRepository {
    private let bundle: Bundle
    private let resourceName: String

    private var cached: [ForageSpecies]?

    init(bundle: Bundle = .main, resourceName: String = "species") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func loadSpecies() async throws(SpeciesRepositoryError) -> [ForageSpecies] {
        if let cached { return cached }

        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw .catalogueMissing(resourceName: resourceName)
        }

        let species = try decodeSpecies(at: url)
        cached = species
        return species
    }

    /// Through `CatalogueFile`, so the app and the editor cannot drift on decoder settings.
    private func decodeSpecies(at url: URL) throws(SpeciesRepositoryError) -> [ForageSpecies] {
        do {
            return try CatalogueFile.load(from: url)
        } catch {
            throw .catalogueUnreadable(description: String(describing: error))
        }
    }
}
