# Plan: Siri, Spotlight and an on-device model for search

**Status:** planned, not started. Written 16/10/2026 at the owner's request ("add a plan to
integrate siri or a local llm for search and other things"), after reading Jordan Morgan,
'iOS 27, Your App, and Siri', Swiftjective-C, 15/06/2026
(https://www.swiftjectivec.com/siri-ai-for-ios027/). The article is a summary written from one
WWDC session, and the author says he may be missing context. Every API below must be checked
against Apple's documentation before it is built. **Starts last** (owner, 16/10): after the food
catalogue, `species-lists.md` (lists, finds and the map) and `useful-plants.md`. Decisions from the
owner's interview, 16/10/2026, are folded in below and listed under *Decisions*.

## Goal

Find a species by asking for it in plain words, in the app and through Siri and Spotlight:
"white flowers by a stream", "what can I pick in March", "the sorrel with the purple leaves",
"open kawakawa". The answer is always a page, or a list of pages, from the catalogue. Nothing
the guide shows or says is written by a model.

## The rule this has to fit

README:261–265: nothing in the catalogue is written by a model, and safety text (edible parts,
preparation, warnings, how to tell a lookalike apart) is written by a person. A model that *answers*
a foraging question writes safety text, and on-device models make things up confidently. So:

- **A model may read the user's words. It may not write the guide's.** Its only output is
  structured: which species, which filters. The app turns that into a list of catalogue entries and
  shows their own text, unchanged.
- **No generated answer to "can I eat this?"**, "is this safe?", "how do I tell X from Y?". The
  model's output types have no free-text field for these, so it cannot produce one. Questions like
  these open the species page.
- **Siri gets names, not safety text.** What the app exposes to the system is limited to what is
  safe for the system's own model to say again: names, group, months, habitat tags, and the caution
  level as a label only (owner: "Yes, label only") — so Siri can say "hemlock, do not eat" and open
  the page. `edibleParts`,
  `preparation`, `warnings` and lookalike `howToTell` are **not** exposed as entity properties, so
  Siri cannot summarise them into an answer that sounds like the guide. "Is it edible?" in Siri
  opens the page.
- **Drafts stay invisible.** Only shipped entries are indexed, exactly as the browse view filters
  them today.
- **Offline.** The app is used in the bush with no signal. Everything here runs on the device; no
  cloud model (Private Cloud Compute included) and no network calls.

## Where search is today

`ForageSpecies.searchableText` (`ForageNZ/Catalogue/Model/ForageSpecies.swift`) joins common name,
Māori name, scientific name and summary, lowercased; `SpeciesStore` (line 109) filters by
`contains`. No App Intents, no Spotlight, no `NSUserActivity`. Deployment target iOS 18.0 today;
**raised to iOS 27 when this plan starts** (owner: raise it; the owner's phone will be on iOS 27).
No `#available` branches for the Siri and App Intents APIs.

## Phases

### 1. App entities, Spotlight and Siri: no model of our own

- **`SpeciesEntity: IndexedEntity`**, a small version of `ForageSpecies` (the article's point: an
  entity is not the model). Properties: id, common name, Māori name, scientific name, group, origin,
  months, habitat tags, caution level (as its label), plus one photo for its `DisplayRepresentation`. Index shipped
  entries; re-index when the bundled catalogue version changes.
- **Actions the owner wants** (16/10): **what's in season** (`InSeasonIntent`, "What's in season in
  ForageNZ?"), **plain-language search** (phase 3, also as an intent), and **log a find** ("I found
  kawakawa here"; needs the finds/map work in `species-lists.md`, which lands first). Each returns
  entities that open their pages, with App Shortcuts phrases. "Open a species" was not picked as a
  priority; it comes almost free with the entity query and can be added if it is. The owner asked
  for **anything else useful** to be proposed and decided when the plan starts (see *Open
  decisions*).
- **On-screen awareness:** `.userActivity(…)` with `appEntityIdentifier` on the species page, and
  `.appEntityIdentifier(…)` view annotations on browse and in-season rows, so "tell me about this"
  refers to the right species. **Check what the system does with it:** if Siri answers from the
  entity's properties, the restricted property list above is what keeps it from reciting safety text.
- **App schemas:** none of Apple's schema domains fits a field guide, as far as is known. The
  article says it is unclear how far an app outside the schemas can take part in the new Siri. Use
  plain App Intents and entities; look again when the iOS 27 docs are final.
- **Test:** Spotlight and Siri find shipped species by any of the three names; drafts never appear;
  no entity property holds edible, preparation, warning or lookalike text (a unit test over
  `SpeciesEntity`'s properties, so a later change cannot add one quietly).

### 2. Better search with no model

Worth doing before any model, and it gives the model a fallback:

- Match without macrons (`tutae kaka` finds `tūtae kākā`, `kanuka` finds `kānuka`) and without
  case.
- Search identification and habitat text too, ranked below names.
- Filters as words: group ("fungi"), month ("March", "in season"), habitat tag ("by a stream" →
  wetland), origin ("native"). A fixed list of synonyms: **drafted by Claude from the catalogue's
  own words, each approved or rewritten by the owner; only approved ones ship** (owner, 16/10).

### 3. On-device model for plain-language search (Apple Intelligence devices)

- **Apple's Foundation Models framework** (`LanguageModelSession` with guided generation,
  `@Generable`). The OS is not gated (target iOS 27), but the model still is: check that it is
  available on the device (Apple Intelligence off, unsupported hardware, model not downloaded) and
  fall back to phase 2's search.
- **Output is a struct, not prose:** for example `SearchRequest { names: [String], group?, months:
  [Int], habitats: [Habitat], flowerColour?, origin? }`. `@Generable` limits the model to these
  fields and to the enum cases.
- **Matching stays in our code.** The struct runs through phase 2's search; names are looked up in
  the catalogue and unknown ones dropped. The model never picks a species we don't hold, and never
  writes text that is shown to the user.
- **Tool calling** (`Tool`) only to look up the catalogue's own values (group names, habitat tags), if
  that improves accuracy; never to fetch anything off the device.
- **Shown as search, not as an answer:** results appear as rows, like any search, with the query
  the model understood ("white flowers · wetland") so the user can see and correct it.
- **Test:** a fixed set of queries with the species each should return — drafted by Claude,
  approved by the owner, as for the synonyms; run
  on a device with the model; record misses. A wrong result is a search miss, never a false claim,
  because the page shown is the catalogue's own.

### 4. "Other things", each a separate decision

Candidates, none started without the owner's word:

- **Finds and the map** (`species-lists.md`): "I found kawakawa here" through Siri, if that plan
  lands first.
- **Identify from a photo: out** (owner, 16/10). Foundation Models image input exists, but a model
  naming a plant or fungus from a photo is an identification the guide would then be vouching for,
  and that is the deadly-lookalike case this app exists to guard against.
- **Summarising, translating or rewriting catalogue text:** out. It is model-written text on a
  page.

## Local LLM other than Apple's

Considered: running an open model on the device (for example through MLX Swift or llama.cpp).
**Recommendation: no, for now.** It means a download of hundreds of MB to several GB for a
catalogue of 338 entries, its own licence to check, battery and heat in the field, and the same
rule applies to its output, so it would do no more than phase 3. Revisit only if Apple's model is
not good enough at phase 3's test set, or the owner needs it on devices without Apple Intelligence.

## Decisions (owner's interview, 16/10/2026)

1. **Order:** last — after the food catalogue, the lists plan and the useful-plants plan.
2. **Caution level is visible to Siri, as a label only.** No edible, preparation, warning or
   lookalike text.
3. **Minimum OS: raise the app to iOS 27** when this starts; the owner's phone will be on it.
4. **Synonyms and test queries:** Claude drafts from the catalogue's own words; the owner approves
   or rewrites each; only approved ones ship.
5. **Photo identification: out.**
6. **Actions:** what's in season, plain-language search, log a find; open-a-species optional.

## Open decisions

1. **"Anything else useful"** (owner): propose further intents when the plan starts, each decided
   on its own. Candidates to put to the owner then: "what can I find near here" (habitat tags plus
   location, if the finds/map work gives one); "show my lists" and "add this to a list" (lists
   plan); "what's in season in <month>"; a Spotlight result for each recipe that opens its species.
   Each must pass the same rule: it returns pages, it never answers a safety question.

## Steps, when it starts

1. Re-read Apple's current App Intents, Spotlight and Foundation Models docs for iOS 27; correct
   this plan where the article was wrong or out of date. Raise the deployment target to iOS 27.
2. Phase 1: `SpeciesEntity`, indexing, two intents, on-screen annotations, the property test.
3. Phase 2: macron-insensitive, ranked search with word filters; tests.
4. Phase 3 behind availability checks; the owner's query set; report the misses.
5. Phase 4 items only as the owner decides them.

## Not in scope

Any model-written text in the catalogue or on screen; cloud models; answering safety questions
outside a species page; changes to the content rules.
