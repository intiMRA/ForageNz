import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

import ForageCatalogue

@Suite("Matcher evaluation")
struct MatcherEvaluationTests {
    /// Leave-one-out has to actually hold the query out. If it didn't, every species would
    /// score 100% — the prototype would contain the query — and the harness would be
    /// worthless while looking excellent.
    @Test("A species whose photos are all identical still scores against the others")
    func leaveOneOutIsHonest() throws {
        let root = try makeSet([
            "solid-red": Array(repeating: ImageKind.solid(1, 0, 0), count: 3),
            "solid-blue": Array(repeating: ImageKind.solid(0, 0, 1), count: 3)
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let report = MatcherEvaluation.run(directory: root)

        #expect(report.perSpecies.count == 2)
        #expect(report.queries == 6)
        // Two obviously different colours should separate cleanly.
        #expect(report.top1Accuracy == 1.0)
        for result in report.perSpecies {
            #expect(result.margin > 0, "\(result.speciesId) had no margin over its rival")
        }
    }

    @Test("A species with only one photo is excluded — it can't be held out")
    func singlePhotoSpeciesSkipped() throws {
        let root = try makeSet([
            "lonely": [.solid(0, 1, 0)],
            "pair-a": [.solid(1, 0, 0), .solid(1, 0.1, 0)],
            "pair-b": [.solid(0, 0, 1), .solid(0, 0.1, 1)]
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let report = MatcherEvaluation.run(directory: root)
        #expect(!report.perSpecies.contains { $0.speciesId == "lonely" })
        #expect(report.perSpecies.count == 2)
    }

    @Test("An empty directory reports nothing rather than dividing by zero")
    func emptyDirectory() throws {
        let root = try makeSet([:])
        defer { try? FileManager.default.removeItem(at: root) }

        let report = MatcherEvaluation.run(directory: root)
        #expect(report.queries == 0)
        #expect(report.top1Accuracy == 0)
        #expect(report.top3Accuracy == 0)
    }

    @Test("Confusions name the species that actually won")
    func confusionsAreRecorded() throws {
        // Two near-identical greys will cross-match; the confusion map should say so.
        let root = try makeSet([
            "grey-a": [.solid(0.50, 0.50, 0.50), .solid(0.51, 0.51, 0.51), .solid(0.49, 0.49, 0.49)],
            "grey-b": [.solid(0.505, 0.505, 0.505), .solid(0.495, 0.495, 0.495), .solid(0.50, 0.50, 0.50)]
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let report = MatcherEvaluation.run(directory: root)
        for (species, confusedWith) in report.confusions {
            #expect(confusedWith.contains("grey-"), "\(species) confused with something unexpected")
        }
    }

    // MARK: - Synthetic image sets

    private enum ImageKind {
        case solid(Double, Double, Double)
    }

    private func makeSet(_ layout: [String: [ImageKind]]) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "eval-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        for (speciesId, kinds) in layout {
            let directory = root.appending(path: speciesId)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (index, kind) in kinds.enumerated() {
                try write(kind, to: directory.appending(path: "\(speciesId)-\(index + 1).png"))
            }
        }
        return root
    }

    private func write(_ kind: ImageKind, to url: URL) throws {
        let size = 224
        let context = try #require(CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        switch kind {
        case .solid(let red, let green, let blue):
            context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }

        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
