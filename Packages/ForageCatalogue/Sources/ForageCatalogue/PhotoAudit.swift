import Foundation

/// Filesystem checks on the shipped photos.
///
/// `ForageSpecies.validationIssues` is pure — it can't know whether a file exists or how
/// big it is. These checks need a directory, so they live here and run in tests and in the
/// editor rather than on the model.
public nonisolated enum PhotoAudit {
    public struct Finding: Sendable, Hashable {
        public let speciesId: String
        public let fileName: String
        public let problem: String
    }

    public struct Report: Sendable {
        public let findings: [Finding]
        public let totalBytes: Int
        public let photoCount: Int
        /// Files in the directory that no entry references.
        public let orphanedFiles: [String]

        public var isClean: Bool { findings.isEmpty && orphanedFiles.isEmpty }
    }

    public static func audit(
        species: [ForageSpecies],
        photoDirectory: URL,
        fileManager: FileManager = .default
    ) -> Report {
        var findings: [Finding] = []
        var totalBytes = 0
        var referenced: Set<String> = []
        var count = 0

        for entry in species {
            for photo in entry.photos {
                count += 1
                referenced.insert(photo.fileName)
                let url = photoDirectory.appending(path: photo.fileName)

                guard fileManager.fileExists(atPath: url.path) else {
                    findings.append(Finding(
                        speciesId: entry.id, fileName: photo.fileName,
                        problem: "Referenced but missing from \(CataloguePhotos.directoryName)/."
                    ))
                    continue
                }

                // A file whose size can't be read is a finding, not zero bytes — otherwise
                // an unreadable photo would sail under both the per-photo and total budgets.
                let bytes: Int
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    guard let size = attributes[.size] as? Int else {
                        findings.append(Finding(
                            speciesId: entry.id, fileName: photo.fileName,
                            problem: "Size unreadable — the filesystem returned no size for it."
                        ))
                        continue
                    }
                    bytes = size
                } catch {
                    findings.append(Finding(
                        speciesId: entry.id, fileName: photo.fileName,
                        problem: "Size unreadable — \(error.localizedDescription)"
                    ))
                    continue
                }
                totalBytes += bytes

                if bytes > CataloguePhotos.maximumBytesPerPhoto {
                    findings.append(Finding(
                        speciesId: entry.id, fileName: photo.fileName,
                        problem: "\(bytes / 1024) KB exceeds the \(CataloguePhotos.maximumBytesPerPhoto / 1024) KB per-photo ceiling — re-import it."
                    ))
                }
            }
        }

        // Only image files can be orphans — a README alongside them is not stray data. A
        // directory that exists but can't be listed is reported; one that doesn't exist yet
        // is fine when nothing references it.
        var orphans: [String] = []
        if fileManager.fileExists(atPath: photoDirectory.path) {
            do {
                orphans = try fileManager.contentsOfDirectory(atPath: photoDirectory.path)
                    .filter { name in
                        !name.hasPrefix(".") && CataloguePhotos.isImageFile(name) && !referenced.contains(name)
                    }
                    .sorted()
            } catch {
                findings.append(Finding(
                    speciesId: "-", fileName: CataloguePhotos.directoryName,
                    problem: "Photo directory unreadable — \(error.localizedDescription)"
                ))
            }
        }

        if totalBytes > CataloguePhotos.totalByteBudget {
            findings.append(Finding(
                speciesId: "-", fileName: "-",
                problem: "Photos total \(totalBytes / 1_000_000) MB, over the \(CataloguePhotos.totalByteBudget / 1_000_000) MB budget."
            ))
        }

        return Report(
            findings: findings,
            totalBytes: totalBytes,
            photoCount: count,
            orphanedFiles: orphans
        )
    }

    /// The photo directory next to a catalogue file.
    public static func directory(forCatalogueAt url: URL) -> URL {
        url.deletingLastPathComponent().appending(path: CataloguePhotos.directoryName)
    }
}
