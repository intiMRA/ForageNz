import ForageCatalogue
import Foundation

/// Measures how well photo matching actually works, using leave-one-out over a directory
/// of labelled photos.
///
/// Accuracy claims about a matcher are worthless without this: a prototype built from a
/// photo will always match that photo. Each query here is scored against prototypes built
/// from the *other* photos of its species.
///
/// Every input that could not be read is reported. An accuracy figure over an evaluation
/// set that silently shrank is not a measurement, and this harness is the entry test any
/// future model has to pass.
public enum MatcherEvaluation {
    public struct SpeciesResult: Sendable {
        public let speciesId: String
        public let queries: Int
        public let top1: Int
        public let top3: Int
        /// Mean distance to its own species' prototype.
        public let meanOwnDistance: Float
        /// Mean distance to the nearest *other* species' prototype.
        public let meanRivalDistance: Float

        /// Positive means own-species is closer than the nearest rival, which is the
        /// property the whole approach depends on.
        public var margin: Float { meanRivalDistance - meanOwnDistance }
    }

    public struct Report: Sendable {
        public let perSpecies: [SpeciesResult]
        public let confusions: [String: String]
        /// Paths that could not be read as images, or listed as directories.
        public let unreadable: [String]

        public var queries: Int { perSpecies.reduce(0) { $0 + $1.queries } }
        public var top1: Int { perSpecies.reduce(0) { $0 + $1.top1 } }
        public var top3: Int { perSpecies.reduce(0) { $0 + $1.top3 } }

        public var top1Accuracy: Double {
            queries == 0 ? 0 : Double(top1) / Double(queries)
        }
        public var top3Accuracy: Double {
            queries == 0 ? 0 : Double(top3) / Double(queries)
        }
    }

    /// `directory` holds one subdirectory per catalogue id, each containing that species'
    /// photos.
    public static func run(
        directory: URL,
        fileManager: FileManager = .default
    ) -> Report {
        let loaded = loadVectors(in: directory, fileManager: fileManager)
        let vectorsBySpecies = loaded.vectors.filter { $0.value.count >= 2 }

        // Rival prototypes never change between queries; build each once.
        let prototypes = vectorsBySpecies.compactMapValues { FeatureVector.mean(of: $0) }

        var results: [SpeciesResult] = []
        var confusions: [String: String] = [:]

        for (speciesId, vectors) in vectorsBySpecies.sorted(by: { $0.key < $1.key }) {
            var top1 = 0
            var top3 = 0
            var ownDistances: [Float] = []
            var rivalDistances: [Float] = []
            var misses: [String: Int] = [:]

            for (index, query) in vectors.enumerated() {
                let heldOut = vectors.enumerated().filter { $0.offset != index }.map(\.element)
                guard let ownPrototype = FeatureVector.mean(of: heldOut) else { continue }

                var ranked: [(id: String, distance: Float)] = [
                    (speciesId, ownPrototype.distance(to: query))
                ]
                for (rivalId, rival) in prototypes where rivalId != speciesId {
                    ranked.append((rivalId, rival.distance(to: query)))
                }
                ranked.sort { $0.distance < $1.distance }

                ownDistances.append(ownPrototype.distance(to: query))
                if let nearestRival = ranked.first(where: { $0.id != speciesId }) {
                    rivalDistances.append(nearestRival.distance)
                }

                if ranked.first?.id == speciesId {
                    top1 += 1
                } else if let winner = ranked.first?.id {
                    misses[winner, default: 0] += 1
                }
                if ranked.prefix(3).contains(where: { $0.id == speciesId }) { top3 += 1 }
            }

            if let worst = misses.max(by: { $0.value < $1.value }) {
                confusions[speciesId] = "\(worst.key) (\(worst.value)×)"
            }

            results.append(SpeciesResult(
                speciesId: speciesId,
                queries: vectors.count,
                top1: top1,
                top3: top3,
                meanOwnDistance: mean(ownDistances),
                meanRivalDistance: mean(rivalDistances)
            ))
        }

        return Report(perSpecies: results, confusions: confusions, unreadable: loaded.unreadable)
    }

    /// Can a distance threshold tell "this is in the catalogue" from "this is something
    /// else entirely"? If not, the matcher cannot refuse, and will always name candidates
    /// for a plant it has never seen.
    public struct OpenSetReport: Sendable {
        public let inCatalogueDistances: [Float]
        public let outOfCatalogueDistances: [Float]
        /// The threshold with the best balanced accuracy, and what it achieves.
        public let bestThreshold: Float
        public let acceptedInCatalogue: Double
        public let rejectedOutOfCatalogue: Double
        public let unreadable: [String]

        /// Fraction of unknown plants that would still be given a shortlist.
        public var falseAcceptRate: Double { 1 - rejectedOutOfCatalogue }
    }

    public static func openSet(
        inCatalogue: URL,
        outOfCatalogue: URL,
        fileManager: FileManager = .default
    ) -> OpenSetReport {
        let knownLoad = loadVectors(in: inCatalogue, fileManager: fileManager)
        let unknownLoad = loadVectors(in: outOfCatalogue, fileManager: fileManager)
        let known = knownLoad.vectors
        let prototypes = known.compactMapValues { FeatureVector.mean(of: $0) }

        func nearest(_ query: FeatureVector, excluding excluded: String?) -> Float {
            prototypes
                .filter { $0.key != excluded }
                .values
                .map { $0.distance(to: query) }
                .min() ?? .greatestFiniteMagnitude
        }

        var inside: [Float] = []
        for (id, group) in known {
            for (index, query) in group.enumerated() {
                let heldOut = group.enumerated().filter { $0.offset != index }.map(\.element)
                guard let own = FeatureVector.mean(of: heldOut) else { continue }
                inside.append(min(own.distance(to: query), nearest(query, excluding: id)))
            }
        }

        let outside = unknownLoad.vectors.values.flatMap { group in
            group.map { nearest($0, excluding: nil) }
        }

        var best: (threshold: Float, accepted: Double, rejected: Double, score: Double) = (0, 0, 0, -1)
        for candidate in stride(from: Float(0.2), through: Float(1.2), by: 0.01) {
            let accepted = Double(inside.count { $0 <= candidate }) / Double(max(inside.count, 1))
            let rejected = Double(outside.count { $0 > candidate }) / Double(max(outside.count, 1))
            let score = (accepted + rejected) / 2
            if score > best.score { best = (candidate, accepted, rejected, score) }
        }

        return OpenSetReport(
            inCatalogueDistances: inside.sorted(),
            outOfCatalogueDistances: outside.sorted(),
            bestThreshold: best.threshold,
            acceptedInCatalogue: best.accepted,
            rejectedOutOfCatalogue: best.rejected,
            unreadable: knownLoad.unreadable + unknownLoad.unreadable
        )
    }

    // MARK: - Loading

    /// One subdirectory per species id; every image file inside becomes a vector. Anything
    /// that fails to list or read is named in `unreadable` rather than dropped.
    private static func loadVectors(
        in directory: URL,
        fileManager: FileManager
    ) -> (vectors: [String: [FeatureVector]], unreadable: [String]) {
        let revision = PhotoMatcher.currentRevision
        var vectors: [String: [FeatureVector]] = [:]
        var unreadable: [String] = []

        let entries: [String]
        do {
            entries = try fileManager.contentsOfDirectory(atPath: directory.path)
        } catch {
            return ([:], [directory.path])
        }

        for speciesId in entries.sorted() {
            let speciesDirectory = directory.appending(path: speciesId)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: speciesDirectory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let files: [String]
            do {
                files = try fileManager.contentsOfDirectory(atPath: speciesDirectory.path)
                    .filter(CataloguePhotos.isImageFile)
                    .sorted()
            } catch {
                unreadable.append(speciesDirectory.path)
                continue
            }

            var loaded: [FeatureVector] = []
            for file in files {
                let url = speciesDirectory.appending(path: file)
                do {
                    loaded.append(try PhotoMatcher.featureVector(for: url, revision: revision))
                } catch {
                    unreadable.append(url.path)
                }
            }
            if !loaded.isEmpty { vectors[speciesId] = loaded }
        }
        return (vectors, unreadable)
    }

    private static func mean(_ values: [Float]) -> Float {
        values.isEmpty ? 0 : values.reduce(0, +) / Float(values.count)
    }
}
