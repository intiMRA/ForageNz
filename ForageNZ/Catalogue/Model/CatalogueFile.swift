import Foundation

/// Reads and writes the catalogue as JSON on disk.
///
/// The iOS app loads the copy bundled with it; the macOS editor edits the file in the repo.
/// Both go through `ForageSpecies`, so the editor cannot write JSON the app can't read.
public nonisolated enum CatalogueFile {
    public enum Failure: Error, Sendable, Equatable {
        case unreadable(String)
        case undecodable(String)
        case unwritable(String)
    }

    public static func load(from url: URL) throws(Failure) -> [ForageSpecies] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw .unreadable(String(describing: error))
        }
        do {
            return try decoder().decode([ForageSpecies].self, from: data)
        } catch {
            throw .undecodable(String(describing: error))
        }
    }

    /// Writes the catalogue back in a stable shape — sorted keys, two-space indent,
    /// unescaped slashes — so an edit to one entry produces a one-entry diff.
    public static func save(_ species: [ForageSpecies], to url: URL) throws(Failure) {
        do {
            let data = try encoder().encode(species)
            try (data + Data("\n".utf8)).write(to: url, options: .atomic)
        } catch {
            throw .unwritable(String(describing: error))
        }
    }

    public static func decoder() -> JSONDecoder {
        JSONDecoder()
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
