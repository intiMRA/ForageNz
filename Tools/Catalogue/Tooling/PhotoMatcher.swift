import ForageCatalogue
import Foundation
import Vision

/// An image embedding, L2-normalised so distances are comparable across images.
public nonisolated struct FeatureVector: Sendable, Hashable {
    public let values: [Float]

    public init(values: [Float]) {
        let magnitude = sqrt(values.reduce(0) { $0 + $1 * $1 })
        self.values = magnitude > 0 ? values.map { $0 / magnitude } : values
    }

    /// Euclidean distance. Both vectors are unit length, so this is monotonic with cosine
    /// distance and lands in 0...2.
    public func distance(to other: FeatureVector) -> Float {
        guard values.count == other.values.count else { return .greatestFiniteMagnitude }
        var sum: Float = 0
        for index in values.indices {
            let delta = values[index] - other.values[index]
            sum += delta * delta
        }
        return sqrt(sum)
    }

    /// The element-wise mean, renormalised — one prototype for a set of photos.
    public static func mean(of vectors: [FeatureVector]) -> FeatureVector? {
        guard let first = vectors.first else { return nil }
        guard vectors.allSatisfy({ $0.values.count == first.values.count }) else { return nil }

        var summed = [Float](repeating: 0, count: first.values.count)
        for vector in vectors {
            for index in summed.indices { summed[index] += vector.values[index] }
        }
        return FeatureVector(values: summed.map { $0 / Float(vectors.count) })
    }
}

/// One species reduced to a single prototype vector, with its caution alongside so a report
/// can never show a species without saying how dangerous it is.
public nonisolated struct SpeciesPrototype: Sendable, Hashable {
    public let speciesId: String
    public let caution: CautionLevel
    public let photoCount: Int
    public let vector: FeatureVector

    public init(speciesId: String, caution: CautionLevel, photoCount: Int, vector: FeatureVector) {
        self.speciesId = speciesId
        self.caution = caution
        self.photoCount = photoCount
        self.vector = vector
    }
}

/// A photo the index could not read, and why.
public nonisolated struct UnreadablePhoto: Sendable, Hashable {
    public let speciesId: String
    public let fileName: String
    public let failure: PhotoMatcher.Failure
}

/// Computes Vision feature prints for catalogue photos.
///
/// Deliberately nearest-neighbour over a frozen embedding rather than a trained classifier:
/// the catalogue is a closed set of a few dozen species with a handful of photos each, which
/// is where metric-based matching works and training does not.
///
/// It ranks; it never identifies. Measured and removed from the app — see the README.
public enum PhotoMatcher {
    public enum Failure: Error, Sendable, Hashable {
        case unreadable(String)
        case noFeaturePrint(String)
        case unexpectedElementType(String)
    }

    /// Vision's current feature-print revision. Recorded in the index because prints from
    /// different revisions cannot be compared — otherwise a silent source of nonsense.
    public static var currentRevision: Int {
        VNGenerateImageFeaturePrintRequest().revision
    }

    public static func featureVector(
        for imageURL: URL,
        revision: Int? = nil
    ) throws(Failure) -> FeatureVector {
        let label = imageURL.lastPathComponent
        let request = VNGenerateImageFeaturePrintRequest()
        if let revision { request.revision = revision }

        do {
            try VNImageRequestHandler(url: imageURL, options: [:]).perform([request])
        } catch {
            throw .unreadable(label)
        }

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw .noFeaturePrint(label)
        }
        guard observation.elementType == .float else {
            throw .unexpectedElementType(label)
        }

        let count = observation.elementCount
        let floats = observation.data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self).prefix(count))
        }
        return FeatureVector(values: floats)
    }
}

/// Prototypes for every species that has photos, plus the revision they were built with.
public nonisolated struct PhotoIndex: Sendable {
    public let revision: Int
    public let prototypes: [SpeciesPrototype]

    public init(revision: Int, prototypes: [SpeciesPrototype]) {
        self.revision = revision
        self.prototypes = prototypes
    }

    /// Builds an index from the catalogue's own photos.
    ///
    /// Every photo that can't be read is returned, individually. A species keeps its
    /// prototype if at least one photo read — but the caller sees exactly which didn't, so a
    /// prototype quietly built from one photo out of six cannot pass as six.
    public static func build(
        species: [ForageSpecies],
        photoDirectory: URL,
        revision: Int? = nil
    ) -> (index: PhotoIndex, unreadable: [UnreadablePhoto]) {
        let usedRevision = revision ?? PhotoMatcher.currentRevision
        var prototypes: [SpeciesPrototype] = []
        var unreadable: [UnreadablePhoto] = []

        for entry in species where !entry.photos.isEmpty {
            var vectors: [FeatureVector] = []
            for photo in entry.photos {
                do {
                    vectors.append(try PhotoMatcher.featureVector(
                        for: photoDirectory.appending(path: photo.fileName),
                        revision: usedRevision
                    ))
                } catch {
                    unreadable.append(UnreadablePhoto(
                        speciesId: entry.id, fileName: photo.fileName, failure: error
                    ))
                }
            }
            guard let prototype = FeatureVector.mean(of: vectors) else { continue }
            prototypes.append(SpeciesPrototype(
                speciesId: entry.id, caution: entry.caution, photoCount: vectors.count, vector: prototype
            ))
        }

        return (PhotoIndex(revision: usedRevision, prototypes: prototypes), unreadable)
    }
}
