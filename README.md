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
| `ForageNZ/Catalogue/Model/` | The shared model (`ForageSpecies`, `ForageMonth`, `ForageGroup`/`ForageOrigin`, `Habitat`, `CautionLevel`, `Lookalike`, `Recipe`), `CatalogueFile` for load/save, `SpeciesValidation` for the shared rules, `PhotoImporter`, `LandStatusMap` and `CatalogueLocator`. Not a package — plain source files, compiled into both ForageNZ and CatalogueEditor. That is what lets the labels reach the String Catalog and the artwork reach the asset catalog; a package is a separate bundle and can do neither. |
| `Package.swift`, `Tools/Catalogue/` | The command-line side, and the only thing that still needs a manifest. It points a target at `ForageNZ/Catalogue/Model` so `catalogue-tool` builds with `swift build` and the model tests run in ~2s with `swift test`, no simulator. Nothing in the app depends on it. `Tools/Catalogue/Tooling` holds the photo-matcher measurement code (Vision), linked only by the CLI, so the app never carries it. |
| `CatalogueEditor/` | macOS editor app target — its own scheme in the project. Compiles the catalogue model plus the app's `Layout`, `CautionPalette` and `CatalogueArtwork`, so the two UIs share one set of layout values, one caution colour mapping and one set of classification drawings. |
| `ForageNZ/Components/CatalogueArtwork.swift` | Classification to drawing, the counterpart of `CautionPalette` for colour. App-side because it uses the `ImageResource` symbols Xcode generates from `SharedResources/Catalogue.xcassets`, which do not exist in a SwiftPM build — keep it out of `Catalogue/Model/` or `swift build` breaks. |
| `CatalogueEditorTests/` | Swift Testing against the editor's store: adding, editing, deleting, and the rule that a removed photo's file is deleted on save, not before. |
| `ForageNZ/ForageNZApp.swift`, `RootView.swift` | App entry and the tab shell, which owns catalogue loading. |
| `ForageNZ/Catalogue/` | `species.json`, `SpeciesRepository` (protocol + bundled actor), `SpeciesStore` (`@Observable @MainActor`). |
| `ForageNZ/InSeason/` | What's worth looking for this month. |
| `ForageNZ/FieldGuide/` | Searchable catalogue with group + origin filters, and the species detail screen. |
| `ForageNZ/Safety/` | Ground rules, the do-not-eat list, and species with deadly lookalikes. |
| `ForageNZ/WhereYouAre/` | Offline land-status lookup: the bundled DOC raster, a one-shot location fix, and the Safety-tab section that reports it. |
| `ForageNZ/Components/` | Shared UI: `SpeciesRow`, `SpeciesRowButton`, `CautionBadge`, `CautionPalette`, `HabitatChips`, `Layout`, and `Colors.xcassets` — the three caution colours live here rather than in the app's asset catalog so the editor can compile them as well. |
| `ForageNZ/Navigation/` | `Destination`, the `@CasePathable` enum of everywhere a screen can go, and `Router`, which owns one stack's `path`. There is a router per tab, injected into that tab's subtree. Screens never hold a `NavigationLink` — a row is a `Button` that calls `router.push(.species(id))`, so the route is state something can read and drive. |
| `ForageNZ/Dependencies/` | The `DependencyKey`s for the repositories, the location provider and the clock. App-side only: `Catalogue/Model/` is also built by `Package.swift`, which does not have these packages. |
| `ForageNZ/SharedResources/` | `Assets.xcassets` and `Catalogue.xcassets` — the 20 classification drawings (habitat ×8, group ×6, biostatus ×3, lookalike ×3), members of **both** app targets. Image sets are flat, not folder-namespaced, so the generated symbol is `Image(.shore)`: rename a set and the build breaks, which is the point. |
| `ForageNZ/Resources/` | `Localizable.xcstrings`, the iOS app's String Catalog. |
| `ForageNZTests/` | Swift Testing: store filtering and shipped-catalogue integrity. |
| `ForageNZUITests/` | XCUITest: tab navigation, origin filtering end-to-end, species detail, safety list. |

Grouped by feature rather than by layer, matching the other apps in this folder.

## The tooling

Two kinds. `catalogue-tool` is Swift and owns everything that **writes `species.json`'s
shape**; the `Tools/*.py` scripts are Python and own everything that **reaches the network**
or **derives a field from text**. The division matters: the canonical writer of `species.json`
is Swift, so any Python tool that writes must be followed by a normalise pass.

### Setup

Every tool resolves paths from the repo root — run them from there. Python needs 3.11+
(`StrEnum`) and the system `python3` here is 3.8, so use the virtualenv:

```sh
python3.13 -m venv .venv
.venv/bin/pip install -e ".[dev]"
```

Commands below say `.venv/bin/python`; substitute `python3` if yours is already 3.11+.

Two runtime dependencies. `certifi`, because Homebrew Python ships without the macOS trust
store wired up: without it HTTPS fails with `CERTIFICATE_VERIFY_FAILED`, and disabling
verification instead would not be acceptable when fetching into a safety-critical dataset.
`pillow`, to rasterise the DOC boundaries into the land-status map.

### `catalogue-tool` — the Swift CLI

Headless catalogue maintenance, so formatting and checking can run without a window. Run from
the repo root; `swift build` has no simulator to wait for.

| Command | Does |
|---|---|
| `swift run catalogue-tool --normalise` | Rewrite `species.json` in canonical form and regenerate `SpeciesID`. **Run after every Python tool that writes** |
| `swift run catalogue-tool --check` | List blocking validation issues; non-zero exit if any |
| `swift run catalogue-tool --photos` | Photo audit: byte budget, missing files, orphans, entries under their target |
| `swift run catalogue-tool --attach <manifest.json>` | Attach staged photos that have a caption written; skip the rest |
| `swift run catalogue-tool --index` | Vision feature-print index; reports within-species spread and unreadable files |
| `swift run catalogue-tool --evaluate <dir>` | Closed-set matcher accuracy over a labelled photo directory |
| `swift run catalogue-tool --openset <in-dir> <out-dir>` | Can a distance threshold reject species not in the catalogue? |

`--catalogue <path>` overrides the located `species.json` for any of them.

### The Python tools

Anything that touches `species.json`'s **prose or classification** reports by default and needs
`--write`, because that is safety-critical data. The rest — the description fetcher, the two
photo/raster builders, the catalog sync — writes on a plain run. The **Writes** column below is
the authority; check it before you run something.

| Tool | Does | Writes | Network |
|---|---|---|---|
| `enrich_catalogue.py` | Fill `moreImagesURL` from iNaturalist; report name, origin, season and te reo disagreements; stage CC-licensed photo candidates | `--write` | NZOR, iNaturalist |
| `validate_candidates.py` | Prove a scraped name is a real organism recorded in NZ before it can become an entry | to `--out`, never the catalogue | NZOR, iNaturalist |
| `import_book_stubs.py` | Turn a book index into draft entries — names, months, origin, group, citation, blank prose | unless `--dry-run` | NZOR (skip with `--no-nzor`) |
| `fetch_descriptions.py` | Copy description and habitat prose from Wikipedia (CC BY-SA), falling back to Flora of NZ (CC BY) | **on a plain run**; `--dry-run` to preview | Wikipedia, Flora of NZ |
| `metricate.py` | Convert imperial in copied text to metric, adding the change to each credit | `--write` | — |
| `classify_habitats.py` | Derive `habitats` labels from each entry's own habitat prose; `--review` writes the evidence sheet | `--write` | — |
| `find_sources.py` | Fetch candidate pages, require each to name the species, then cite it | `--write` | NZPCN, NZOR |
| `audit_names.py` | Check every scientific name against NZOR: real, current, recorded here | never | NZOR |
| `build_land_status.py` | Rasterise DOC's conservation and marine-reserve layers into the shipped bitmap | on a plain run | DOC ArcGIS |
| `fetch_eval_photos.py` | Download openly licensed photos into a gitignored matcher evaluation set | on a plain run | iNaturalist |
| `sync_string_catalog.py` | Merge a terminal build's extracted strings into `Localizable.xcstrings` | on a plain run | — |
| `check_target_membership.py` | Fail if a model source is not compiled by both app targets | never | — |

`Tools/sources.py` is a library, not a script: one definition of each endpoint, licence code
and request convention, so two scripts cannot drift on what "an acceptable licence" means.

Flags worth knowing:

| Flag | On | Does |
|---|---|---|
| `--only a,b,c` | enrich, fetch_descriptions, find_sources | Limit to those species ids |
| `--all` | fetch_descriptions | Also fill blanks on finished entries, not only drafts |
| `--drafts-only` | audit_names | Skip the shipped entries |
| `--review [path]` | classify_habitats | Evidence sheet, default `docs/habitat-review.md` |
| `--stage-photos` | enrich | Candidates → `.staged-photos/<id>/`, with `--photos-per-species` |
| `--name-records` | find_sources | Also cite NZOR *name* records. See step 9 for why this is off |
| `--no-nzor` | import_book_stubs | Skip the origin lookup, for offline runs |
| `--degrees 0.005` | build_land_status | Coarser grid, smaller file |
| `--set out-of-catalogue` | fetch_eval_photos | The negative set, for `--openset` |
| `--limit N` | validate_candidates | Stop after N candidates |
| `--catalogue <path>` | audit_names, classify_habitats, fetch_descriptions, find_sources, import_book_stubs, metricate | Point at a catalogue other than the located one |

### Recipes

```sh
# after hand-editing species.json, always
swift run catalogue-tool --normalise && swift run catalogue-tool --check

# is the catalogue sound? — the full gate
.venv/bin/python -m pytest -q && .venv/bin/ruff check Tools && .venv/bin/mypy
swift test
.venv/bin/python Tools/check_target_membership.py
xcodebuild test -project ForageNZ.xcodeproj -scheme ForageNZ \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ForageNZTests/CatalogueTests | xcbeautify -q

# what is missing, without changing anything
.venv/bin/python Tools/enrich_catalogue.py      # gaps and disagreements
.venv/bin/python Tools/audit_names.py           # names that are wrong or stale
swift run catalogue-tool --photos               # photo budget and thin entries

# after adding a model file
.venv/bin/python Tools/check_target_membership.py

# after a terminal build, so the String Catalog does not drift
.venv/bin/python Tools/sync_string_catalog.py
```

**In PyCharm:** open the repo root as the project, set the interpreter to `.venv/bin/python`
(Settings → Project → Python Interpreter → Add → Existing). Seven run configurations are
committed in `.idea/runConfigurations/` and appear in the run dropdown:

| Configuration | Does |
|---|---|
| Enrich catalogue (dry run) | Reports fills, suggestions and disagreements. Changes nothing |
| Enrich catalogue (write) | Applies the fills, then normalises |
| Stage photos for review | Downloads CC-licensed candidates to `.staged-photos/` |
| Fetch eval photos | Evaluation set for the matcher harness |
| Fetch eval photos (out-of-catalogue) | The negative set, for open-set testing |
| Build land status map | Rebuilds the bundled DOC conservation / marine reserve raster |
| Sync string catalog | Merges the last build's extracted UI strings into `Localizable.xcstrings` |

Each sets the working directory to the repo root.

`mypy` is strict and must be clean; `.venv/bin/ruff format Tools/` is the formatter.
`Tools/tests/` covers nine of the scripts, including a test that **proves
`check_target_membership.py` fails** on an unlisted file, so the check cannot become a rubber
stamp.

## Enriching the catalogue from external sources

`Tools/enrich_catalogue.py` fills gaps from NZOR and iNaturalist. **It never overwrites
anything you wrote.**

```sh
.venv/bin/python Tools/enrich_catalogue.py                 # dry run: reports, changes nothing
.venv/bin/python Tools/enrich_catalogue.py --write         # applies the fills, then normalises
.venv/bin/python Tools/enrich_catalogue.py --stage-photos  # openly licensed, staged not attached
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

Headless maintenance lives in `catalogue-tool` instead, so it can run without a window.

**Formatting is load-bearing.** `CatalogueFileTests` asserts that re-encoding `species.json`
is byte-identical to what's on disk, so a save is a one-entry diff rather than a whole-file
reformat. Foundation's `prettyPrinted` writes `"key" : value` (with a space before the colon),
which is *not* what most formatters produce — after hand-editing the file, run `--normalise`.

## Playbook: adding species from a book you own

The rule this pipeline exists to enforce: **nothing in the catalogue is written by a model,
and nothing is copied from a book.** Facts (names, seasons, which species a book says are
confusable) may come from a book you own. Description text may only come from an openly
licensed, human-written source, copied verbatim and credited beside the paragraph. Safety text
— edible parts, preparation, warnings, how to tell a lookalike apart — is written by a person.

**Verbatim means in the source's own language.** A translation is not a copy: it is new prose in
the target language, and when a model produces it, it is model prose wearing a citation. So an
openly licensed article in another language is a source of *facts* like any book — cite it, do not
render it. Settled 2026-10-07 over French Wikipedia's `Xerocomellus cisalpinus`, which is CC BY-SA;
`bluefoot-bolete` cites it and quotes nothing. The ruling cost nothing in the end — an English
CC BY 4.0 description of that species turned up in a regional new-record paper. **Which is the
lesson: when a species has no Wikipedia article, search the "new record for the mycobiota of X"
literature.** Those papers carry full descriptions and the regional journals that publish them are
very often CC BY.

Every prose field is `{ "text": …, "sources": [...] }` (`SourcedText` in Swift). An empty
`sources` array means the text was written for this guide; otherwise it is the short credit,
e.g. `Wikipedia, 'Agaricus arvensis' (CC BY-SA 4.0)`. The entry-level `sources` array holds the
full citations with URL and retrieval date, prefixed by the fields they supplied
(`Identification, habitat and summary text: …`).

### 1. Index the book (off-repo)

Extract the book's text and build a JSON list of its species entries — one record per entry
with `title`, `scientific`, `maori`, `season` (the seasonality sentence) and `page`. The
Langlands e-book follows a fixed heading structure (SCIENTIFIC NAME / MĀORI NAME / OTHER
NAMES / … / SEASONALITY / CAUTIONARY NOTES), so a small parser does it. **Keep the index out of
the repo**: it contains fragments of a copyrighted book. Use the scratch directory.

### 2. Cross-check species you already have

For each catalogue entry the book covers, compare names, Māori names and months in the index
against `species.json` and correct discrepancies by hand or script. Add the citation
`Langlands, Peter. Foraging New Zealand (Penguin Random House NZ, 2024), '<entry title>' entry.`
to `sources` (cite by entry title, e-book pages don't match print) and remove the id from
`CatalogueTests.pendingVerification`. Lookalikes the book names but you don't card yet go on
the checklist (`docs/langlands-fill-in.md`), not into the JSON — a card needs a `howToTell`
in your words, and validation blocks an empty one.

### 3. Validate the names before stubbing (scanned books)

A book with labelled fields can be stubbed straight from its index. A scan read by OCR cannot:
a heading like "Dandelion coffee" parses as a binomial as readily as *Allium vineale* does, and
an invented species in a safety-critical file is the one failure worth engineering against.

```sh
.venv/bin/python Tools/validate_candidates.py --candidates cands.json --out index.json
```

Each name must be known to **NZOR** *and* carry a New Zealand biostatus — that is what says
the species is real and recorded here, and it supplies the origin. **iNaturalist** then gives
the common name and taxon page, so the entry is named by a register rather than by OCR. On
*A Forager's Treasury* this kept 82 of 238 candidates; 145 of the rejects were names NZOR has
never heard of.

### 4. Stub the species you don't have

`--skip-pages` takes the index pages already covered by step 2; `--seaweed-from` and
`--fungi-from` are the book's own chapter boundaries and are required, because one book's
page numbers mean nothing in another's (pass `0` for a book with no such chapter). Drop
`--dry-run` to write.

```sh
.venv/bin/python Tools/import_book_stubs.py --index /path/to/index.json \
  --skip-pages 421,699 \
  --seaweed-from 683 --fungi-from 726 \
  --citation "Knox, Johanna. A Forager's Treasury: A New Zealand guide to finding and using wild plants (Allen & Unwin, 2013)" \
  --dry-run
```

The citation is the book alone; `import_book_stubs` appends the book's own heading for the
species when the index carries one. It never appends the common name we chose for the entry —
that would assert the book prints a heading it may not.

Each stub gets the title as common name, the first scientific name, Māori names, months
parsed from the seasonality sentence (a stated peak wins; unparseable → year-round and
flagged), an origin from NZOR's biostatus (unknown → `introduced` and flagged), a group
guessed from chapter order and title, `careRequired`, the book citation, blank prose, and
`"draft": true`. The script prints what it could not determine; that list goes into the
checklist. Then:

```sh
swift run catalogue-tool --normalise   # regenerates SpeciesID
```

### 5. Fill descriptions from licensed sources

```sh
.venv/bin/python Tools/fetch_descriptions.py                    # drafts only, blanks only
.venv/bin/python Tools/fetch_descriptions.py --only hosta,oak   # retry a few
.venv/bin/python Tools/fetch_descriptions.py --all              # finished entries too
```

**This one writes on a plain run** — `--dry-run` to preview. Safety fields are out of scope on
purpose: neither source is a foraging text.

Copies the description-like and habitat-like sections of the Wikipedia article for the
scientific name (CC BY-SA 4.0), falling back to the Flora of New Zealand Online factsheet
(CC BY 3.0 NZ) for identification when Wikipedia has no such section. Writes
`{text, sources}` into blank `identification`, `habitat` and `summary`, appends the full
citation to the entry's `sources`, and never touches a field that has text. It backs off on
Wikipedia's 429s; expect ~15 minutes for 200 species. Sources checked and rejected: NZPCN and
Weedbusters, both all rights reserved — their facts may be restated and cited, their sentences
may not be copied.

**Non-commercial prose is admitted**, on the same 2026-09-30 decision that the app will be
free as the one admitting CC BY-NC photos. Te Ara was previously listed here as rejected for
being non-commercial only, which contradicted both the photo rule and the practice in the data
— the three clovers already carry CC BY-NC-SA text. The cost is the same one the photos carry
and is recorded in the same place: an NC source names its licence in the credit beside the
paragraph, so if the app ever stopped being free, `grep 'NC'` finds everything that would have
to come out. Prefer an unrestricted source wherever one exists, so that set stays small.

**Books and guides that are not openly licensed** — Langlands' *Foraging New Zealand* (2024),
Knox's *A Forager's Treasury* (2013), the *Wellington Regional Native Plant Guide* (2010) —
are used the same way:
names, Māori names, seasons and which species they flag as confusable, cited by entry, with no
sentence copied. A species appearing in a guide to a region's indigenous plants is evidence of
origin, too — `native` is the floor to record, since such a guide cannot distinguish endemic.

### 6. Put it in metric

```sh
.venv/bin/python Tools/metricate.py            # report; --write to apply
```

The copied text arrives in feet and inches. Most of it needs no arithmetic — the source
writes metric first with imperial in brackets — and every field it touches gains "units
converted to metric" in its credit, which CC BY-SA requires. It reports anything it will not
convert rather than guessing; fix those by hand.

### 7. Classify where it grows

```sh
.venv/bin/python Tools/classify_habitats.py    # report; --write to apply, then --normalise
.venv/bin/python Tools/classify_habitats.py --review   # docs/habitat-review.md: the evidence per label
```

Reads each entry's own `habitat` prose and files it under the `Habitat` cases the text
already supports, so the app can filter by place without parsing sentences. It adds no claim:
an entry with no habitat prose gets no labels, and prose that only gives a native range
("native to Europe") is reported as unmatched rather than guessed at. Denials are dropped —
the field mushroom's "Not in woodland." must not file it under forest — and ambiguous words
need their context, so a national park is not urban and "sea celery" in a cross-reference is
not the coast.

`--review` writes `docs/habitat-review.md`: every entry, its labels, **the literal phrase
that earned each one**, and whether the prose is yours or credited. Review the evidence, not
the verdict — both defects found so far were invisible in the label and obvious in the
phrase behind it (`urban` on a mushroom whose prose mentioned *sea celery*; `shrubland` on a
pine-plantation fungus because a shelter belt sat with the hedgerows). A wrong label is a
rule to fix in the tool, never a value to hand-edit: the file is regenerated every run.

**Where habitat can and cannot come from.** Checked, with porcini as the test case:
Wikipedia carries habitat only as prose under a heading and its scope is global — its
*Boletus edulis* section yields `coastal` and `alpine` from **California**, and `urban` from
a sentence about the Bordeaux *cèpe* trade, while never mentioning New Zealand. Wikidata has
no habitat property (`P2974` absent). iNaturalist has no habitat field or annotation, though
its georeferenced NZ observations are real evidence — 873 for porcini, concentrated in
Wellington, Christchurch and Dunedin — biased towards where people live. GBIF exposes a
Darwin Core `habitat` field that is ~1% populated (1 of 300 records for kawakawa). NZPCN has
the best NZ habitat statements but is all-rights-reserved, so cite it, never copy it. **For a
shipped entry, the owner's own NZ-specific prose beats every one of them.**

### 8. Finish a draft by hand

In the editor, a draft is a normal entry with the **Draft** toggle on. Write `edibleParts`,
`preparation`, at least one warning or lookalike, `harvestEthics` for natives and endemics;
check the guessed group and origin; then clear the toggle. `CatalogueTests` requires every
draft to be sourced *and* still fail validation — so a finished stub left as a draft, or an
unsourced stub, both fail the build. The app never lists a draft (`SpeciesStore` drops them),
so a half-written entry cannot reach the field.

### 9. Source what is left

```sh
.venv/bin/python Tools/find_sources.py            # report; --write to apply
.venv/bin/python Tools/audit_names.py             # is every scientific name real, current, and here?
```

`find_sources.py` fetches each candidate page and requires it to name the species before
citing it, so no URL is guessed. It will not write an NZOR name record into `sources`: a name
record says the name exists and nothing about the plant, and writing one would flip
`isVerified`, taking the entry off the pending list on the strength of a check nobody made.

**When the web has nothing, say so on the entry.** Some species cannot be finished online at
all: everything licensed is silent, and everything that speaks is all rights reserved. Turn on
**Book only** in the editor's Sources tab and write the note beside it — which book to reach
for, and what each route failed to give. It raises an advisory, never a blocking issue: waiting
on a book is a fact about the sources available, not a defect in the entry. The sidebar's
**Book only** filter is then the queue to work through with the shelf in front of you, and in a
debug build the entry is badged in its row and on its page.

Turn it on **only after searching**. Off means nobody has looked, not that a search came back
clean — and a flag with no note leaves the next person exactly where an untagged entry does,
which is what the advisory checks for. `wild-oat` is the worked example: see the
*"Online sourcing exhausted"* section of `docs/langlands-fill-in.md` for what was tried.

### 10. Verify

Run the full gate — the second recipe under *The tooling*. `CatalogueTests` is what the
pipeline is aimed at: byte-identical re-encoding, one `SpeciesID` case per entry,
every lookalike opens a page, no shipped entry with blocking issues, drafts sourced and
unfinished, pending-verification list current.

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
| Whole catalogue | ≤ 40 MB |

**Lossless is not an option.** A lossless PNG of a photograph at this size is 1.5–3 MB, so
four per species would be 190–370 MB embedded. HEIC at 0.62 is visually indistinguishable
for identification and roughly 30× smaller. Every number above is a constant in
`CataloguePhotos`, so retune it in one place.

Two ways in, one encoder. `PhotoImporter` lives in the model and downscales and re-encodes
on the way in, so an untouched 6 MB phone photo can't land in the repo whichever route it takes:

- **The editor**, for your own photos — drag in, caption, credit.
- **The staging pipeline**, for openly licensed photos from iNaturalist research-grade
  observations — CC0 and CC BY preferred, CC BY-NC accepted as a fallback because the app will
  be free (see `Licence` in `Tools/sources.py`):

```sh
.venv/bin/python Tools/enrich_catalogue.py --stage-photos              # candidates → .staged-photos/<id>/
# look at them; write a caption for each one you accept in .staged-photos/manifest.json
swift run catalogue-tool --attach .staged-photos/manifest.json
swift run catalogue-tool --photos                             # budget, missing files, orphans, thin entries
```

**The caption is the review.** `--attach` takes only photos whose `caption` you have filled in
and skips the rest, so nothing gets into the app that nobody has looked at. The first pass
through this rejected a black bear, a camera on a tripod, a hillside in Hawaii, and a brown
alga that was not bull kelp — research-grade is a community vote on the *species*, not on
whether the frame shows anything useful. Photos that are still over the per-photo ceiling
after compression fail loudly; shrink them and retry, or drop them. The budget does not bend.

**Observations are New Zealand ones.** A research-grade photo from California says nothing
about what a species looks like in a gully here, and the habitat prose is written about here.
The exception is an introduced species that looks the same wherever it grows and has almost no
local records: `fetch_catalogue_photos.py --worldwide`, or untick **New Zealand only** beside
the editor's *Fetch more…*. New Zealand frames are still taken first and only the shortfall
goes abroad; every overseas candidate is flagged `inNewZealand: false` in the manifest and
badged in the staged tray. `giant-timber-bamboo` is the precedent — iNaturalist holds one New
Zealand observation of it, `needs_id`, and an unconfirmed local plant is worse on an
identification page than a confirmed French one. **Keeping such a frame means saying why in
that entry's `sources`**, where a reader of the catalogue can see it.

The stager cannot resolve compound names (`Sonchus oleraceus / Sonchus kirkii`, `Ulva spp.`),
so blackberry, karengo, nettle, pūhā, sea lettuce and wild plum get nothing from it and need
the editor route.

`PhotoAuditTests` fails the build on a missing file, an oversized file, an orphaned file, or a
photo with no caption or credit.

`CatalogueEditorUITests` drives the real window: every tab reachable, the photo importer one
click from the Photos tab, prose fields accepting typed text, and the derived identifier
shown before a new species is committed. **macOS gates UI testing behind a one-time system
authentication prompt**, so run it yourself the first time (⌘U in Xcode, or
`xcodebuild test -scheme CatalogueEditor -destination 'platform=macOS'`) and approve the
prompt.

A caption is required because "the stem base" is the entire reason a photo helps, and a
credit is required because CC BY obliges it — the app displays both. The credit is also the
only record of a photo's licence: iNaturalist's attribution names it, so the CC BY-NC set the
app would have to strip if it ever stopped being free is `grep 'CC BY-NC'` away.

## Photo matching — measured, then removed from the app

There is no photo matcher in the app. It was built, measured, and taken out. The measurement
code (`Tools/Catalogue/Tooling`, linked only by the CLI) and the evaluation harness remain,
because the measurement is the useful artifact and the basis for retrying with a better model.

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
.venv/bin/python Tools/fetch_eval_photos.py                                  # gitignored
.venv/bin/python Tools/fetch_eval_photos.py --set out-of-catalogue --out .eval-photos-negative
swift run catalogue-tool --evaluate .eval-photos
swift run catalogue-tool --openset .eval-photos .eval-photos-negative
```

## Where you are — the offline land-status map

The guide says pikopiko needs a DOC permit and that karengo beds may sit inside a marine
reserve. It could not say whether *you* were standing in one. `Tools/build_land_status.py`
bakes DOC's two public layers into a bitmap small enough to ship:

```bash
.venv/bin/python Tools/build_land_status.py                  # fetch, rasterise, verify, report size
.venv/bin/python Tools/build_land_status.py --degrees 0.005  # coarser grid, smaller file
```

It writes `ForageNZ/Catalogue/land-status.png` (**237 KB** for the whole country, ~2% of the
photo budget) plus `land-status.json` describing the grid. `LandStatusMap` reads them and
answers a coordinate in constant time, entirely offline.

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
  query confidently and wrongly. `LandStatusMap.groundTruth` holds six places whose status is
  not in doubt — two national parks, Poor Knights (reserve only), Goat Island (both flags),
  and two city centres. The builder checks them **before** it writes anything and exits
  non-zero if any fail, the Swift tests check them against the shipped file, and
  `BundledLandStatusRepository` refuses to serve a map that fails them.

  Both flags need their own point. An earlier version compared only the conservation bit,
  which left the marine-reserve bit — the one carrying the absolute prohibition — verified by
  nothing, and compared `value & expected`, which is vacuously true for the two points
  expected to be unrestricted. Half the smoke test could not fail. Both are now whole-value
  comparisons.
- **Unexpected pixel values are rejected, not masked.** Folding a stray 255 into the low two
  bits would read as "conservation land AND marine reserve" — a plausible answer from a
  corrupted raster, and invisible everywhere except the six ground-truth pixels.

Location is taken once, on request, and never leaves the device.

## Fixed values

Every closed set in the catalogue lives in `ForageNZ/Catalogue/Model/`, as a `String`-raw-value
enum unless noted. They are closed on purpose: a typo fails to decode, so `species.json` cannot
carry a group or a caution level the app has never heard of, and a `switch` over one is
exhaustive — adding a case is a compile error everywhere it matters rather than a silent
default. The raw value is what the JSON stores; the display name is what the UI shows, and
changing it is a UI change with no migration.

Display names are `LocalizedStringResource`, so they reach the String Catalog. Icons are drawn
artwork resolved in `CatalogueArtwork.swift`, not SF Symbols — `CautionLevel` is the one
classification with no drawing and still uses a symbol.

**`ForageGroup`** — what sort of thing it is, for browsing and cooking. Drives the Field
Guide filter and the row icon. Deliberately neutral about edibility: the death cap's group is
`fungi`, and it is not food.

| Raw value | Display name | Image set |
|---|---|---|
| `greens` | Greens & leaves | `greens` |
| `herbs` | Herbs & flavour | `herbs` |
| `fruit` | Fruit & berries | `fruits` |
| `fungi` | Fungi | `fungi` |
| `seaweed` | Seaweed | `seaweed` |
| `nuts` | Nuts & seeds | `nuts` |

**`ForageOrigin`** — where the species sits relative to Aotearoa's own flora, which decides how
freely it can be taken. `isIndigenous` is `endemic || native`, kept as one predicate so the
validation rules and the editor cannot drift apart on it.

| Raw value | Display name | Harvest guidance |
|---|---|---|
| `endemic` | Endemic | Found nowhere else on Earth. Take the least you need; DOC permit on conservation land |
| `native` | Native | Take sparingly; DOC permit on conservation land |
| `introduced` | Introduced | Naturalised and not a pest. Harvest reasonably |
| `pest` | Weed / pest | Harvest as much as you like — you are helping |

**`CautionLevel`** — the most prominent attribute in the UI, and the one the safety tests are
built around.

| Raw value | Display name | Short | Means |
|---|---|---|---|
| `straightforward` | Straightforward | OK | A careful beginner can identify it, and is unharmed if they get it wrong |
| `careRequired` | Care required | Care | Has toxic lookalikes, or needs processing before it is safe |
| `doNotEat` | Do not eat | Danger | Listed so it can be recognised and avoided |
| `psychoactive` | Psychoactive | Psychoactive | Not poisonous, but its active compounds are controlled drugs |

`isHarvestable` is false for the last two and true for the first two. Every screen that asks
"is this food?" asks that, not `!= .doNotEat`: the two reasons not to take something differ in
kind, but no list of what to pick this month cares which one applies. The validation rules for
`psychoactive` are `doNotEat`'s — it must claim no edible parts, and it must carry a warning,
which is where the legal status goes.

**`LookalikeRisk`** — how bad it is to confuse a species with its double. `Comparable`, so
`highestLookalikeRisk` is `max()` and the ordering is the type's, not a caller's.

| Raw value | Display name | Rank |
|---|---|---|
| `deadly` | Deadly | highest |
| `toxic` | Toxic | |
| `psychoactive` | Psychoactive | |
| `unpalatable` | Unpalatable | |
| `edible` | Edible | lowest |

The risk describes the species the card *names*, not the pair — a confusable pair is carded
from both sides, and without `edible` the reverse card had to repeat the dangerous entry's own
risk, so hemlock's page told the reader that wild fennel was deadly. `psychoactive` and
`edible` are the two cases that only exist because of that. A test
(`lookalikeRiskMatchesItsEntry`) holds every card to the caution on the page it opens.

**`Habitat`** — where it grows, as a filterable classification beside the habitat prose. A case
names a **place**, and so does its label: never a thing found in it, a piece of infrastructure
or a land use. A roadside is not a habitat (`disturbed` ground is), and neither is a garden
(`urban` is). Display names read "<habitat> & <example>", never the example alone.
Deliberately coarse — see step 7 of the playbook.

| Raw value | Display name | Chip | Image set |
|---|---|---|---|
| `coastal` | Coast & shore | Coast | `shore` |
| `forest` | Forest & bush | Forest | `forest` |
| `shrubland` | Shrubland & hedgerow | Shrubland | `shrubland` |
| `grassland` | Grassland & pasture | Grassland | `grassland` |
| `wetland` | Wetland & riverbank | Wetland | `wetland` |
| `alpine` | Alpine & tussock | Alpine | `alpine` |
| `urban` | Urban & gardens | Urban | `urban` |
| `disturbed` | Disturbed & waste ground | Disturbed ground | `disturbed` |

Empty means **unclassified**, never "grows nowhere". Of 329 entries, 180 are classified, 101
have no habitat prose to classify from, and 48 have prose that is really a distribution
section. Unclassified is an advisory, never blocking.

**`ForageMonth`** — `Int` raw value, 1–12, January to December. Southern-hemisphere seasons, so
a window routinely wraps the new year and `seasonDescription` treats the calendar as circular
("Nov – Feb", not "Jan, Feb, Nov, Dec"). An **empty** month list means year-round, not unknown.

**`LandStatus`** — an `OptionSet` over `UInt8`, not an enum, because the two can hold at once.

| Value | Bit | Means |
|---|---|---|
| — | `0` | No restriction recorded |
| `conservation` | `1` | DOC public conservation land — harvesting needs a permit |
| `marineReserve` | `2` | Marine reserve — no taking of anything, ever |

**`ValidationField`** — the part of an entry an issue points at: `id`, `commonName`,
`scientificName`, `summary`, `habitat`, `habitats`, `identification`, `edibleParts`,
`preparation`, `caution`, `months`, `lookalikes`, `warnings`, `harvestEthics`, `sources`,
`needsBookSource`, `recipes`, `photos`. An enum rather than a string so the editor's tab-ownership `switch` is
exhaustive: a field no tab claims is a compile error, not an issue the editor silently never
shows. **`ValidationIssue.Severity`** is `blocking` (fails the build) or `advisory`.

**`SpeciesID`** — generated, one case per entry, described in the next section.

### Fixed values that are not enums

| Constant | Value | Why it is fixed |
|---|---|---|
| `ForageSpecies.noEdibleParts` | `"None."` | The one accepted way for a do-not-eat entry to say it has no edible parts. Matched exactly, never as a substring — "Leaves (none for children)" must not pass |
| `CataloguePhotos.maximumPixelSize` | `1000` | Longest edge, sized against what the app draws: the detail strip decodes at 720, thumbnails at 360, and nothing zooms. **This is the lever that makes full coverage fit** — 1,366 photos measure ~154 MB here against ~230 MB at the old 1400. Measure, don't extrapolate: HEIC does not shrink with pixel area (1000 px is 0.68× of 1400, not 0.51×) |
| `CataloguePhotos.compressionQuality` | `0.62` | HEIC quality |
| `CataloguePhotos.maximumBytesPerPhoto` | `220_000` | A photo over this has been mis-encoded. A defect detector, not a size lever — left at 220 KB when the pixel size dropped, so the already-shipped 1400 px photos are not flagged |
| `CataloguePhotos.totalByteBudget` | `180_000_000` | A download-size limit, not a coverage limit. Sized to stay under the App Store's default 200 MB cellular prompt; fits 4 photos on every entry (~154 MB). Applies to what **ships** — `fetch_catalogue_photos.py` does not charge staged downloads against it, and reports the real total after `--write` |
| `CataloguePhotos.recommendedCount` | 4, or 6 with a deadly lookalike | There is no signal in a gully, so the embedded photos are all the user gets |
| `CataloguePhotos.imageExtensions` | heic, heif, jpg, jpeg, png, webp | One definition, so orphan detection and the evaluation sets cannot disagree about whether a `.webp` is a photo |
| `CataloguePhotos.directoryName` | `Photos` | |
| `CatalogueLocator.relativePath` | `ForageNZ/Catalogue/species.json` | |
| `LandStatusMap.shippedResourceName` | `land-status` | `<name>.png` and `<name>.json` |
| `LandStatusMap.approximateResolutionMetres` | `300` | The builder emits ≈278 m; "about 300 m" is honest where "278 m" implies precision the raster lacks |

### What is deliberately *not* a fixed set

Prose is prose. `summary`, `habitat`, `identification`, `edibleParts`, `preparation` and
`harvestEthics` are `SourcedText`; `Lookalike.howToTell`, `Recipe.title`/`method`,
`SpeciesPhoto.caption` and `sources` are free text. The recurring temptation is `warnings`,
and the numbers answer it: there are 104 warnings across 56 entries and **103 of them are
distinct**. There is no closed set hiding inside them — the text *is* the safety content, and
an enum in its place would delete it. A `kind` alongside the text is a different proposal and
a reasonable one; replacing the text is not.

## Species are compile-time values

`SpeciesID` (`ForageNZ/Catalogue/Model/Generated/SpeciesID.swift`) has
one case per catalogue entry and is **generated, never edited** — `catalogue-tool --normalise`
and the editor's save both regenerate it. Two tests keep it honest: `SpeciesIDGeneratorTests`
fails unless the checked-in file is byte-identical to what the catalogue renders, and
`CatalogueTests` fails unless the enum and the catalogue are exactly the same set.

What that buys:

- **A lookalike can only name a species that has a page.** `Lookalike.entry` is a `SpeciesID`,
  so `species.json` naming an unknown species fails to decode and the build fails with it. No
  string matching, nothing to drift.
- **One factory, dumb views.** `SpeciesModelFactory` is a protocol; `CatalogueSpeciesModelFactory`
  is injected through `@Environment(\.speciesModels)` and returns plain models —
  `InfoPageModel`, `ListingRowModel`, `LookalikeCardModel`. Screens ask for a model and build
  the view: `SpeciesRow(model:)`, `LookalikeCardView(model:)`, `SpeciesDetailView(model:)`. The
  models are `Equatable`, so `SpeciesModelFactoryTests` checks the factory without rendering.
- **One route.** Every `NavigationStack` installs `speciesDestination()`, which switches over
  `Destination` — and `Destination.species(SpeciesID)` is its only case, so the compiler names
  every place that has to handle a new kind of page. Nothing else pushes a species page.

The cost is a workflow step in the editor: add a species → save (the enum is rewritten and the
status bar says so) → **rebuild** → only then can the new species be chosen as a lookalike's
page. That is what compile-time ids mean.

## Localisation

UI strings live in `ForageNZ/Resources/Localizable.xcstrings`, a String Catalog with English as
the source language. Every `Text("…")` and `LocalizedStringKey` in the app is extracted by the
compiler at build time (`SWIFT_EMIT_LOC_STRINGS`), so there is nothing to register by hand —
write the English in the view and it appears in the catalog. Xcode writes the catalog for you
when you build in the IDE; a terminal build does not, so:

```sh
xcodebuild build -project ForageNZ.xcodeproj -scheme ForageNZ -destination '…'
.venv/bin/python Tools/sync_string_catalog.py      # merge the build's extracted strings into the catalog
```

The sync adds new keys, never touches an existing entry or translation, and lists keys the code
no longer uses so they can be removed deliberately. Only the iOS app's strings go in — the
macOS editor is a developer tool and stays English.

**What is not localised by this:** the catalogue. `species.json` is content, not UI — an entry's
identification text in te reo Māori is a second catalogue, authored and verified separately,
not a translation of a key. That is a real piece of work and a separate decision; the UI
catalog is the prerequisite for it, not a substitute.

To add a language, add it to the catalog in Xcode (Editor → Add Language) and translate; `mi`
(te reo Māori) is the obvious first.

## Validation

Per-entry rules live in `ForageSpecies.validationIssues`, split into blocking (fails the
build) and advisory. The editor shows them at the top of each entry, and `CatalogueTests`
enforces the same rules — one definition, so the tool and the build can't disagree.

### Bright magenta means nobody designed it

The owner designs this app. A view built without them, wearing a look nobody chose, reads as
settled once it ships — so anything added to the interface that the owner has not drawn or
asked for is painted bright magenta until they have, via `View.needsDesign()`
(`ForageNZ/Components/NeedsDesign.swift`). The colour is identical in light and dark, so
neither appearance lets it pass. `grep -rn "needsDesign" ForageNZ` is the complete outstanding
list, which is the other half of the point: a placeholder nobody can enumerate is a
placeholder that stays. The psychoactive banner on the species detail screen is the first one.

## Verification status

Every entry carries `sources`. Entries with none are unverified, and
`CatalogueTests.pendingVerification` lists them: a new entry with no sources fails the build
unless declared there, and an id left on the list after being sourced also fails — so the list
can only shrink. The detail screen shows a "Not yet checked" banner until an entry is sourced.

Verified is not the same as finished: 271 entries are sourced **drafts** (see the playbook),
hidden from the app until their safety fields are written and the draft flag cleared.

A third question, separate from both: `needsBookSource` says the web has been searched for an
entry and found to hold nothing usable, so the rest has to come off a printed page.
`isVerified` asks whether anything is cited, `draft` asks whether anyone has finished writing,
and this asks whether there is any point searching again. `sourcingNote` carries which book and
why. Absent means nobody has looked — never that a search came back clean.

## Dependencies

`DesignLibrary` (`github.com/intiMRA/Desing-Library-SPM`, branch **`foraging-app`**) for
`CommonPadding` spacing tokens. That branch is the one that builds for macOS, which is what lets
the CatalogueEditor target link it and use the same tokens as the app; the project is pinned to
it so library changes can be verified from here as they land. Move the pin back to `main` once
the branch is merged. It ships no typography or public colour tokens, so text uses SwiftUI semantic
Dynamic Type styles and the caution palette is defined as asset-catalog colour sets
(`cautionSafe` / `cautionCare` / `cautionDanger`).

**`swift-dependencies`** (Point-Free, 1.17.1) carries the app's three injectable collaborators —
`\.speciesRepository`, `\.landStatusRepository`, `\.locationProvider` — plus its built-in
`\.date`, which is what lets a test put the In Season screen in February. Keys are declared in
`ForageNZ/Dependencies/`, each with a `liveValue` and no `testValue` on purpose: a test that
reaches a dependency it has not overridden gets a loud failure instead of the real bundle.

**`swift-navigation`** (Point-Free) supplies `@CasePathable`, so a `Destination` enum can drive
presentation directly — `sheet(item: $destination.adding)` rather than a `Bool` beside its
payload. **Pinned to exactly 2.7.0**, which is not tidiness: from 2.8.0 the library moved its
features behind SwiftPM *traits*, and `CasePaths` is not on by default. Trait selection exists
only in a package manifest — `enabledTraits` appears nowhere in Xcode's own frameworks — so an
Xcode project cannot switch it on, and `@CasePathable` simply does not resolve on 2.8.0+. Revisit
if Xcode gains trait support.

Both use macros, so a command-line build needs `-skipMacroValidation` (see *Building*); Xcode
asks once and remembers. They bring the graph from two pins to thirteen, `swift-syntax` included
— that is the cost, and it lands on clean builds.

`NetworkLayerSPM` is deliberately **not** a dependency — v1 makes no network calls. That still
holds with the land-status map: the boundaries ship in the bundle and `CoreLocation` reads the
GPS, so the whole feature works with the radio off.

## Building

```sh
# the iOS app
xcodebuild build -project ForageNZ.xcodeproj -scheme ForageNZ -skipMacroValidation \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify -q
xcodebuild test  -project ForageNZ.xcodeproj -scheme ForageNZ -skipMacroValidation \
  -destination 'platform=iOS Simulator,name=iPhone 17' | xcbeautify -q

# the macOS editor
xcodebuild build -project ForageNZ.xcodeproj -scheme CatalogueEditor -skipMacroValidation \
  -destination 'platform=macOS'

# the model and the CLI — no simulator, ~2s
swift test
```

`-skipMacroValidation` is required: swift-dependencies and swift-navigation both ship macro
plugins, and `xcodebuild` refuses to run an unapproved one ("Macro … must be enabled before it
can be used"). Xcode's UI asks once instead.

Use **iPhone 17** for the iOS scheme: the iPhone 16 family is only installed on iOS 18.x
runtimes here, and `xcodebuild` defaults to `OS:latest`, so those names fail to resolve.
Confirm with `xcodebuild -showdestinations` if the device list drifts.

`Package.resolved` is committed: `DesignLibrary` is branch-pinned with no tags, so it is the
only record of the revision this app was built against.

## Catalogue data

`species.json` is hand-authored. Adding an entry means satisfying `CatalogueTests`, which is
the point: the schema encodes the safety rules.

Known gaps, in rough priority order:

- **Photo coverage is uneven.** 50 of 58 entries carry reviewed CC0/CC-BY photos (198 in
  all, 23 MB of the 40 MB budget), but many are below their target and eight have none. Several are missing the one
  feature that matters most: karaka has no fruit, sweet chestnut has no burr or nut, porcini
  has no pore surface or stem net, hemlock has no shot of its blotched stem, gorse has no
  flower close-up, and kareao has no shoot tip. Those need photographs taken on purpose.
- **Every shipped entry is now sourced**, down from 58 unsourced this morning. Langlands (2024) covers 39, Knox (2013) three more, `Tools/find_sources.py` found
  institutional references for eight, six were sourced by hand, and the last two — group
  pages rather than species — are sourced by the register's answer to what species they
  cover. `pendingVerification` is empty.
- **271 drafts await their safety text** — 187 cite Langlands, 110 cite Knox (35 both), and
  9 came from the registers alone; 255 carry a licensed description. `docs/langlands-fill-in.md` lists what each still needs; the
  Knox drafts have no season at all, because that book states none. Two disagreements with
  Langlands were left conservative on purpose: it treats water celery and ripe black nightshade
  berries as edible; the catalogue says do not eat.
- **No user lists yet** — favourites, found, wanted. Planned, with the model and boundaries
  worked out, in `docs/plans/species-lists.md`.
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
