import ForageCatalogue
import Foundation

/// Builds the photo index from the bundled catalogue photos and ranks a query against it.
///
/// An `actor` because feature-print extraction is CPU-bound and must not run on the main
/// actor, and because the index is built once and reused.
actor PhotoMatchService {
    /// How well the catalogue can support matching at all.
    struct Coverage: Sendable, Equatable {
        let speciesWithPhotos: Int
        let speciesTotal: Int

        /// Below this, ranking is theatre: with one or two prototypes everything "matches".
        static let usableMinimum = 5

        var isUsable: Bool { speciesWithPhotos >= Self.usableMinimum }
    }

    enum Failure: Error, Equatable {
        case noPhotosBundled
        case unreadableImage
    }

    private var cachedIndex: PhotoIndex?

    private var photoDirectory: URL? {
        Bundle.main.resourceURL?.appending(path: CataloguePhotos.directoryName)
    }

    func coverage(for species: [ForageSpecies]) -> Coverage {
        Coverage(
            speciesWithPhotos: species.count { !$0.photos.isEmpty },
            speciesTotal: species.count
        )
    }

    func index(for species: [ForageSpecies]) throws(Failure) -> PhotoIndex {
        if let cachedIndex { return cachedIndex }
        guard let photoDirectory else { throw .noPhotosBundled }

        let (built, _) = PhotoIndex.build(species: species, photoDirectory: photoDirectory)
        guard !built.prototypes.isEmpty else { throw .noPhotosBundled }
        cachedIndex = built
        return built
    }

    /// Ranked candidates for `imageData`, nearest first.
    func matches(
        forImageData imageData: Data,
        species: [ForageSpecies],
        limit: Int = 5
    ) throws(Failure) -> [PhotoMatch] {
        let index = try index(for: species)

        let query: FeatureVector
        do {
            query = try PhotoMatcher.featureVector(forImageData: imageData, revision: index.revision)
        } catch {
            throw .unreadableImage
        }

        return index.matches(for: query, limit: limit)
    }
}
