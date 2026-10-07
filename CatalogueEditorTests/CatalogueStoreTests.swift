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
            group: .greens, origin: .introduced, caution: .straightforward,
            summary: "s", habitat: "h", identification: "i", edibleParts: "Leaves", preparation: "Boil",
            photos: [SpeciesPhoto(fileName: "puha-1.heic", caption: "leaf", credit: "me")]
        )
        let tutu = ForageSpecies(
            id: "tutu", commonName: "Tutu", scientificName: "Coriaria arborea",
            group: .fruit, origin: .endemic, caution: .doNotEat,
            summary: "s", habitat: "h", identification: "i",
            edibleParts: SourcedText(ForageSpecies.noEdibleParts), preparation: "",
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
            group: .greens, origin: .introduced, caution: .careRequired,
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

    // MARK: - Writes from outside the editor

    /// Rewrites the file underneath the store, the way `catalogue-tool` or a `git pull` would.
    private static func writeFromOutside(_ species: [ForageSpecies], to directory: URL) throws {
        try CatalogueFile.save(species, to: directory.appending(path: "species.json"))
    }

    @Test("a save is refused once someone else has written the file")
    func outsideWriteBlocksSave() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        let puha = try #require(store.species.first { $0.id == "puha" })
        store.update(puha.with(summary: "edited in the editor"))

        let tutu = try #require(store.species.first { $0.id == "tutu" })
        try Self.writeFromOutside([puha, tutu.with(summary: "written by catalogue-tool")], to: directory)

        store.save()

        #expect(store.diskChangedUnderneathUs)
        if case .failed = store.status {} else { Issue.record("expected .failed, got \(store.status)") }
    }

    @Test("an identical rewrite is not a conflict")
    func identicalRewriteIsNotAConflict() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        // Same bytes, new modification date — `catalogue-tool --normalise` on an already
        // normalised file. Detection is by content, so this must sail through.
        try Self.writeFromOutside(store.species, to: directory)
        let edited = try #require(store.species.first { $0.id == "puha" })
        store.update(edited.with(summary: "edited in the editor"))

        store.save()

        #expect(!store.diskChangedUnderneathUs)
        if case .saved = store.status {} else { Issue.record("expected .saved, got \(store.status)") }
    }

    @Test("merging keeps both sides and reports what came back from disk")
    func mergeKeepsBothSides() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        let puha = try #require(store.species.first { $0.id == "puha" })
        store.update(puha.with(summary: "mine"))

        let tutu = try #require(store.species.first { $0.id == "tutu" })
        try Self.writeFromOutside([puha, tutu.with(summary: "theirs")], to: directory)

        store.save()
        store.saveMergingDiskChanges()

        #expect(store.species.first { $0.id == "puha" }?.summary.text == "mine")
        #expect(store.species.first { $0.id == "tutu" }?.summary.text == "theirs")
        #expect(!store.hasUnsavedChanges)
        if case .merged(_, let fromDisk, let collisions) = store.status {
            #expect(fromDisk == ["tutu"])
            #expect(collisions.isEmpty)
        } else {
            Issue.record("expected .merged, got \(store.status)")
        }

        // And it is on disk, not just in memory.
        let reread = try CatalogueFile.load(from: directory.appending(path: "species.json"))
        #expect(reread.first { $0.id == "tutu" }?.summary.text == "theirs")
    }

    @Test("a merge keeps the editor's copy of an entry both sides changed, and names it")
    func mergeReportsCollisions() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }

        let tutu = try #require(store.species.first { $0.id == "tutu" })
        let puha = try #require(store.species.first { $0.id == "puha" })
        store.update(puha.with(summary: "mine"))
        try Self.writeFromOutside([puha.with(summary: "theirs"), tutu], to: directory)

        store.save()
        store.saveMergingDiskChanges()

        #expect(store.species.first { $0.id == "puha" }?.summary.text == "mine")
        if case .merged(_, _, let collisions) = store.status {
            #expect(collisions == ["puha"], "a silent overwrite is the thing this replaces")
        } else {
            Issue.record("expected .merged, got \(store.status)")
        }
    }

    @Test("a merge that brings an entry back does not delete the photo file it points at")
    func mergeKeepsPhotosOfRestoredEntries() throws {
        let (store, directory) = try Self.makeCatalogue()
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = directory
            .appending(path: CataloguePhotos.directoryName)
            .appending(path: "puha-1.heic")

        // The editor drops pūhā; meanwhile someone else edits it on disk. The merge keeps the
        // entry, so its photo file must survive the save that follows.
        let puha = try #require(store.species.first { $0.id == "puha" })
        let tutu = try #require(store.species.first { $0.id == "tutu" })
        store.delete(id: "puha")
        try Self.writeFromOutside([puha.with(summary: "theirs"), tutu], to: directory)

        store.save()
        store.saveMergingDiskChanges()

        #expect(store.species.contains { $0.id == "puha" })
        #expect(FileManager.default.fileExists(atPath: photo.path))
    }
}

/// The merge itself, away from disk: one entry at a time against the copy the editor read.
@Suite("Catalogue merge")
struct CatalogueMergeTests {
    private static func species(_ id: String, _ summary: String) -> ForageSpecies {
        ForageSpecies(
            id: id, commonName: id.capitalized, scientificName: "Genus species",
            group: .greens, origin: .introduced, caution: .careRequired,
            summary: SourcedText(summary), habitat: "h", identification: "i",
            edibleParts: "e", preparation: "p"
        )
    }

    private static let base = [species("a", "base"), species("b", "base"), species("c", "base")]
    private static var baseMap: [String: ForageSpecies] {
        Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
    }

    @Test("edits to different entries both survive")
    func disjointEdits() {
        var disk = Self.base
        disk[0] = Self.species("a", "disk")
        var editor = Self.base
        editor[1] = Self.species("b", "editor")

        let outcome = CatalogueMerge.merge(base: Self.baseMap, disk: disk, editor: editor)

        #expect(outcome.species.first { $0.id == "a" }?.summary.text == "disk")
        #expect(outcome.species.first { $0.id == "b" }?.summary.text == "editor")
        #expect(outcome.fromDisk == ["a"])
        #expect(outcome.collisions.isEmpty)
    }

    @Test("the same entry changed on both sides keeps the editor's and is reported")
    func collision() {
        var disk = Self.base
        disk[0] = Self.species("a", "disk")
        var editor = Self.base
        editor[0] = Self.species("a", "editor")

        let outcome = CatalogueMerge.merge(base: Self.baseMap, disk: disk, editor: editor)

        #expect(outcome.species.first { $0.id == "a" }?.summary.text == "editor")
        #expect(outcome.collisions == ["a"])
    }

    @Test("the same change made on both sides is not a collision")
    func identicalChange() {
        var disk = Self.base
        disk[0] = Self.species("a", "same")
        var editor = Self.base
        editor[0] = Self.species("a", "same")

        let outcome = CatalogueMerge.merge(base: Self.baseMap, disk: disk, editor: editor)

        #expect(outcome.collisions.isEmpty)
        #expect(outcome.species.first { $0.id == "a" }?.summary.text == "same")
    }

    @Test("an entry added by either side survives")
    func additions() {
        let added = Self.species("d", "new")

        let fromDisk = CatalogueMerge.merge(base: Self.baseMap, disk: Self.base + [added], editor: Self.base)
        #expect(fromDisk.species.map(\.id) == ["a", "b", "c", "d"])
        #expect(fromDisk.fromDisk == ["d"])

        let fromEditor = CatalogueMerge.merge(base: Self.baseMap, disk: Self.base, editor: Self.base + [added])
        #expect(fromEditor.species.map(\.id) == ["a", "b", "c", "d"])
        #expect(fromEditor.collisions.isEmpty)
    }

    @Test("a deletion the other side left alone is honoured")
    func deletions() {
        let withoutB = [Self.base[0], Self.base[2]]

        let editorDeleted = CatalogueMerge.merge(base: Self.baseMap, disk: Self.base, editor: withoutB)
        #expect(editorDeleted.species.map(\.id) == ["a", "c"])

        let diskDeleted = CatalogueMerge.merge(base: Self.baseMap, disk: withoutB, editor: Self.base)
        #expect(diskDeleted.species.map(\.id) == ["a", "c"])
    }

    @Test("a deletion loses to an edit on the other side, and is reported")
    func deletionVersusEdit() {
        var disk = Self.base
        disk[1] = Self.species("b", "disk")
        let editorDeletedB = [Self.base[0], Self.base[2]]

        let kept = CatalogueMerge.merge(base: Self.baseMap, disk: disk, editor: editorDeletedB)
        #expect(kept.species.map(\.id) == ["a", "b", "c"], "an entry is expensive to rewrite")
        #expect(kept.collisions == ["b"])
        #expect(kept.fromDisk == ["b"])

        var editor = Self.base
        editor[1] = Self.species("b", "editor")
        let mine = CatalogueMerge.merge(base: Self.baseMap, disk: editorDeletedB, editor: editor)
        #expect(mine.species.first { $0.id == "b" }?.summary.text == "editor")
        #expect(mine.collisions == ["b"])
    }

    @Test("merging two copies that already agree changes nothing")
    func noOp() {
        let outcome = CatalogueMerge.merge(base: Self.baseMap, disk: Self.base, editor: Self.base)

        #expect(outcome.species.map(\.id) == ["a", "b", "c"])
        #expect(outcome.fromDisk.isEmpty)
        #expect(outcome.collisions.isEmpty)
    }
}
