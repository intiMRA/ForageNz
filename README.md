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
| `ForageNZ/WhereYouAre/` | Offline land-status lookup: the bundled DOC raster, a one-shot location fix, and the Safety-tab section that reports it. |
| `ForageNZ/Components/` | Shared UI: `SpeciesRow`, `CautionBadge`, `CautionPalette`, `Layout`. |
| `ForageNZTests/` | Swift Testing: store filtering and shipped-catalogue integrity. |
| `ForageNZUITests/` | XCUITest: tab navigation, origin filtering end-to-end, species detail, safety list. |

Grouped by feature rather than by layer, matching the other apps in this folder.

## Python tooling

The tools in `Tools/` are Python. They need 3.11+ (`StrEnum`), and the system `python3` on
this machine is 3.8 — use the virtualenv:

```sh
python3.13 -m venv .venv
.venv/bin/pip install -e ".[dev]"

.venv/bin/mypy          # the verify gate: strict, must be clean
.venv/bin/ruff check Tools/
.venv/bin/ruff format Tools/
```

**In PyCharm:** open the repo root as the project, set the interpreter to `.venv/bin/python`
(Settings → Project → Python Interpreter → Add → Existing). Five run configurations are
committed in `.idea/runConfigurations/` and appear in the run dropdown (six of them):

| Configuration | Does |
|---|---|
| Enrich catalogue (dry run) | Reports fills, suggestions and disagreements. Changes nothing |
| Enrich catalogue (write) | Applies the fills, then normalises |
| Stage photos for review | Downloads CC-licensed candidates to `.staged-photos/` |
| Fetch eval photos | Evaluation set for the matcher harness |
| Fetch eval photos (out-of-catalogue) | The negative set, for open-set testing |
| Build land status map | Rebuilds the bundled DOC conservation / marine reserve raster |

Each sets the working directory to the repo root — every tool resolves paths from there.

Two runtime dependencies. `certifi`, because Homebrew Python ships without the macOS trust
store wired up: without it HTTPS fails with `CERTIFICATE_VERIFY_FAILED`, and disabling
verification instead would not be acceptable when fetching into a safety-critical dataset.
`pillow`, to rasterise the DOC boundaries into the land-status map.

## Enriching the catalogue from external sources

`Tools/enrich_catalogue.py` fills gaps from NZOR and iNaturalist. **It never overwrites
anything you wrote.**

```sh
python3 Tools/enrich_catalogue.py                 # dry run: reports, changes nothing
python3 Tools/enrich_catalogue.py --write         # applies the fills, then normalises
python3 Tools/enrich_catalogue.py --stage-photos  # CC0/CC-BY candidates, staged not attached
```

It is not a discovery tool either. It iterates the species already in the catalogue and
looks each one up by the scientific name you wrote, so it cannot introduce a species you
have not vetted — a guard aborts the write if the entry set changes. No source it queries
knows what is edible: iNaturalist, NZOR and GBIF carry taxonomy, distribution and
conservation status, not edibility. Deciding something is foragable stays editorial.

Three categories, and the split is the point:

| | Fields | Behaviour |
|---|---|---|
| **Fills when empty** | `moreImagesURL` | Matter of record — an iNaturalist taxon id |
| **Never writes** | `identification`, `warnings`, `lookalikes`, `preparation`, `edibleParts`, `harvestEthics`, `sources`, `recipes`, `caution`, `summary`, `habitat`, `maoriName` | Judgement or safety-critical. From your books, never a script |
| **Reports only** | `scientificName`, `origin`, `months`, conservation status, te reo suggestions | A disagreement is a decision for you |

"Empty" means absent or the empty string, never whitespace — the rule that this script never
overwrites is kept total, because an exception for "looks blank enough" is one somebody has
to remember. A whitespace-only field is reported instead, so a stray space cannot silently
block enrichment. `Tools/tests/` exists to make that invariant fail loudly if it breaks.

### What it reads from iNaturalist

- **`establishment_means`** for the New Zealand place: `endemic` / `native` / `introduced`.
  Finer than the catalogue's `native`, and an endemic species is a stronger reason to
  harvest sparingly than "native" alone conveys — so it suggests saying so.
- **`conservation_status`** — flagged loudly, because presenting a threatened species as
  foragable is a different kind of mistake.
- **Seasonality**: research-grade NZ observations per month. Reported only, and only when
  the observed peak is *narrower* than what the entry claims. Observation counts are not a
  harvest window — a perennial like kawakawa is photographed year-round regardless of when
  its leaves are worth picking, so an all-year peak says nothing and is suppressed.

Dry run is the default, because this touches safety-critical data.

**Why `maoriName` is not auto-filled:** iNaturalist's `preferred_common_name` is
locale-dependent and defaults to English — asked for te reo names it offered "Persian
walnut", "King Bolete" and "garden nasturtium". `locale=mi` is far too patchy, returning
nothing for kawakawa or horopito, whose te reo names *are* their common names. Candidates it
does find are printed as suggestions.

**Photos are staged, never attached.** A photo needs a caption naming the feature it shows,
which is a human judgement; attach and caption them in the editor.

What it found on first run: 26 entries gained an iNaturalist link, and NZOR disagrees with
one name — it accepts **`Feijoa sellowiana`** where the catalogue says `Acca sellowiana`.

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

**There is no signal where this app gets used.** That is the constraint everything else
follows from: the embedded photos are all a forager will ever have, so they carry the whole
identification load. `moreImagesURL` is a planning aid for before you leave — the app labels
it as needing a connection, and `CatalogueTests` asserts no entry depends on it for anything
needed in the field.

The photo target scales with how badly a mistake ends: **four** normally, **six** for
anything with a deadly lookalike, since those are the calls where a forager most needs
another angle and can least afford to guess.

They ship inside the app, so size is a constraint rather than an afterthought:

| | |
|---|---|
| Format | HEIC, quality 0.62 |
| Longest edge | 1400 px |
| Per photo | ≤ 215 KB |
| Target per entry | 4, or 6 with a deadly lookalike |
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

## Photo matching — measured, then removed from the app

There is no photo matcher in the app. It was built, measured, and taken out. The package
code and the evaluation harness remain, because the measurement is the useful artifact and
the basis for retrying with a better model.

**Why it was removed: it cannot refuse.** Nearest-neighbour ranking always returns the
closest catalogue entries, however far away they are. For a foraging guide that is not a
quality problem, it is a safety one — the dangerous case is photographing something that
isn't in the guide at all.

`catalogue-tool --openset` measures whether a distance threshold could tell "in the
catalogue" from "not in the catalogue", using 112 photos of 14 catalogue species against 48
photos of six NZ plants deliberately left out (foxglove, hemlock, ragwort, agapanthus, arum
lily, buttercup):

```
in catalogue      n=112  min 0.27  p10 0.41  median 0.54  p90 0.72  max 0.82
NOT in catalogue  n=48   min 0.47  p10 0.52  median 0.66  p90 0.88  max 1.00

Best threshold 0.64: accepts 84% of known, rejects 58% of unknown
```

The distributions overlap almost entirely. The best achievable threshold still hands a
shortlist to **42% of plants that are not in the guide**. Photograph hemlock and there is a
good chance it points at wild fennel — the exact fatal confusion the guide exists to
prevent.

Closed-set accuracy was respectable (`--evaluate`: top-1 78.6%, top-3 94.6% over the same
112 photos), and irrelevant next to the above. A matcher that is usually right about species
it knows, and confidently wrong about everything else, is worse than no matcher.

**What would change the decision:** a plant-specific backbone (PlantCLEF DINOv2) with wide
enough margins that in-catalogue and unknown distances separate. `--openset` is the test it
would have to pass first — and rejecting unknowns matters more than closed-set accuracy.

```sh
python3 Tools/fetch_eval_photos.py                                  # CC0/CC-BY, gitignored
python3 Tools/fetch_eval_photos.py --set out-of-catalogue --out .eval-photos-negative
swift run catalogue-tool --evaluate ../../.eval-photos
swift run catalogue-tool --openset ../../.eval-photos ../../.eval-photos-negative
```

## Where you are — the offline land-status map

The guide says pikopiko needs a DOC permit and that karengo beds may sit inside a marine
reserve. It could not say whether *you* were standing in one. `Tools/build_land_status.py`
bakes DOC's two public layers into a bitmap small enough to ship:

```bash
python3 Tools/build_land_status.py                  # fetch, rasterise, verify, report size
python3 Tools/build_land_status.py --degrees 0.005  # coarser grid, smaller file
```

It writes `ForageNZ/Catalogue/land-status.png` (**237 KB** for the whole country, ~2% of the
photo budget) plus `land-status.json` describing the grid. `LandStatusMap` in the package
reads them and answers a coordinate in constant time, entirely offline.

Deliberate trade-offs:

- **A raster, not polygons.** Generalised GeoJSON was ~3.4 MB and needed point-in-polygon over
  11,000 shapes. One pixel read is simpler and honestly approximate.
- **~280 m per pixel.** Enough to say "stop and check", not enough to place a boundary.
- **Two bits per pixel in memory.** The decoded 8-bit form is ~29 MB; packed it is ~7 MB.
- **Holes are not modelled**, so it over-reports conservation land. That is the safe direction.
- **Never green.** `LandStatus.tintColor` has no `cautionSafe` case: the map knows two
  restrictions and nothing about private land, rāhui or council bylaws, so no state of the UI
  says yes. The Safety section's wording is hedged in every branch, on purpose.
- **A wrong map fails loudly.** Xcode re-encodes bundled PNGs and ImageIO colour-matches on
  decode; either could re-map values or flip an axis, and an upside-down map answers every
  query confidently and wrongly. `LandStatusMap.groundTruth` holds four places whose status is
  not in doubt, the Python builder checks them after rasterising, the Swift tests check them
  against the shipped file, and `BundledLandStatusRepository` refuses to serve a map that
  fails them.

Location is taken once, on request, and never leaves the device.

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

`NetworkLayerSPM` is deliberately **not** a dependency — v1 makes no network calls. That still
holds with the land-status map: the boundaries ship in the bundle and `CoreLocation` reads the
GPS, so the whole feature works with the radio off.

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
- **No live overlays.** Rāhui, MPI biotoxin warnings and LAWA algal-bloom status are all
  referenced in warning copy but not yet fetched. Rāhui in particular should not be aggregated
  without mana whenua involvement. DOC land and marine reserves are now embedded (see
  *Where you are*), but as a static snapshot — boundaries change and the map does not.
- **Seaweed and shellfish are under-served.** The catalogue lists seaweed but the biotoxin
  warning is static text; it should be a live MPI feed.

## Disclaimer

This app is an aid to learning, not an identification service. Nothing in it should be treated
as confirmation that something is safe to eat. National Poisons Centre: **0800 764 766**.
