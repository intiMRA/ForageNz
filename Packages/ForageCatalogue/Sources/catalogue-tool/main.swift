import CoreGraphics
import ForageCatalogue
import ForageCatalogueTooling
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Headless catalogue maintenance. The GUI editor is the `CatalogueEditor` target in
// ForageNZ.xcodeproj; this exists so formatting and checking can run without a window
// (after hand-editing species.json, or in CI).
//
//   swift run catalogue-tool --normalise   rewrite in the canonical shape
//   swift run catalogue-tool --check       report blocking validation issues, non-zero if any

let arguments = CommandLine.arguments

guard let url = CatalogueLocator.resolve() else {
    FileHandle.standardError.write(Data("Couldn't find \(CatalogueLocator.relativePath). Pass --catalogue <path>.\n".utf8))
    exit(1)
}

/// A flat mid-grey image: the "nothing like a plant" baseline for calibration.
func makeControlImage() -> URL? {
    guard let context = CGContext(
        data: nil, width: 320, height: 320, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 320, height: 320))

    guard let image = context.makeImage() else { return nil }
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "control-\(UUID().uuidString).png")
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination) ? url : nil
}

func loadCatalogue() -> [ForageSpecies] {
    do {
        return try CatalogueFile.load(from: url)
    } catch {
        FileHandle.standardError.write(Data("Couldn't read the catalogue: \(error)\n".utf8))
        exit(1)
    }
}

/// Names every input an evaluation could not read, and returns the exit code for it. A
/// measurement over a set that silently shrank is not a measurement.
func reportUnreadable(_ paths: [String]) -> Int32 {
    guard !paths.isEmpty else { return 0 }
    FileHandle.standardError.write(Data("\n\(paths.count) input(s) could not be read — the figures above exclude them:\n".utf8))
    for path in paths {
        FileHandle.standardError.write(Data("  \(path)\n".utf8))
    }
    return 1
}

if arguments.contains("--normalise") {
    let species = loadCatalogue()
    do {
        try CatalogueFile.save(species, to: url)
    } catch {
        FileHandle.standardError.write(Data("Couldn't write the catalogue: \(error)\n".utf8))
        exit(1)
    }
    print("Normalised \(species.count) entries in \(url.path(percentEncoded: false))")
    do {
        switch try SpeciesIDGenerator.regenerate(for: species, catalogueURL: url) {
        case .unchanged: print("SpeciesID enum already matches the catalogue")
        case .rewritten: print("Regenerated \(SpeciesIDGenerator.relativePath) — rebuild before referencing new species")
        case .notInRepo: FileHandle.standardError.write(Data("Catalogue is outside the repo; SpeciesID enum not regenerated\n".utf8))
        }
    } catch {
        FileHandle.standardError.write(Data("Couldn't regenerate SpeciesID: \(error)\n".utf8))
        exit(1)
    }
    exit(0)
}

if let flag = arguments.firstIndex(of: "--openset") {
    guard arguments.count > flag + 2 else {
        FileHandle.standardError.write(Data("--openset needs <in-catalogue-dir> <out-of-catalogue-dir>\n".utf8))
        exit(2)
    }
    let report = MatcherEvaluation.openSet(
        inCatalogue: URL(fileURLWithPath: arguments[flag + 1]),
        outOfCatalogue: URL(fileURLWithPath: arguments[flag + 2])
    )

    func summarise(_ label: String, _ values: [Float]) {
        guard let first = values.first, let last = values.last else { print("\(label): none"); return }
        let median = values[values.count / 2]
        let p10 = values[max(0, values.count / 10)]
        let p90 = values[min(values.count - 1, values.count * 9 / 10)]
        print(String(format: "%@  n=%d  min %.2f  p10 %.2f  median %.2f  p90 %.2f  max %.2f",
                     label, values.count, first, p10, median, p90, last))
    }

    print("Nearest-prototype distance distributions\n")
    summarise("in catalogue    ", report.inCatalogueDistances)
    summarise("NOT in catalogue", report.outOfCatalogueDistances)
    print(String(format: "\nBest threshold %.2f: accepts %.0f%% of known, rejects %.0f%% of unknown",
                 report.bestThreshold,
                 report.acceptedInCatalogue * 100,
                 report.rejectedOutOfCatalogue * 100))
    print(String(format: "So %.0f%% of plants NOT in the guide would still be handed a shortlist.",
                 report.falseAcceptRate * 100))
    exit(reportUnreadable(report.unreadable))
}

if let flag = arguments.firstIndex(of: "--evaluate") {
    guard arguments.count > flag + 1 else {
        FileHandle.standardError.write(Data("--evaluate needs a directory of labelled photos\n".utf8))
        exit(2)
    }
    let directory = URL(fileURLWithPath: arguments[flag + 1])
    let report = MatcherEvaluation.run(directory: directory)

    guard report.queries > 0 else {
        FileHandle.standardError.write(Data("No species with 2+ photos found in \(directory.path)\n".utf8))
        exit(1)
    }

    print("Leave-one-out over \(report.queries) photos, \(report.perSpecies.count) species\n")
    func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }
    func percent(_ part: Int, of whole: Int) -> String {
        whole == 0 ? "  -" : String(format: "%3d%%", Int(Double(part) / Double(whole) * 100))
    }

    print("\(pad("species", 20)) n  top1  top3   own  rival  margin  confused with")
    print(String(repeating: "-", count: 78))
    for result in report.perSpecies.sorted(by: { $0.margin < $1.margin }) {
        let numbers = String(
            format: "%2d  %@  %@  %.2f   %.2f  %+.2f",
            result.queries,
            percent(result.top1, of: result.queries),
            percent(result.top3, of: result.queries),
            result.meanOwnDistance,
            result.meanRivalDistance,
            result.margin
        )
        print("\(pad(result.speciesId, 20)) \(numbers)  \(report.confusions[result.speciesId] ?? "")")
    }
    print(String(repeating: "-", count: 78))
    print(String(format: "overall top-1 %.1f%%   top-3 %.1f%%",
                 report.top1Accuracy * 100, report.top3Accuracy * 100))
    exit(reportUnreadable(report.unreadable))
}

if arguments.contains("--index") {
    let species = loadCatalogue()
    let photoDirectory = PhotoAudit.directory(forCatalogueAt: url)
    let (index, unreadable) = PhotoIndex.build(species: species, photoDirectory: photoDirectory)

    print("Vision feature-print revision \(index.revision)")
    print("\(index.prototypes.count) prototype(s) from \(index.prototypes.reduce(0) { $0 + $1.photoCount }) photo(s)")
    for photo in unreadable {
        print("unreadable: \(photo.speciesId) · \(photo.fileName) — \(photo.failure)")
    }

    // Within-species spread: how far apart are two photos of the SAME species?
    for entry in species where entry.photos.count >= 2 {
        var vectors: [FeatureVector] = []
        for photo in entry.photos {
            // Already reported above if it failed; here it simply doesn't take part.
            if let vector = try? PhotoMatcher.featureVector(for: photoDirectory.appending(path: photo.fileName), revision: index.revision) {
                vectors.append(vector)
            }
        }
        var worst: Float = 0
        for i in vectors.indices {
            for j in vectors.indices where j > i {
                worst = max(worst, vectors[i].distance(to: vectors[j]))
            }
        }
        print(String(format: "within  %@: widest gap between its own photos %.3f", entry.id, worst))
    }

    // Between-species: the nearest other prototype. Needs to exceed the within figure for
    // matching to mean anything.
    for a in index.prototypes {
        let nearest = index.prototypes
            .filter { $0.speciesId != a.speciesId }
            .map { (id: $0.speciesId, d: a.vector.distance(to: $0.vector)) }
            .min { $0.d < $1.d }
        if let nearest {
            print(String(format: "between %@: nearest is %@ at %.3f", a.speciesId, nearest.id, nearest.d))
        }
    }
    if index.prototypes.count < 2 {
        print("Only one species has photos — between-species separation can't be measured yet.")
    }
    if !unreadable.isEmpty {
        print("\n\(unreadable.count) photo(s) could not be read; the figures above exclude them.")
    }

    // Calibration: how far is an unrelated image? Within-species distance has to be well
    // below this for ranking to carry any signal.
    if let control = makeControlImage() {
        defer { try? FileManager.default.removeItem(at: control) }
        do {
            let controlVector = try PhotoMatcher.featureVector(for: control, revision: index.revision)
            for a in index.prototypes {
                print(String(format: "control %@: distance to an unrelated image %.3f",
                             a.speciesId, a.vector.distance(to: controlVector)))
            }
        } catch {
            print("control image could not be read: \(error)")
        }
    }
    exit(unreadable.isEmpty ? 0 : 1)
}

if arguments.contains("--photos") {
    let species = loadCatalogue()
    let report = PhotoAudit.audit(
        species: species,
        photoDirectory: PhotoAudit.directory(forCatalogueAt: url)
    )
    for finding in report.findings {
        print("\(finding.speciesId) · \(finding.fileName): \(finding.problem)")
    }
    for orphan in report.orphanedFiles {
        print("orphan · \(orphan): referenced by no entry")
    }
    let thin = species.filter { entry in
        entry.caution != .doNotEat && entry.photos.count < CataloguePhotos.recommendedCount(
            hasDeadlyLookalike: entry.highestLookalikeRisk == .deadly
        )
    }
    print("""
    \(report.photoCount) photo(s) · \(report.totalBytes / 1024) KB of \(CataloguePhotos.totalByteBudget / 1_000_000) MB budget
    \(thin.count) entrie(s) below their photo target (4, or 6 with a deadly lookalike)
    """)
    exit(report.isClean ? 0 : 1)
}

// Attach reviewed photos from a staging manifest. Only photos whose `caption` has been filled
// in are attached: writing the caption IS the review — it says you looked at the picture,
// confirmed the species, and named the feature it shows. Everything else is skipped.
if let flag = arguments.firstIndex(of: "--attach") {
    guard arguments.count > flag + 1 else {
        FileHandle.standardError.write(Data("--attach needs the path to a staging manifest.json\n".utf8))
        exit(1)
    }
    let manifestURL = URL(fileURLWithPath: arguments[flag + 1])
    let stagingDirectory = manifestURL.deletingLastPathComponent()

    struct StagedPhoto: Decodable {
        let file: String
        let licence: String
        let credit: String
        let sourceURL: String
        let caption: String
    }
    let manifest: [String: [StagedPhoto]]
    do {
        manifest = try JSONDecoder().decode([String: [StagedPhoto]].self, from: Data(contentsOf: manifestURL))
    } catch {
        FileHandle.standardError.write(Data("Couldn't read the manifest: \(error)\n".utf8))
        exit(1)
    }

    var species = loadCatalogue()
    let photoDirectory = PhotoAudit.directory(forCatalogueAt: url)
    var attached = 0
    var skipped = 0
    var failed = 0

    for index in species.indices {
        guard let staged = manifest[species[index].id] else { continue }
        var photos = species[index].photos
        for candidate in staged {
            let caption = candidate.caption.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !caption.isEmpty else {
                skipped += 1
                continue
            }
            do {
                // The stager writes each species into its own folder under the manifest's.
                let photo = try PhotoImporter.importPhoto(
                    from: stagingDirectory.appending(path: species[index].id).appending(path: candidate.file),
                    speciesId: species[index].id,
                    existing: photos,
                    into: photoDirectory,
                    caption: caption,
                    credit: "\(candidate.credit) (\(candidate.licence.uppercased()))",
                    sourceURL: URL(string: candidate.sourceURL)
                )
                photos.append(photo)
                attached += 1
                print("\(species[index].id) · \(photo.fileName) ← \(candidate.file)")
            } catch {
                failed += 1
                FileHandle.standardError.write(Data("\(species[index].id) · \(candidate.file): \(error.localizedDescription)\n".utf8))
            }
        }
        species[index] = species[index].with(photos: photos)
    }

    do {
        try CatalogueFile.save(species, to: url)
    } catch {
        FileHandle.standardError.write(Data("Couldn't write the catalogue: \(error)\n".utf8))
        exit(1)
    }
    print("\(attached) attached · \(skipped) skipped (no caption) · \(failed) failed")
    exit(failed == 0 ? 0 : 1)
}

if arguments.contains("--check") {
    let species = loadCatalogue()
    var blocking = 0
    for entry in species {
        for issue in entry.blockingIssues {
            print("\(entry.id) · \(issue.label): \(issue.message)")
            blocking += 1
        }
    }
    let unverified = species.filter { !$0.isVerified }.count
    print("\(species.count) entries · \(blocking) blocking issue(s) · \(unverified) unverified")
    exit(blocking == 0 ? 0 : 1)
}

print("""
catalogue-tool — headless catalogue maintenance

  --normalise            rewrite species.json in the canonical shape
  --check                report blocking validation issues
  --photos               report photo budget, missing files and orphans
  --attach <manifest>    attach the captioned photos from a staging manifest
  --index                build the photo match index and report its separation
  --evaluate <dir>       leave-one-out accuracy over a directory of labelled photos
  --openset <in> <out>   open-set separation between catalogue and unknown photos
  --catalogue <path>     use a different catalogue file

The editor with a window is the CatalogueEditor scheme in ForageNZ.xcodeproj.
""")
exit(0)
