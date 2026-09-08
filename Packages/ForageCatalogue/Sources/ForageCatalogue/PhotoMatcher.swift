import Foundation
import Vision

/// An image embedding, L2-normalised so distances are comparable across images.
public nonisolated struct FeatureVector: Codable, Sendable, Hashable {
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

/// One species reduced to a single prototype vector.
public nonisolated struct SpeciesPrototype: Codable, Sendable, Hashable, Identifiable {
    public let speciesId: String
    public let photoCount: Int
    public let vector: FeatureVector

    public var id: String { speciesId }

    public init(speciesId: String, photoCount: Int, vector: FeatureVector) {
        self.speciesId = speciesId
        self.photoCount = photoCount
        self.vector = vector
    }
}

/// A close candidate, with the catalogue context needed to present it safely.
public nonisolated struct PhotoMatch: Sendable, Hashable, Identifiable {
    public let speciesId: String
    public let distance: Float
    public let caution: CautionLevel

    /// True when this entry exists only to be recognised and avoided.
    public var isAvoidOnly: Bool { caution == .doNotEat }

    public var id: String { speciesId }

    public init(speciesId: String, distance: Float, caution: CautionLevel) {
        self.speciesId = speciesId
        self.distance = distance
        self.caution = caution
    }
}

/// Computes Vision feature prints for catalogue photos.
///
/// Deliberately nearest-neighbour over a frozen embedding rather than a trained classifier:
/// the catalogue is a closed set of a few dozen species with a handful of photos each, which
/// is where metric-based matching works and training does not.
///
/// It ranks; it never identifies.
public enum PhotoMatcher {
    public enum Failure: Error, Sendable, Equatable {
        case unreadable(String)
        case noFeaturePrint(String)
        case unexpectedElementType(String)
        /// Feature prints from different Vision revisions are not comparable.
        case revisionMismatch(indexRevision: Int, queryRevision: Int)
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
        let request = VNGenerateImageFeaturePrintRequest()
        if let revision { request.revision = revision }

        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw .unreadable(imageURL.lastPathComponent)
        }

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw .noFeaturePrint(imageURL.lastPathComponent)
        }
        guard observation.elementType == .float else {
            throw .unexpectedElementType(imageURL.lastPathComponent)
        }

        let count = observation.elementCount
        let floats = observation.data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self).prefix(count))
        }
        return FeatureVector(values: floats)
    }
}

/// Prototypes for every species that has photos, plus the revision they were built with.
public nonisolated struct PhotoIndex: Codable, Sendable {
    public let revision: Int
    public let prototypes: [SpeciesPrototype]
    /// Caution per species, so a match can be presented without re-reading the catalogue.
    public let cautions: [String: CautionLevel]

    public init(revision: Int, prototypes: [SpeciesPrototype], cautions: [String: CautionLevel]) {
        self.revision = revision
        self.prototypes = prototypes
        self.cautions = cautions
    }

    /// Builds an index from the catalogue's own photos. Species whose photos can't be read
    /// are skipped and reported rather than silently dropped.
    public static func build(
        species: [ForageSpecies],
        photoDirectory: URL,
        revision: Int? = nil
    ) -> (index: PhotoIndex, skipped: [String]) {
        let usedRevision = revision ?? PhotoMatcher.currentRevision
        var prototypes: [SpeciesPrototype] = []
        var cautions: [String: CautionLevel] = [:]
        var skipped: [String] = []

        for entry in species {
            cautions[entry.id] = entry.caution
            guard !entry.photos.isEmpty else { continue }

            let vectors = entry.photos.compactMap { photo -> FeatureVector? in
                try? PhotoMatcher.featureVector(
                    for: photoDirectory.appending(path: photo.fileName),
                    revision: usedRevision
                )
            }
            guard let prototype = FeatureVector.mean(of: vectors) else {
                skipped.append(entry.id)
                continue
            }
            prototypes.append(SpeciesPrototype(
                speciesId: entry.id, photoCount: vectors.count, vector: prototype
            ))
        }

        return (
            PhotoIndex(revision: usedRevision, prototypes: prototypes, cautions: cautions),
            skipped
        )
    }

    /// Closest catalogue entries to `query`, nearest first.
    ///
    /// Entries that exist only to be avoided are never cut by the limit: if a do-not-eat
    /// species is anywhere in range, seeing it matters more than the next-best edible guess.
    public func matches(for query: FeatureVector, limit: Int = 5) -> [PhotoMatch] {
        let ranked = prototypes
            .map { prototype in
                PhotoMatch(
                    speciesId: prototype.speciesId,
                    distance: prototype.vector.distance(to: query),
                    caution: cautions[prototype.speciesId] ?? .careRequired
                )
            }
            .sorted { $0.distance < $1.distance }

        let head = Array(ranked.prefix(limit))
        let rescuedAvoidOnly = ranked.filter { candidate in
            candidate.isAvoidOnly && !head.contains { $0.speciesId == candidate.speciesId }
        }

        return (head + rescuedAvoidOnly).sorted { $0.distance < $1.distance }
    }

    /// Rejects a query built with a different Vision revision — those distances would be
    /// meaningless rather than merely inaccurate.
    public func requireCompatible(queryRevision: Int) throws(PhotoMatcher.Failure) {
        guard queryRevision == revision else {
            throw .revisionMismatch(indexRevision: revision, queryRevision: queryRevision)
        }
    }
}
