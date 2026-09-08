# ForageNZ

An offline field guide to wild food in Aotearoa — what's in season, how to identify it,
and, just as importantly, what will hurt you.

## Why it's shaped this way

**Offline first.** Foraging happens in gullies and on coastlines with no signal, so the
catalogue ships in the app bundle rather than being fetched. `SpeciesRepository` is a
protocol with a bundled implementation; a remote-refresh implementation can be added behind
it later without touching callers.

**It never claims to identify anything.** The app describes what to check — it does not tell
you what a plant is. Every entry that has a dangerous lookalike carries a field-checkable
difference (`Lookalike.howToTell`), not a general warning. Species that exist only to be
avoided (tutu, death cap, karaka) are first-class entries with `caution: doNotEat`, so the
guide teaches avoidance rather than only collection.

**Safety data is tested, not just written.** `CatalogueTests` fails the build if a deadly
lookalike is marked straightforward, a do-not-eat entry lists edible parts, a lookalike has
no distinguishing check, or a native species ships without harvesting guidance.

## Structure

| Path | What's in it |
|---|---|
| `Packages/ForageCatalogue/` | Local SwiftPM package. `Sources/ForageCatalogue` is the shared model — `ForageSpecies`, `ForageMonth`, `ForageCategory`/`ForageOrigin`, `CautionLevel`, `Lookalike`, `Recipe` — plus `CatalogueFile` for reading and writing `species.json`. `Sources/CatalogueEditor` is the macOS editor. |
| `ForageNZ/ForageNZApp.swift`, `RootView.swift` | App entry and the tab shell, which owns catalogue loading. |
| `ForageNZ/Catalogue/` | `species.json`, `SpeciesRepository` (protocol + bundled actor), `SpeciesStore` (`@Observable @MainActor`). |
| `ForageNZ/InSeason/` | What's worth looking for this month. |
| `ForageNZ/FieldGuide/` | Searchable catalogue with category + origin filters, and the species detail screen. |
| `ForageNZ/Safety/` | Ground rules, the do-not-eat list, and species with deadly lookalikes. |
| `ForageNZ/Components/` | Shared UI: `SpeciesRow`, `CautionBadge`, `CautionPalette`, `Layout`. |
| `ForageNZTests/` | Swift Testing: store filtering and shipped-catalogue integrity. |
| `ForageNZUITests/` | XCUITest: tab navigation, origin filtering end-to-end, species detail, safety list. |

Grouped by feature rather than by layer, matching the other apps in this folder.

## Editing the catalogue

`species.json` is edited with the macOS editor, which goes through the same `ForageSpecies`
type the app decodes — so it cannot write JSON the app can't read.

```sh
cd Packages/ForageCatalogue
swift run CatalogueEditor              # opens the editor on the repo's species.json
swift run CatalogueEditor --normalise  # rewrite in canonical form, no window
```

Entries are grouped by verification priority: lethal claims first (do-not-eat entries and
anything with a deadly lookalike), then care-required, then the rest. `--catalogue <path>`
points it at a different file.

**Formatting is load-bearing.** `CatalogueFileTests` asserts that re-encoding `species.json`
is byte-identical to what's on disk, so a save is a one-entry diff rather than a whole-file
reformat. Foundation's `prettyPrinted` writes `"key" : value` (with a space before the colon),
which is *not* what most formatters produce — after hand-editing the file, run `--normalise`.

## Verification status

Every entry carries `sources`. Entries with none are unverified, and
`CatalogueTests.pendingVerification` lists them: a new entry with no sources fails the build
unless declared there, and an id left on the list after being sourced also fails — so the list
can only shrink. The detail screen shows a "Not yet checked" banner until an entry is sourced.

## Dependencies

`DesignLibrary` (`github.com/intiMRA/Desing-Library-SPM`, branch `main`) for `CommonPadding`
spacing tokens. It ships no typography or public colour tokens, so text uses SwiftUI semantic
Dynamic Type styles and the caution palette is defined as asset-catalog colour sets
(`cautionSafe` / `cautionCare` / `cautionDanger`).

`NetworkLayerSPM` is deliberately **not** a dependency — v1 makes no network calls.

## Building

```sh
xcodebuild build -project ForageNZ.xcodeproj -scheme ForageNZ \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify -q
xcodebuild test  -project ForageNZ.xcodeproj -scheme ForageNZ \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify -q
```

Use **iPhone 17**: the iPhone 16 family is only installed on iOS 18.x runtimes here, and
`xcodebuild` defaults to `OS:latest`, so those names fail to resolve. Confirm with
`xcodebuild -showdestinations` if the device list drifts.

`Package.resolved` is committed: `DesignLibrary` is branch-pinned with no tags, so it is the
only record of the revision this app was built against.

## Catalogue data

`species.json` is hand-authored. Adding an entry means satisfying `CatalogueTests`, which is
the point: the schema encodes the safety rules.

Known gaps, in rough priority order:

- **No photographs.** A field guide without images is half a guide. Licensing is the blocker —
  iNaturalist research-grade observations carry CC0/CC-BY/CC-BY-NC photos and are the obvious
  source.
- **No location awareness.** Several entries are regional (cherry guava is northern, rosehip is
  dry-eastern). Region filtering needs a region field on each entry.
- **No live overlays.** Rāhui, DOC land boundaries, MPI biotoxin warnings and LAWA algal-bloom
  status are all referenced in warning copy but not yet fetched. Rāhui in particular should not
  be aggregated without mana whenua involvement.
- **Seaweed and shellfish are under-served.** The catalogue lists seaweed but the biotoxin
  warning is static text; it should be a live MPI feed.

## Disclaimer

This app is an aid to learning, not an identification service. Nothing in it should be treated
as confirmation that something is safe to eat. National Poisons Centre: **0800 764 766**.
