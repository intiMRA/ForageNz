import ForageCatalogue
import Foundation
import Observation

/// The catalogue being edited, plus where it came from and whether it still matches disk.
@Observable
@MainActor
final class CatalogueStore {
    enum Status: Equatable {
        case clean
        case edited(count: Int)
        case saved(at: Date)
        case failed(String)
    }

    private(set) var species: [ForageSpecies] = []
    private(set) var status: Status = .clean
    /// `nil` when no catalogue could be located — the editor says so rather than
    /// silently editing nothing.
    let fileURL: URL?

    /// Ids whose entry differs from what was loaded, so the sidebar can mark them.
    private(set) var editedIds: Set<String> = []
    private var loaded: [String: ForageSpecies] = [:]

    init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    var displayPath: String {
        fileURL?.path(percentEncoded: false) ?? "No catalogue found"
    }

    /// Where photos live, alongside the catalogue file.
    var photoDirectory: URL? {
        fileURL.map(PhotoAudit.directory(forCatalogueAt:))
    }

    /// Filesystem checks the pure model can't do: missing files, oversized files, orphans.
    var photoReport: PhotoAudit.Report? {
        guard let photoDirectory else { return nil }
        return PhotoAudit.audit(species: species, photoDirectory: photoDirectory)
    }

    func load() {
        guard let fileURL else {
            status = .failed(
                "Couldn't find \(CatalogueLocator.relativePath). Open the CatalogueEditor scheme "
                + "from inside the repo, or pass --catalogue <path> in the scheme's arguments."
            )
            return
        }
        do {
            let loadedSpecies = try CatalogueFile.load(from: fileURL)
            species = loadedSpecies
            loaded = Dictionary(uniqueKeysWithValues: loadedSpecies.map { ($0.id, $0) })
            editedIds = []
            status = .clean
        } catch {
            status = .failed(message(for: error))
        }
    }

    func save() {
        guard let fileURL else { return }
        do {
            try CatalogueFile.save(species, to: fileURL)
            loaded = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
            editedIds = []
            status = .saved(at: .now)
        } catch {
            status = .failed(message(for: error))
        }
    }

    enum AddFailure: Error, Equatable {
        case nameEmpty
        case duplicate(id: String)
    }

    /// Creates a skeleton entry from a common name and returns its id.
    ///
    /// Deliberately a skeleton, not a blank: caution defaults to `careRequired` so a new
    /// entry can never start out claiming to be safe, and the blocking issues on it act as
    /// the to-do list for filling it in.
    func addSpecies(commonName: String) -> Result<String, AddFailure> {
        let trimmed = commonName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.nameEmpty) }

        let id = ForageSpecies.makeIdentifier(from: trimmed)
        guard !id.isEmpty else { return .failure(.nameEmpty) }
        guard !species.contains(where: { $0.id == id }) else { return .failure(.duplicate(id: id)) }

        let new = ForageSpecies(
            id: id,
            commonName: trimmed,
            scientificName: "",
            category: .greens,
            origin: .introduced,
            caution: .careRequired,
            summary: "",
            habitat: "",
            identification: "",
            edibleParts: "",
            preparation: ""
        )
        species.append(new)
        species.sort { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }
        editedIds.insert(id)
        status = .edited(count: editedIds.count)
        return .success(id)
    }

    func delete(id: String) {
        species.removeAll { $0.id == id }
        editedIds.insert(id)
        status = .edited(count: editedIds.count)
    }

    /// Entries that would fail the build as they stand.
    var unpublishable: [ForageSpecies] {
        species.filter { !$0.isPublishable }
    }

    func update(_ updated: ForageSpecies) {
        guard let index = species.firstIndex(where: { $0.id == updated.id }) else { return }
        species[index] = updated

        if loaded[updated.id] == updated {
            editedIds.remove(updated.id)
        } else {
            editedIds.insert(updated.id)
        }
        status = editedIds.isEmpty ? .clean : .edited(count: editedIds.count)
    }

    var hasUnsavedChanges: Bool { !editedIds.isEmpty }

    /// Entries with no `sources`, worst-first — the queue this tool exists to empty.
    var unverified: [ForageSpecies] {
        species.filter { !$0.isVerified }.sorted { lhs, rhs in
            if lhs.reviewTier != rhs.reviewTier { return lhs.reviewTier < rhs.reviewTier }
            return lhs.commonName.localizedCaseInsensitiveCompare(rhs.commonName) == .orderedAscending
        }
    }

    private func message(for error: CatalogueFile.Failure) -> String {
        let name = fileURL?.lastPathComponent ?? "the catalogue"
        return switch error {
        case .unreadable(let detail): "Couldn't read \(name) — \(detail)"
        case .undecodable(let detail): "\(name) isn't valid catalogue JSON — \(detail)"
        case .unwritable(let detail): "Couldn't write \(name) — \(detail)"
        }
    }
}

extension ForageSpecies {
    /// Verification priority: lethal claims first, then anything needing care.
    var reviewTier: Int {
        if caution == .doNotEat || highestLookalikeRisk == .deadly { return 1 }
        if caution == .careRequired { return 2 }
        return 3
    }

    var reviewTierLabel: String {
        switch reviewTier {
        case 1: "Lethal claims"
        case 2: "Care required"
        default: "Straightforward"
        }
    }
}
