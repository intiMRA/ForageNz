import Foundation

/// Finds the repo's `species.json` so neither the editor nor the CLI needs it configured.
///
/// A `--catalogue <path>` argument wins; otherwise it walks up from a starting directory
/// looking for the file, which covers being launched from Xcode, from the package
/// directory, or from anywhere inside the repo.
public enum CatalogueLocator {
    public static let relativePath = "ForageNZ/Catalogue/species.json"

    /// The catalogue to open, or `nil` when none could be found and none was given.
    /// `sourceAnchor` expands at the CALL SITE, so it is the caller's own source file —
    /// which is inside the repo. Launched from Xcode, an app bundle's working directory and
    /// bundle path are both in DerivedData with no repo above them, so this is the only
    /// origin that reliably locates the catalogue. Fine for a developer tool; it would be
    /// wrong for anything shipped to a user.
    public static func resolve(
        arguments: [String] = CommandLine.arguments,
        startingAt start: URL? = nil,
        fileManager: FileManager = .default,
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        bundleURL: URL = Bundle.main.bundleURL,
        sourceAnchor: String = #filePath
    ) -> URL? {
        if let flag = arguments.firstIndex(of: "--catalogue"), arguments.count > flag + 1 {
            return URL(fileURLWithPath: arguments[flag + 1])
        }

        let origins = [
            start,
            URL(fileURLWithPath: currentDirectory),
            URL(fileURLWithPath: sourceAnchor).deletingLastPathComponent(),
            bundleURL
        ].compactMap(\.self)

        for origin in origins {
            if let found = search(from: origin, fileManager: fileManager) { return found }
        }
        return nil
    }

    /// Walks up at most `levels` directories looking for the catalogue.
    public static func search(from start: URL, levels: Int = 8, fileManager: FileManager = .default) -> URL? {
        var directory = start.standardizedFileURL
        for _ in 0..<levels {
            let candidate = directory.appending(path: relativePath)
            if fileManager.fileExists(atPath: candidate.path) { return candidate }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }
        return nil
    }
}
