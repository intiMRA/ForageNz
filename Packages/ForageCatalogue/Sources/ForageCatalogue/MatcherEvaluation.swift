import Foundation

/// Measures how well photo matching actually works, using leave-one-out over a directory
/// of labelled photos.
///
/// Accuracy claims about a matcher are worthless without this: a prototype built from a
/// photo will always match that photo. Each query here is scored against prototypes built
/// from the *other* photos of its species.
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
        let revision = PhotoMatcher.currentRevision
        var vectorsBySpecies: [String: [FeatureVector]] = [:]

        let entries = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for speciesId in entries.sorted() {
            let speciesDirectory = directory.appending(path: speciesId)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: speciesDirectory.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let files = ((try? fileManager.contentsOfDirectory(atPath: speciesDirectory.path)) ?? [])
                .filter { ["jpg", "jpeg", "png", "heic"].contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }
                .sorted()

            let vectors = files.compactMap { file in
                try? PhotoMatcher.featureVector(
                    for: speciesDirectory.appending(path: file), revision: revision
                )
            }
            if vectors.count >= 2 { vectorsBySpecies[speciesId] = vectors }
        }

        var results: [SpeciesResult] = []
        var confusions: [String: String] = [:]

        for (speciesId, vectors) in vectorsBySpecies.sorted(by: { $0.key < $1.key }) {
            var top1 = 0
            var top3 = 0
            var ownDistances: [Float] = []
            var rivalDistances: [Float] = []
            var misses: [String: Int] = [:]

            for (index, query) in vectors.enumerated() {
                // Prototype from every photo of this species EXCEPT the query.
                let heldOut = vectors.enumerated().filter { $0.offset != index }.map(\.element)
                guard let ownPrototype = FeatureVector.mean(of: heldOut) else { continue }

                var ranked: [(id: String, distance: Float)] = [
                    (speciesId, ownPrototype.distance(to: query))
                ]
                for (rivalId, rivalVectors) in vectorsBySpecies where rivalId != speciesId {
                    if let rival = FeatureVector.mean(of: rivalVectors) {
                        ranked.append((rivalId, rival.distance(to: query)))
                    }
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

        return Report(perSpecies: results, confusions: confusions)
    }

    private static func mean(_ values: [Float]) -> Float {
        values.isEmpty ? 0 : values.reduce(0, +) / Float(values.count)
    }
}
