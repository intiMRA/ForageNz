import Foundation

/// One candidate photo waiting for a verdict, from `Tools/fetch_catalogue_photos.py`.
///
/// Everything here except the file itself comes from the staging manifest, and all of it is
/// there to support one judgement: does this frame agree with the entry's own prose? The
/// weraroa pass rejected the richest observation because it was shot on a mown lawn, which
/// only `place` would have told you.
struct StagedPhoto: Identifiable, Hashable {
    let fileURL: URL
    /// Attribution as the licence requires it, carried straight through to the photo record.
    let credit: String
    let sourceURL: URL?
    let place: String
    let observedOn: String
    /// How many iNaturalist users agreed with the identification. A frame is only as good as
    /// the name attached to it.
    let agreeingIdentifications: Int
    let licence: String
    let bytes: Int

    var id: URL { fileURL }
    var fileName: String { fileURL.lastPathComponent }
}

/// Finds and reads the staging area the photo fetcher writes to.
///
/// Editor-only on purpose: staged photos are a step in making the catalogue, not part of it,
/// so none of this belongs in `Model/` where the iOS app would compile it for nothing.
enum StagedPhotos {
    /// Matches the fetcher's `--staging` default, which is relative to the repo root.
    static let directoryName = ".staged-photos"

    /// The staging directory for a catalogue, or `nil` when there is none to review.
    ///
    /// The catalogue sits at `CatalogueLocator.relativePath` inside the repo, so the root is
    /// that many components up — derived rather than hardcoded to three, so moving the
    /// catalogue moves this with it.
    static func directory(
        forCatalogueAt url: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        let depth = CatalogueLocator.relativePath.split(separator: "/").count
        var root = url
        for _ in 0..<depth { root = root.deletingLastPathComponent() }

        let staging = root.appending(path: directoryName)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: staging.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        return staging
    }

    /// Candidates for one entry, best-ranked first.
    ///
    /// Driven by the files actually on disk, with the manifests supplying their metadata: a
    /// manifest entry whose file has been kept or discarded is stale, and showing it would
    /// offer a verdict on something that is no longer there.
    static func candidates(
        forSpecies speciesId: String,
        in stagingDirectory: URL,
        fileManager: FileManager = .default
    ) -> [StagedPhoto] {
        let directory = stagingDirectory.appending(path: speciesId)
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }

        let metadata = manifestEntries(in: stagingDirectory, fileManager: fileManager)
        return names
            .filter(CataloguePhotos.isImageFile)
            .sorted { rank(of: $0) < rank(of: $1) }
            .map { name in
                let entry = metadata[name]
                let fileURL = directory.appending(path: name)
                return StagedPhoto(
                    fileURL: fileURL,
                    credit: entry?.credit ?? "",
                    sourceURL: entry?.sourceURL.flatMap(URL.init(string:)),
                    place: entry?.place ?? "",
                    observedOn: entry?.observedOn ?? "",
                    agreeingIdentifications: entry?.agreeingIdentifications ?? 0,
                    licence: entry?.licence ?? "",
                    bytes: entry?.bytes ?? fileSize(of: fileURL, fileManager: fileManager)
                )
            }
    }

    /// Deletes a rejected candidate. Safe to do immediately, unlike dropping a shipped photo:
    /// the staging area is gitignored scratch and the fetcher can re-download it.
    static func discard(_ photo: StagedPhoto, fileManager: FileManager = .default) throws {
        try fileManager.removeItem(at: photo.fileURL)
    }

    // MARK: - Manifests

    /// What the fetcher records per staged file. Its `caption` is always blank — captions are
    /// the one thing no query can write — so it is not read here.
    private struct ManifestEntry: Decodable {
        let fileName: String
        let credit: String
        let sourceURL: String?
        let place: String?
        let observedOn: String?
        let agreeingIdentifications: Int?
        let licence: String?
        let bytes: Int?
    }

    /// Every manifest merged, keyed by file name.
    ///
    /// The fetcher writes a new `manifest<N>.json` per run rather than rewriting one, so a
    /// file re-staged by a later run is described in more than one. Later runs win: they
    /// describe the bytes currently on disk.
    private static func manifestEntries(
        in stagingDirectory: URL,
        fileManager: FileManager
    ) -> [String: ManifestEntry] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: stagingDirectory.path) else {
            return [:]
        }

        let manifests = names
            .filter { $0.hasPrefix("manifest") && $0.hasSuffix(".json") }
            .sorted { rank(of: $0) < rank(of: $1) }

        var merged: [String: ManifestEntry] = [:]
        for name in manifests {
            let url = stagingDirectory.appending(path: name)
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([String: [ManifestEntry]].self, from: data)
            else { continue }
            for entry in decoded.values.flatMap(\.self) {
                merged[entry.fileName] = entry
            }
        }
        return merged
    }

    // MARK: - Ordering

    /// The trailing number in a staged name, so `…-10` sorts after `…-2` and `manifest10`
    /// after `manifest2`. An unnumbered `manifest.json` is the first run, hence zero.
    private static func rank(of name: String) -> Int {
        let stem = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
        let digits = String(stem.reversed().prefix(while: \.isNumber).reversed())
        return Int(digits) ?? 0
    }

    private static func fileSize(of url: URL, fileManager: FileManager) -> Int {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? Int) ?? 0
    }
}
