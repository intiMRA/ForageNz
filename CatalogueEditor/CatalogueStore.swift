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
    /// Photo files dropped from an entry since the last save. Deleted on save, not on
    /// removal: an unsaved catalogue must never point at a file that is already gone.
    private(set) var pendingPhotoDeletions: [SpeciesPhoto] = []
    /// Set when a save rewrote `SpeciesID.swift`: the editor must be rebuilt before the new or
    /// renamed species can be chosen as a lookalike's page.
    private(set) var needsRebuildForSpeciesIDs = false
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
            pendingPhotoDeletions = []
            status = .clean
        } catch {
            status = .failed(message(for: error, file: fileURL.lastPathComponent))
        }
    }

    func save() {
        guard let fileURL else { return }
        do {
            try CatalogueFile.save(species, to: fileURL)
        } catch {
            status = .failed(message(for: error, file: fileURL.lastPathComponent))
            return
        }
        loaded = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
        editedIds = []

        do {
            if try SpeciesIDGenerator.regenerate(for: species, catalogueURL: fileURL) == .rewritten {
                needsRebuildForSpeciesIDs = true
            }
        } catch {
            status = .failed(message(for: error, file: SpeciesIDGenerator.relativePath))
            return
        }

        // The catalogue on disk no longer references these, so now they can go. A failure
        // here is reported, not swallowed: an orphan on disk fails the photo audit.
        var failures: [String] = []
        if let photoDirectory {
            for photo in pendingPhotoDeletions {
                do {
                    try PhotoImporter.deleteFile(for: photo, in: photoDirectory)
                } catch {
                    failures.append(error.localizedDescription)
                }
            }
        }
        pendingPhotoDeletions = []
        status = failures.isEmpty ? .saved(at: .now) : .failed(failures.joined(separator: "\n"))
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
    func addSpecies(commonName: String) throws(AddFailure) -> String {
        let trimmed = commonName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .nameEmpty }

        let id = ForageSpecies.makeIdentifier(from: trimmed)
        guard !id.isEmpty else { throw .nameEmpty }
        guard !species.contains(where: { $0.id == id }) else { throw .duplicate(id: id) }

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
        species.sort(by: ForageSpecies.displayOrder)
        editedIds.insert(id)
        status = .edited(count: editedIds.count)
        return id
    }

    func delete(id: String) {
        guard let removed = species.first(where: { $0.id == id }) else { return }
        pendingPhotoDeletions.append(contentsOf: removed.photos)
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

    /// Records that a photo's file should go when the catalogue is next saved.
    func schedulePhotoDeletion(_ photo: SpeciesPhoto) {
        pendingPhotoDeletions.append(photo)
    }

    var hasUnsavedChanges: Bool { !editedIds.isEmpty }

    /// Entries with no `sources`, worst-first — the queue this tool exists to empty.
    var unverified: [ForageSpecies] {
        species.filter { !$0.isVerified }.sorted { lhs, rhs in
            if lhs.reviewTier != rhs.reviewTier { return lhs.reviewTier < rhs.reviewTier }
            return ForageSpecies.displayOrder(lhs, rhs)
        }
    }

    private func message(for error: CatalogueFile.Failure, file name: String) -> String {
        switch error {
        case .unreadable(let detail): "Couldn't read \(name) — \(detail)"
        case .undecodable(let detail): "\(name) isn't valid catalogue JSON — \(detail)"
        case .unwritable(let detail): "Couldn't write \(name) — \(detail)"
        }
    }
}

/// Verification priority. Lethal claims first, because those are the entries where an
/// unchecked sentence can kill someone.
enum ReviewTier: Int, CaseIterable, Comparable {
    case lethalClaims
    case careRequired
    case straightforward

    var title: String {
        switch self {
        case .lethalClaims: "Lethal claims"
        case .careRequired: "Care required"
        case .straightforward: "Straightforward"
        }
    }

    static func < (lhs: ReviewTier, rhs: ReviewTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension ForageSpecies {
    var reviewTier: ReviewTier {
        if caution == .doNotEat || hasDeadlyLookalikeAsEdible { return .lethalClaims }
        if caution == .careRequired { return .careRequired }
        return .straightforward
    }
}
