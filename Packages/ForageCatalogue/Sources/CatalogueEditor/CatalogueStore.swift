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
    let fileURL: URL

    /// Ids whose entry differs from what was loaded, so the sidebar can mark them.
    private(set) var editedIds: Set<String> = []
    private var loaded: [String: ForageSpecies] = [:]

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() {
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
        do {
            try CatalogueFile.save(species, to: fileURL)
            loaded = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
            editedIds = []
            status = .saved(at: .now)
        } catch {
            status = .failed(message(for: error))
        }
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
        switch error {
        case .unreadable(let detail): "Couldn't read \(fileURL.lastPathComponent) — \(detail)"
        case .undecodable(let detail): "\(fileURL.lastPathComponent) isn't valid catalogue JSON — \(detail)"
        case .unwritable(let detail): "Couldn't write \(fileURL.lastPathComponent) — \(detail)"
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

    /// A copy with one field replaced. The model is immutable by design, so the editor
    /// rebuilds an entry rather than mutating it.
    func with(
        commonName: String? = nil,
        maoriName: String?? = nil,
        scientificName: String? = nil,
        category: ForageCategory? = nil,
        origin: ForageOrigin? = nil,
        caution: CautionLevel? = nil,
        months: [ForageMonth]? = nil,
        summary: String? = nil,
        habitat: String? = nil,
        identification: String? = nil,
        edibleParts: String? = nil,
        preparation: String? = nil,
        lookalikes: [Lookalike]? = nil,
        warnings: [String]? = nil,
        harvestEthics: String?? = nil,
        sources: [String]? = nil,
        recipes: [Recipe]? = nil
    ) -> ForageSpecies {
        ForageSpecies(
            id: id,
            commonName: commonName ?? self.commonName,
            maoriName: maoriName ?? self.maoriName,
            scientificName: scientificName ?? self.scientificName,
            category: category ?? self.category,
            origin: origin ?? self.origin,
            caution: caution ?? self.caution,
            months: months ?? self.months,
            summary: summary ?? self.summary,
            habitat: habitat ?? self.habitat,
            identification: identification ?? self.identification,
            edibleParts: edibleParts ?? self.edibleParts,
            preparation: preparation ?? self.preparation,
            lookalikes: lookalikes ?? self.lookalikes,
            warnings: warnings ?? self.warnings,
            harvestEthics: harvestEthics ?? self.harvestEthics,
            sources: sources ?? self.sources,
            recipes: recipes ?? self.recipes
        )
    }
}
