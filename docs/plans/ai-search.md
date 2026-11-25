# Plan: search the field guide in plain words

**Status:** built 25/11/2026, uncommitted. A, B and C approved by the owner 25/11; waiting on a
run on an iPhone, since the on-device model does not run in the simulator.

**History.** Written 16/10/2026 as "Siri, Spotlight and an on-device model for search", to come
last. Started early on 25/11 ("implement this"); Siri, Spotlight and Shortcuts intents were built,
then dropped the same day — owner: "I don't think we need siri voice search we only need ai search
in app eg. 'plants in season that grow on grass'". What remains is search inside the app.

## Goal

Type what you are after in plain words — "plants in season that grow on grass", "white flowers by
a stream", "fungi in March" — and get catalogue rows back. Nothing the guide shows is written by a
model.

## The rule this has to fit

README:261–265: nothing in the catalogue is written by a model, and safety text is written by a
person. So the model reads the user's words and never writes the guide's: its only output is enum
cases (group, origin, habitat, month) and words copied from the query, and the app turns that into
an ordinary search over the catalogue. No answers to "can I eat this?" — the rows open the pages a
person wrote. On-device only: no Private Cloud Compute, no network.

## Decisions

- **In-app only** (owner, 25/11). Rejected: Siri voice, Spotlight, App Shortcuts (built, then
  removed the same day).
- **Synonyms, model wording and test queries are drafted from the catalogue's own words and ship
  only when the owner approves them** (owner, 16/10).
- **Deployment target iOS 26** (owner, 25/11): Foundation Models needs it. Rejected: iOS 27 (forces
  Xcode 27), iOS 18 with `#available` branches. Builds with the owner's Xcode 26.1.1.
- **No photo identification; no summarising or rewriting catalogue text** (owner, 16/10).
- **No other local model** (MLX, llama.cpp): a large download for a 500-entry guide, its own
  licence, battery and heat, and the same rule on its output. Revisit only if Apple's model misses
  too much of C.

## What is built

**Word search, no model** (`ForageNZ/Catalogue/SpeciesSearch.swift`, every species screen):

- Folds macrons, case, hyphens and punctuation: `kanuka` finds kānuka.
- Names, then summary, then identification and habitat text, at the start of a word; a word inside
  a name ranks last ("cress" finds watercress). Every word must match; filler words do not count.
- The guide's own labels act as filters: group ("fungi", "berries"), origin ("native" includes
  endemic, "weed"), habitat ("coast", "bush", "wetland", "waste ground"), month ("March", "mar"),
  "in season". A test fails any filter word no label carries. An entry named by the whole query is
  always found ("bush lawyer" is not read as forest).
- The line under the search box says which words became filters.

**Plain words, on the device** (`ForageNZ/Catalogue/PlainWordsSearch.swift`, Field guide tab):

- A "Search in plain words" button appears under the search box once the query has three or
  more words (owner, 25/11: a button, not Return, which gives no hint it searches differently).
  Tapping it asks Apple's on-device model for a `SearchReading`:
  groups, origins, habitats, months, and words. Words the query does not contain are dropped, so
  the line under the box ("✦ Grassland · November") only echoes the guide's labels and the user's
  own words. Greedy sampling; the current month is given for "now" and "in season".
- If the reading's words match nothing, the list falls back to its filters alone.
- Editing the query drops the reading; asking again cancels a read in flight.
- The button is offered only where the model reports itself available (owner, 25/11), and also
  whenever word search finds nothing. Where it is offered, a tap must show a reading or a note
  ("Couldn't read that as a search"); a UI test holds both.
- **Does not run in the simulator**: the iOS 26.3 and 27 simulators report the model available,
  then every request fails in Apple's safety check ("SafetyGuardrailTextSanitizerBackend …
  Simulator is not supported", 25/11/2026). Try it on an iPhone 15 Pro or later with Apple
  Intelligence on.

## Approved by the owner

Each was drafted from the catalogue's own words and approved on 25/11/2026.

### A. Search synonyms — approved by the owner 25/11/2026 ("A yeah do it"); in `SpeciesSearch.Vocabulary.habitatSynonyms`

The words `Tools/classify_habitats.py` already reads as each habitat when it classifies the
catalogue's prose — the guide's own mapping, not a new one. Plurals match too ("streams").

| Habitat | Search words |
|---|---|
| Coast | coastal, coastline, seashore, beach, dune, sand dune, estuary, saltmarsh, tidal, intertidal, mangrove, harbour, rock pool, seaside |
| Forest | woodland, woods, canopy, understorey, plantation, podocarp, shelter belt |
| Shrubland | scrub, scrubland, gorse, broom, hedge, thicket, bracken, regenerating |
| Grassland | paddock, meadow, lawn, grass, grassy, farmland, farm, turf, playing field |
| Wetland | swamp, bog, marsh, river, stream, streamside, creek, pond, lake, lakeside, ditch, drain, seepage, freshwater, riparian, waterlogged |
| Alpine | subalpine, scree, herbfield, treeline, mountain, high country, snowline |
| Urban | suburb, suburban, city, town, berm, street, backyard, allotment, cemetery, churchyard, park |
| Disturbed | roadside, verge, wayside, wasteland, railway, rubbish, vacant, abandoned, derelict, fallow, trackside, car park, pavement, kerb |

Left out on purpose: "mānuka"/"kānuka" (the classifier reads them as shrubland, but as a search
word they are species names), "sea" (ambiguous without the classifier's context rules).

### B. The model's habitat wording — approved as written by the owner 25/11/2026 ("B yeah do it")

`PlainWordsSearch` tells the model: a stream, river, swamp or bog is wetland; a beach, dune or
estuary is coastal; bush and woodland are forest; grass, a paddock or a lawn is grassland; a
roadside or waste ground is disturbed; a garden or park is urban.

### C. Test queries — approved by the owner 25/11/2026 ("C sure")

To run on a device with Apple Intelligence; misses are recorded here. Expected results are what
the catalogue's own classes should return, not a judgement of any species.

| Query | Should read as | Should include |
|---|---|---|
| white flowers by a stream | Wetland · "white" "flowers" | entries in wetland whose text has white flowers |
| what can I pick in March | March | the March list of the In season tab |
| native fruit near the beach | Native · Fruit · Coast | native and endemic fruit classed coastal |
| mushrooms under pine trees | Fungi · Forest · "pine" | fungi in forest mentioning pine |
| seaweed I can find now | Seaweed · this month | seaweed in season |
| weeds growing on the roadside | Weed · Disturbed | pest entries classed disturbed |
| the sorrel with purple leaves | "sorrel" "purple" "leaves" | sorrel entries mentioning purple |
| berries in the bush in autumn | Fruit · Forest | forest fruit (no month: "autumn" is not a month) |
| nuts from introduced trees | Nuts · Introduced | introduced nut entries |
| greens growing in my garden | Greens · Urban | urban greens |
| alpine plants in January | Alpine · January | alpine entries in season in January |
| something peppery in the forest | Forest · "peppery" | forest entries whose text says peppery |
| plants in season that grow on grass | Grassland · this month | grassland entries in season (the owner's example, 25/11) |

## Next

1. Run C on an iPhone; record misses here; adjust B only from what C shows. (A, B and C were
   approved 25/11; A is in the word search, so it works without the model.)

## Not in scope

Siri, Spotlight and Shortcuts; any model-written text in the catalogue or on screen; cloud models;
identifying from a photo; changes to the content rules.
