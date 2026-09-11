import Foundation

/// Renders the `SpeciesID` enum from the catalogue, so a species is a compile-time value and
/// a reference to one that does not exist cannot be written.
///
/// The catalogue is data and cannot be checked by the compiler, so this is the bridge: the
/// enum is generated from `species.json`, checked in, and a test asserts the two agree. A
/// lookalike's `entry` decodes as `SpeciesID`, so a catalogue that names a species with no
/// page fails to load — and the build fails with it.
public enum SpeciesIDGenerator {
    /// Where the generated file lives, relative to the repo root.
    public static let relativePath = "Packages/ForageCatalogue/Sources/ForageCatalogue/Generated/SpeciesID.swift"

    /// Swift source for the enum. Deterministic: sorted by id, so regenerating an unchanged
    /// catalogue is byte-identical and the check-in test can compare bytes.
    public static func render(ids: some Sequence<String>) -> String {
        let sorted = Array(Set(ids)).sorted()
        var lines: [String] = [
            "// Generated from ForageNZ/Catalogue/species.json by `catalogue-tool --normalise` or the editor's save.",
            "// Do not edit: add or rename a species in the catalogue and regenerate.",
            "",
            "/// One case per catalogue entry. Referencing a species means naming one of these, so a",
            "/// screen or a lookalike cannot point at a species the catalogue does not have.",
            "public enum SpeciesID: String, Codable, Sendable, Hashable, CaseIterable {"
        ]
        for id in sorted {
            lines.append("    case \(caseName(for: id)) = \"\(id)\"")
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    /// `death-cap` → `deathCap`; `red-pored-boletes` → `redPoredBoletes`.
    public static func caseName(for id: String) -> String {
        let parts = id.split(separator: "-")
        guard let first = parts.first else { return id }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// The generated file's location for a catalogue at `catalogueURL`, or `nil` if the
    /// catalogue is not inside the repo layout this expects.
    public static func fileURL(forCatalogueAt catalogueURL: URL) -> URL? {
        var root = catalogueURL
        for _ in CatalogueLocator.relativePath.split(separator: "/") { root.deleteLastPathComponent() }
        let candidate = root.appending(path: relativePath)
        return FileManager.default.fileExists(atPath: candidate.deletingLastPathComponent().path) ? candidate : nil
    }

    public enum Outcome: Sendable, Equatable {
        /// The enum already matched the catalogue.
        case unchanged
        /// The file was rewritten: rebuild before referencing the new or renamed species.
        case rewritten
        /// The catalogue is not inside the repo layout, so there is no enum to maintain.
        case notInRepo
    }

    /// Writes the enum for `species` next to the catalogue's package.
    public static func regenerate(for species: [ForageSpecies], catalogueURL: URL) throws(CatalogueFile.Failure) -> Outcome {
        guard let url = fileURL(forCatalogueAt: catalogueURL) else { return .notInRepo }
        let rendered = render(ids: species.map(\.id))
        let existing = try? String(contentsOf: url, encoding: .utf8)
        guard existing != rendered else { return .unchanged }
        do {
            try Data(rendered.utf8).write(to: url, options: .atomic)
        } catch {
            throw .unwritable(String(describing: error))
        }
        return .rewritten
    }
}
