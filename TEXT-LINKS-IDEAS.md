# Text links + OpenURLAction ideas — ForageNZ

Source: harness rule `ios-swift/standards/15-text-links-openurl.md` (from https://jacobzivandesign.com/technology/links_in_swiftui_markdown_do_what/). Audited 16/10/2026.

## 1. Tappable source citations — high value
- `ForageNZ/FieldGuide/SpeciesDetailView.swift:264` renders each `species.sources` entry as plain `Text(source)`.
- 963 of 1,532 sources in `ForageNZ/Catalogue/species.json` end in a URL (Wikipedia, iNaturalist), and none can be tapped today.
- Fix: build an `AttributedString` per source, mark URL ranges with `NSDataDetector(types: .link)`, render `Text(attributed)`. Tint from the design system.
- Wikipedia CC BY-SA attribution is better served by a working link too.

## 2. Poisons Centre number inline — medium
- `ForageNZ/Safety/SafetyView.swift:14-19`: the sentence states the number, then a separate `Link("Call …")` repeats it.
- Option: put the number in the sentence as a `tel:` markdown link. Keep the separate button too if the big tap target matters for a safety screen (it probably does), so this is optional.

## 3. Cross-links between species — medium, needs catalogue work
- Summary / habitat / identification / lookalike text (`SpeciesDetailView.swift:107-138`, `:252`) could link species names with an app-owned scheme, e.g. `forage-species:<id>`.
- Handle with `.environment(\.openURL, OpenURLAction { … })` scoped to the detail view: route to the species, return `.handled`; everything else `.systemAction`.
- Lookalike warnings linking straight to the dangerous lookalike is the most useful case. Needs markdown in the catalogue text and `AttributedString(markdown:)` (runtime strings don't parse markdown in `Text`).

## 4. Smaller bits
- `ForageNZ/WhereYouAre/WhereYouAreSection.swift:36` footer: "Boundaries are DOC's" could link to the DOC dataset/licence page.
- `WhereYouAreSection.swift:28-31` failed state: fine as `Text` + button; an inline "Try again" link is possible but not worth it.
