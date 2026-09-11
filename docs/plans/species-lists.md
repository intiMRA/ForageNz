# Plan: user lists — "Favourites", "Found", "Wanted", …

**Status:** planned, not started. Written 11/09/2026. Nothing in the app depends on this yet.

## Goal

Let the user keep named lists of species — some shipped ("Favourites", "Found"), some their own
("Wanted", "Near the bach") — and see membership on the rows and pages they already use. The
catalogue stays exactly as it is: read-only, bundled JSON, checked at build time. Lists are the
first **mutable, per-user** data in the app, and they get their own store.

## Why SwiftData, and why not for the catalogue

Lists are relational user data: a list has many entries, a species can sit in several lists, and
each membership may carry its own facts (when, where, a note). That is SwiftData's brief. The
catalogue is 58 read-only entries versioned in git, diffed in PRs, generated into `SpeciesID`,
and edited by a macOS tool and Python scripts — none of which survives moving it into an opaque
SQLite store. Two kinds of data, two stores. See the README section *Species are compile-time
values* for what the catalogue side guarantees.

## Model

```swift
/// Which shipped list this is, if any. Identity by kind, not by name, so renaming "Favourites"
/// to "Keepers" does not lose the heart badge.
enum BuiltInList: String, Codable { case favourites, found }

@Model final class SpeciesList {
    /// Our own stable id, crossing the repository boundary in snapshots. Not `@Attribute(.unique)`
    /// — unique constraints are incompatible with CloudKit.
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = .now
    var builtIn: BuiltInList? = nil
    @Relationship(deleteRule: .cascade, inverse: \ListEntry.list) var entries: [ListEntry]? = []
}

@Model final class ListEntry {
    var id: UUID = UUID()
    /// Stored as the raw string, NOT as `SpeciesID`. If the enum were the attribute type, removing
    /// a species from the catalogue would make every fetch that touches an old row fail to decode
    /// — a crash on launch for anyone who had listed it. As a string the row still loads, and
    /// `speciesID` (below) is `nil` for it, which the UI shows as "no longer in the guide" and
    /// offers to remove. Writes still go through `SpeciesID`, so a new entry can never name a
    /// species the catalogue lacks.
    var speciesIDRaw: String = ""
    var addedAt: Date = .now
    var note: String? = nil
    /// Where it was found, if the user chose to record it. The Where-you-are location code and
    /// its permission string already exist; this is opt-in per entry, never automatic.
    var latitude: Double? = nil
    var longitude: Double? = nil
    var list: SpeciesList? = nil

    var speciesID: SpeciesID? { SpeciesID(rawValue: speciesIDRaw) }
}
```

Every property has a default and every relationship is optional: that is the CloudKit-compatible
shape, and it costs nothing to adopt now even if sync is never turned on. Adding columns later is
a migration; the location fields are in from the start for that reason.

## Boundaries (per the harness standard: protocol at every seam, factories return models)

```swift
protocol SpeciesListsRepository: Sendable {
    func lists() async throws(SpeciesListsError) -> [SpeciesListSnapshot]
    func createList(named: String) async throws(SpeciesListsError) -> SpeciesListSnapshot
    func rename(_ list: SpeciesListSnapshot.ID, to name: String) async throws(SpeciesListsError)
    func delete(_ list: SpeciesListSnapshot.ID) async throws(SpeciesListsError)
    func add(_ species: SpeciesID, to list: SpeciesListSnapshot.ID, note: String?) async throws(SpeciesListsError)
    func remove(_ species: SpeciesID, from list: SpeciesListSnapshot.ID) async throws(SpeciesListsError)
}
```

- `SwiftDataSpeciesListsRepository` — the real conformance, a `@ModelActor` actor owning its
  `ModelContext` (contexts are not `Sendable`; the actor is what makes the async protocol honest).
  If the `ModelContainer` cannot be created — corrupt store, full disk — the app reports "lists
  unavailable" and disables the feature for the session. It never crashes on launch over user
  data, and it never touches the catalogue.
- `InMemorySpeciesListsRepository` — tests and previews. No SwiftData in a unit test.
- Snapshots (`SpeciesListSnapshot`, `ListEntrySnapshot`) are `Sendable` value types crossing the
  boundary; `@Model` classes never leave the repository. That keeps views and the factory free of
  actor questions, exactly as `ForageSpecies` does today.
- `SpeciesListsError` is a typed error (`throws(SpeciesListsError)`), with `userMessage`.
- A `@Observable @MainActor` `ListsViewModel` owns what the screens show (same split as
  `SpeciesStore` / `BundledSpeciesRepository`: actor-ish repository does the work, main-actor
  observable holds UI state).

`SpeciesModelFactory` grows: `ListingRowModel` gains `memberships: [ListBadge]` so a row can show
which lists it is in; new `ListRowModel` / `ListDetailModel` for the lists screens. The factory
takes the lists snapshot as input the same way it takes the store — it stays a pure mapping.

## UI

- A fourth tab, **Lists**: the lists, each with a count; tap → the species in it via
  `SpeciesRowLink` (so navigation stays the one route). Swipe to remove; "+" to create.
- On `SpeciesDetailView`: an "Add to list…" control offering every list with a tick for current
  membership. Built-in lists first.
- On rows: small badges for membership (heart for Favourites, tick for Found; text for custom
  lists). Badges come from `ListingRowModel`, not from the view querying anything.
- Editor: none. Lists are user data and never enter the catalogue or the repo.

## Tests

- `InMemorySpeciesListsRepository` drives `ListsViewModel` tests: create/rename/delete, add/remove,
  built-ins cannot be deleted, duplicate names refused, membership reflected in factory models.
- A SwiftData integration test against an in-memory `ModelConfiguration(isStoredInMemoryOnly: true)`
  for the real repository: cascade delete removes entries; a `SpeciesID` round-trips.
- An entry whose `speciesIDRaw` has no `SpeciesID` case (species removed from the catalogue after
  it was listed) loads, is flagged in its snapshot, appears in the UI as "no longer in the guide",
  and can be removed — never silently deleted, never a crash. Test it by inserting a row with a
  made-up raw id into the in-memory store.
- UI test: add dandelion to Favourites, relaunch, see it in the Lists tab.

## Open decisions (decide before starting)

1. **Built-in lists** — ship "Favourites" and "Found" pre-created? Deletable? Renamable? Leaning:
   pre-created on first launch, not deletable, renamable (identity is `builtIn`, not the name).
2. **CloudKit sync** — lists following the user between devices. The models above are already in
   the shape CloudKit requires (defaults everywhere, optional relationships, no unique
   constraints), so this is a container-configuration switch plus an entitlement, not a
   remodel. Still decide up front: sync changes how conflicts and deletions behave.
3. **"Found" as a log** — if yes, add location (and optionally a photo reference) to `ListEntry`
   from the start, and the Where-you-are location code becomes reusable here.
4. **Tab or sheet** — a fourth tab is discoverable; a sheet from the detail page is lighter. The
   badges on rows matter more than where the lists live.

## Steps, when it starts

1. Decide the four items above.
2. Package: `SpeciesListSnapshot`, `ListEntrySnapshot`, `SpeciesListsError`,
   `SpeciesListsRepository` protocol + `InMemorySpeciesListsRepository` (all in `ForageCatalogue`,
   no SwiftData dependency there).
3. App: `SwiftDataSpeciesListsRepository`, `ModelContainer` in `ForageNZApp`, `ListsViewModel`.
4. Factory: extend `ListingRowModel`; add list models; inject the lists snapshot.
5. UI: Lists tab, detail-page control, row badges.
6. Tests as above; both reviewers; README section; remove this file or mark it done.

## Not in scope

Sharing lists, importing/exporting, anything server-side, and any change to how the catalogue is
stored.
