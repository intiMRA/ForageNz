# Plan: plants foraged for fibre, dye and other uses

**Status:** planned, not started. Written 16/10/2026 at the owner's request. **Starts only after**
the food catalogue is finished and the work in `species-lists.md` (lists, then finds and the map)
is done. Nothing in the app depends on this yet.

## Goal

Let the guide cover plants gathered for something other than eating: fibre (weaving, cordage,
basketry), dyes, and other practical uses the owner chooses (see *Open decisions*). A species
that is already in the catalogue for food gains its other uses on the same page; a species with
no food use gets a page of its own. The content rules do not change: nothing written by a model,
nothing copied from a book, every claim from a trusted source and credited beside it.

## Why this is more than adding entries

The catalogue is food-shaped from the model up, and every one of these assumes "is this food?":

- `ForageGroup` (`greens`, `herbs`, `fruit`, `fungi`, `seaweed`, `nuts`) has no place for a fibre or
  dye plant.
- `CautionLevel.isHarvestable` answers "can I collect it to eat". A dye plant can be `doNotEat` and
  still be worth gathering; today that would read as "don't collect".
- `SpeciesValidation` is written around eating: a do-not-eat entry must say "None." for its edible
  parts and state the danger, and a care-required entry must say why with a warning or a lookalike.
  None of that says what a fibre or dye page must contain before it ships.
- `LookalikeRisk` describes what happens if you *eat* the wrong plant. For a dye or fibre plant, the
  danger can be handling it (sap, skin reactions) or harvesting a protected lookalike.
- `months` is the window when the collected part can be harvested (owner, 12/10). That rule carries
  over unchanged, but the part changes, from fruit to leaves, bark or stems.

## Model (proposal, to settle before starting)

- **One entry per species, with its uses on that entry.** Nettle or harakeke must not get a
  second page for fibre — the no-catch-all rule is about species, so it also forbids two pages for
  one species. Add `uses: [SpeciesUse]`, where each use has a kind (`food`, `fibre`, `dye`, …), the
  part used, how it is prepared, its own warnings, and its own `sources`. Today's food fields become
  the `food` use; migrate them by script, keeping the bytes identical (the `swiftjson.py` dumper).
- **Groups:** add non-food groups (for example "Fibre & weaving", "Dyes"), or make group a
  property of the use rather than the species. Decide with the browse UI in mind.
- **Caution split:** keep `caution` about eating, and add a handling caution for non-food uses, so
  a dye plant can be "do not eat" and "wear gloves" at once without either reading as the other.
- **Validation per use:** a food use keeps today's blocking rules. A fibre or dye use needs, at a
  minimum: the part used, the harvest window, how it is processed, and any handling warning. A page
  ships when every use on it passes.
- **Lookalike cards** gain a risk for "protected, do not harvest" if that turns out to be needed,
  since harvesting a protected or at-risk species is a legal risk, not a poisoning risk.

## Content and sources

- **Processing steps are safety text.** Dye mordants (alum, iron, copper and so on) and retting or
  boiling fibre involve chemicals, heat and waste water. Under the README rule these are written by a
  person or quoted from an openly licensed source — never written by a model.
- **Tikanga carries more weight here than for food.** Harakeke, kiekie, pīngao and the plants used
  for dyes in raranga are taonga, and the right way to harvest them comes from Māori practice and
  Māori authors. `harvestEthics` should come from those sources (or from people the owner consults),
  not from a weed database. Some species are protected or At Risk, and harvesting on DOC land needs a
  permit; the page must say so where it applies.
- **Source leads to check (licence first, as always):** Ngā Rauropi Whakaoranga (Manaaki Whenua's
  database of Māori plant uses); Te Ara; Flora of New Zealand (descriptions, CC BY 3.0 NZ); the
  "Other uses" sections of Useful Temperate Plants (CC BY-NC-SA 3.0); Te Papa collections. None has
  been read for this yet.

## Open decisions (decide before starting)

1. **Which uses are in scope** besides fibre and dye? Candidates: basketry and weaving materials,
   cordage, tinder and kindling, soap plants, natural building materials. **Recommendation:**
   medicinal uses stay out unless the owner decides otherwise. A medicinal claim is the riskiest
   kind of safety text, and there are few trusted open sources for it.
2. **Groups:** new top-level groups, or a "uses" filter across the existing groups?
3. **Who reviews tikanga text,** and whether some taonga species get a page that describes the
   plant but deliberately leaves out how to harvest it.
4. **Order:** start with species already in the catalogue (adding a use to an existing page), or with
   the best-known non-food plants first?

## Steps, when it starts

1. Decide the four items above.
2. Model: `SpeciesUse`, the caution split, validation per use; migrate food fields into the `food`
   use; regenerate; tests that the migration changes no shipped page.
3. Editor and `catalogue-tool`: show and check uses; `--check` reports gaps per use.
4. UI: uses on the species page, the group or filter, the handling caution.
5. Content: one pilot species end to end (sources, tikanga, photos, cards), reviewed by the owner
   before any batch.
6. Report (`Tools/catalogue_report.py`): count gaps per use.

## Not in scope

Selling or trading what is gathered, cultivation instructions, medicinal use (unless decision 1
changes that), and any change to the food content rules.
