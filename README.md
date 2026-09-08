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
| `Packages/ForageCatalogue/` | Local SwiftPM package: the shared model (`ForageSpecies`, `ForageMonth`, `ForageCategory`/`ForageOrigin`, `CautionLevel`, `Lookalike`, `Recipe`), `CatalogueFile` for load/save, `SpeciesValidation` for the shared rules, `CatalogueLocator`, and the `catalogue-tool` CLI. Depended on by every target. |
| `CatalogueEditor/` | macOS editor app target — its own scheme in the project. |
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

`species.json` is edited with the **CatalogueEditor** scheme — a macOS app target in
`ForageNZ.xcodeproj`. Open the project, pick the scheme, ⌘R. It edits the repo's
`species.json` in place; there is no import or export step.

It finds the catalogue via a compile-time source anchor (`#filePath` at the call site),
because an app bundle launched from Xcode has neither a working directory nor a bundle path
inside the repo. That's fine for a developer tool and wrong for anything shipped — see
`CatalogueLocator`.

The entry is split into four tabs — **Entry**, **Photos**, **Safety**, **Sources** — each
labelled with its own count of unfilled required fields, e.g. "Entry (5)". A single scrolling
form buried the photo importer ten sections down.

In the app: ⌘N adds a species, ⌘S saves. Nothing is written until you save; the sidebar
marks unsaved entries and flags incomplete ones. Entries are grouped by verification
priority, lethal claims first.

Headless maintenance lives in the package instead, so it can run without a window:

```sh
cd Packages/ForageCatalogue
swift run catalogue-tool --normalise   # rewrite species.json in canonical form
swift run catalogue-tool --check       # list blocking issues, non-zero exit if any
```

**Formatting is load-bearing.** `CatalogueFileTests` asserts that re-encoding `species.json`
is byte-identical to what's on disk, so a save is a one-entry diff rather than a whole-file
reformat. Foundation's `prettyPrinted` writes `"key" : value` (with a space before the colon),
which is *not* what most formatters produce — after hand-editing the file, run `--normalise`.

## Photos

Each entry wants around four identification photos: whole plant, leaf or frond detail, the
diagnostic feature, and whatever it gets confused with. Plus `moreImagesURL` pointing at a
page with more — an iNaturalist taxon page is usually best, since licences are stated there.

They ship inside the app, so size is a constraint rather than an afterthought:

| | |
|---|---|
| Format | HEIC, quality 0.62 |
| Longest edge | 1400 px |
| Per photo | ≤ 215 KB |
| Whole catalogue | ≤ 24 MB |

**Lossless is not an option.** A lossless PNG of a photograph at this size is 1.5–3 MB, so
four per species would be 190–370 MB embedded. HEIC at 0.62 is visually indistinguishable
for identification and roughly 30× smaller. Every number above is a constant in
`CataloguePhotos`, so retune it in one place.

Import through the editor — it downscales and re-encodes on the way in, so an untouched 6 MB
phone photo can't land in the repo. `PhotoAuditTests` fails the build on a missing file, an
oversized file, an orphaned file, or a photo with no caption or credit.

```sh
swift run catalogue-tool --photos   # budget used, missing files, orphans, thin entries
```

`CatalogueEditorUITests` drives the real window: every tab reachable, the photo importer one
click from the Photos tab, prose fields accepting typed text, and the derived identifier
shown before a new species is committed. **macOS gates UI testing behind a one-time system
authentication prompt**, so run it yourself the first time (⌘U in Xcode, or
`xcodebuild test -scheme CatalogueEditor -destination 'platform=macOS'`) and approve the
prompt.

A caption is required because "the stem base" is the entire reason a photo helps, and a
credit is required because CC BY obliges it — the app displays both.

## Validation

Per-entry rules live in `ForageSpecies.validationIssues`, split into blocking (fails the
build) and advisory. The editor shows them at the top of each entry, and `CatalogueTests`
enforces the same rules — one definition, so the tool and the build can't disagree.

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
# the iOS app
xcodebuild build -project ForageNZ.xcodeproj -scheme ForageNZ \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify -q
xcodebuild test  -project ForageNZ.xcodeproj -scheme ForageNZ \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify -q

# the macOS editor
xcodebuild build -project ForageNZ.xcodeproj -scheme CatalogueEditor -destination 'platform=macOS'

# the shared package
cd Packages/ForageCatalogue && swift test
```

Use **iPhone 17** for the iOS scheme: the iPhone 16 family is only installed on iOS 18.x
runtimes here, and `xcodebuild` defaults to `OS:latest`, so those names fail to resolve.
Confirm with `xcodebuild -showdestinations` if the device list drifts.

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
