import ForageCatalogue
import Foundation
import Testing

@testable import CatalogueEditor

/// The editor's state machine, exercised against a throwaway copy of a catalogue on disk.
@Suite("Catalogue store")
@MainActor
struct CatalogueStoreTests {
    // MARK: - Fixtures

    /// A two-entry catalogue in a temp directory, with one photo file present for `puha`.
    private static func makeCatalogue() throws -> (store: CatalogueStore, directory: URL) {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let photos = directory.appending(path: CataloguePhotos.directoryName)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)

        let puha = ForageSpecies(
            id: "puha", commonName: "Pūhā", scientificName: "Sonchus oleraceus",
            category: .greens, origin: .introduced, caution: .straightforward,
            summary: "s", habitat: "h", identification: "i", edibleParts: "Leaves", preparation: "Boil",
            photos: [SpeciesPhoto(fileName: "puha-1.heic", caption: "leaf", credit: "me")]
        )
        let tutu = ForageSpecies(
            id: "tutu", commonName: "Tutu", scientificName: "Coriaria arborea",
            category: .fruit, origin: .endemic, caution: .doNotEat,
            summary: "s", habitat: "h", identification: "i",
            edibleParts: ForageSpecies.noEdibleParts, preparation: "",
            warnings: ["Lethal."], harvestEthics: "Leave it."
        )
        try Data([0]).write(to: photos.appending(path: "puha-1.heic"))

        let file = directory.appending(path: "species.json")
        try CatalogueFile.save([puha, tutu], to: file)

        let store = CatalogueStore(fileURL: file)
        store.load()
        return (store, directory)
    }

    // MARK: - Adding

    @Test("adding derives the id from the name and starts the entry as care-required")
    func addSpecies() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        let id = try store.addSpecies(commonName: "  Wild Fennel ")

        #expect(id == "wild-fennel")
        let added = try #require(store.species.first { $0.id == id })
        #expect(added.caution == .careRequired, "a new entry must never start out claiming to be safe")
        #expect(!added.isPublishable, "the blocking issues are the to-do list")
        #expect(store.editedIds.contains(id))
        #expect(store.status == .edited(count: 1))
    }

    @Test("adding keeps the list in display order")
    func addKeepsOrder() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        _ = try store.addSpecies(commonName: "Karaka")

        #expect(store.species.map(\.id) == ["karaka", "puha", "tutu"])
    }

    @Test("an empty or symbol-only name is refused")
    func addRefusesEmptyName() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(throws: CatalogueStore.AddFailure.nameEmpty) { try store.addSpecies(commonName: "   ") }
        #expect(throws: CatalogueStore.AddFailure.nameEmpty) { try store.addSpecies(commonName: "!!!") }
        #expect(store.species.count == 2)
    }

    @Test("a name that slugs to an existing id is refused, naming the clash")
    func addRefusesDuplicate() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(throws: CatalogueStore.AddFailure.duplicate(id: "puha")) {
            try store.addSpecies(commonName: "Puha")
        }
    }

    // MARK: - Editing

    @Test("editing marks the entry, and reverting it clears the mark")
    func updateTogglesEdited() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try #require(store.species.first { $0.id == "puha" })

        store.update(original.with(summary: "changed"))
        #expect(store.editedIds == ["puha"])
        #expect(store.status == .edited(count: 1))
        #expect(store.hasUnsavedChanges)

        store.update(original)
        #expect(store.editedIds.isEmpty)
        #expect(store.status == .clean)
        #expect(!store.hasUnsavedChanges)
    }

    @Test("updating an unknown id changes nothing")
    func updateUnknownIsIgnored() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }
        let ghost = try #require(store.species.first).with(commonName: "Ghost")
        let stranger = ForageSpecies(
            id: "stranger", commonName: ghost.commonName, scientificName: "",
            category: .greens, origin: .introduced, caution: .careRequired,
            summary: "", habitat: "", identification: "", edibleParts: "", preparation: ""
        )

        store.update(stranger)

        #expect(store.species.count == 2)
        #expect(store.status == .clean)
    }

    // MARK: - Deleting and photos

    @Test("deleting an entry defers its photo files until the catalogue is saved")
    func deleteDefersPhotoFiles() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = directory.appending(path: CataloguePhotos.directoryName).appending(path: "puha-1.heic")

        store.delete(id: "puha")

        #expect(!store.species.contains { $0.id == "puha" })
        #expect(FileManager.default.fileExists(atPath: photo.path), "the file must outlive an unsaved deletion")
        #expect(store.pendingPhotoDeletions.map(\.fileName) == ["puha-1.heic"])

        store.save()

        #expect(!FileManager.default.fileExists(atPath: photo.path))
        #expect(store.pendingPhotoDeletions.isEmpty)
        if case .saved = store.status {} else { Issue.record("expected .saved, got \(store.status)") }
    }

    @Test("a photo removed from an entry is deleted on save, not before")
    func removedPhotoDeletedOnSave() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }
        let puha = try #require(store.species.first { $0.id == "puha" })
        let file = directory.appending(path: CataloguePhotos.directoryName).appending(path: "puha-1.heic")

        store.update(puha.with(photos: []))
        store.schedulePhotoDeletion(puha.photos[0])
        #expect(FileManager.default.fileExists(atPath: file.path))

        store.save()

        #expect(!FileManager.default.fileExists(atPath: file.path))
        let reloaded = try CatalogueFile.load(from: store.fileURL!)
        #expect(reloaded.first { $0.id == "puha" }?.photos.isEmpty == true)
    }

    @Test("reloading discards pending deletions along with unsaved edits")
    func reloadDiscardsPending() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.delete(id: "puha")
        store.load()

        #expect(store.species.count == 2)
        #expect(store.pendingPhotoDeletions.isEmpty)
        #expect(store.status == .clean)
    }

    // MARK: - Queues

    @Test("the verification queue puts lethal claims first")
    func unverifiedOrdering() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        // Neither fixture entry has sources, so both are unverified; tutu is do-not-eat.
        #expect(store.unverified.map(\.id) == ["tutu", "puha"])
    }

    @Test("review tiers are ordered lethal, care, straightforward")
    func reviewTierOrder() {
        #expect(ReviewTier.lethalClaims < ReviewTier.careRequired)
        #expect(ReviewTier.careRequired < ReviewTier.straightforward)
        #expect(ReviewTier.allCases == [.lethalClaims, .careRequired, .straightforward])
    }

    // MARK: - Failure

    @Test("a missing catalogue is reported, not silently edited as empty")
    func missingFileFails() {
        let store = CatalogueStore(fileURL: nil)
        store.load()
        if case .failed = store.status {} else { Issue.record("expected .failed, got \(store.status)") }
        #expect(store.species.isEmpty)
    }
}
