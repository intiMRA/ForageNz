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

## Candidates noted while filling food entries

Non-food uses met in sources while filling food pages. Nothing here is on a page yet; each needs its
source re-read (licence first) and the plan's rules applied before it is used.

| Species (entry id) | Use | Where it was seen |
|---|---|---|
| Hedge woundwort (`hedge-woundwort`) | Tough stem fibre; yellow dye from the plant | Kahikatea Farm 'Woundwort' (NZ nursery); PFAF 'Stachys sylvatica' |
| Red deadnettle (`red-deadnettle`) | Dye for wool | Grow Forage Cook Ferment; Nerdy Farm Wife |
| Kōkihi / beach spinach (`beach-spinach`) | Red berries used as a stain and dye (not eaten) | Ngā Rauropi Whakaoranga, Tunuku Karetai to Beattie |
| Kohia (`kohia`) | Seed oil, fibre, scent | Ngā Rauropi Whakaoranga |
| Henbit deadnettle (`henbit-deadnettle`) | Salve (medicinal — out of scope unless decision 1 changes) | Nerdy Farm Wife |
| Narrow-leaved plantain (`plantain`), greater plantain (`greater-plantain`) | Leaf-infused oil for salves, balms, lip balm, lotion bars and soap; bath salts and bath bags; infused-vinegar hair rinse (medicinal and cosmetic — out of scope unless decision 1 changes) | The Nerdy Farm Wife '10 Things to Make with Plantain' (written for Plantago major and P. lanceolata); Hedgecombers 'Plantain salve recipe' (both species); On the Land 'Plantain for pain' (infused-oil and beeswax balm); Herb Federation of NZ 'Plantain' (infused oil) |
| French broom (`french-broom`) | Stem fibre (cellulose biofibre) | Seen in search results 26/10/2026: 'Characterizing Teline monspessulana as a green sustainable source of biofibers', BioResources (Chile); not read |
| Climbing dock (`climbing-dock`) | Dye for wool; ornamental fruiting valves; leaf monoprints (paint dabbed on the leaves, pressed between paper) | Flora of New Zealand vol. IV 'Rumex sagittatus'; Diego Bonetto, 'How to forage and cook rambling dock' (21/08/2021) |
| Sheep sorrel (`sheep-sorrel`) | Mordant-free dye, green to yellow to red (docks' leaves and stalks generally) | Diego Bonetto, 'How to identify and use yellow dock and its close relatives' |
| Curled dock (`curled-dock`) | Root oil colours cold-process soap pink; roots dye yellow, dark green to brown and dark grey without a mordant; leaf-infused oil salve for itchy skin (medicinal — out of scope unless decision 1 changes) | Diego Bonetto (as above); Eat The Weeds 'Rumex Ruminations' (reader comment); Useful Tropical Plants 'Rumex crispus'; The Nerdy Farm Wife 'Yellow Dock Salve Recipe' |
| Broad-leaved dock (`broad-leaved-dock`) | Leaves wrapped butter for market ('butter dock') | Wikipedia 'Rumex obtusifolius'; Totally Wild UK; Eat The Weeds |
| New Zealand dock (`new-zealand-dock`), broad-leaved dock | Sap, leaves and root used on abrasions, boils, cracked lips (medicinal — out of scope unless decision 1 changes) | Ngā Rauropi Whakaoranga |
| Common sorrel (`common-sorrel`) | Roots dye green, grey and brown, leaves and stems blue-grey; juice removes stains from linen and cloth (laundry stain-remover); an ingredient in wood and silver polish | The Foraging Course Company 'Common sorrel - Rumex acetosa'; The Wildlife Trusts 'Common sorrel'; Kew Species Profile (POWO); Korpelainen & Pietiläinen 2020 (dyes) |
| Pōhue / pink bindweed (`pink-bindweed`) | Used as tying material; roots boiled for nursing mothers, purgative root (medicinal — out of scope unless decision 1 changes) | Useful Temperate Plants 'Calystegia sepium'; Ngā Rauropi Whakaoranga; Plants For A Future |
| Lesser burdock (`lesser-burdock`) | Fibre for paper; root used as a herbal remedy (medicinal — out of scope unless decision 1 changes) | Useful Temperate Plants 'Arctium minus'; Common Weeds of New Zealand via RNZIH |
| Narrow-leaved plantain (`plantain`) | Dye (plant simmered in water, for textiles); clothing starch; cordage; seed-coat mucilage as a food thickener and stabiliser | Wikipedia 'Plantago lanceolata'; The Foraging Course Company 'Ribwort plantain'; Useful Temperate Plants 'Plantago lanceolata' |
| Greater plantain (`greater-plantain`) | Tough leaf fibres for small cords, fishing line and braiding; seed mucilage as a thickener (ice cream, chocolate) and in cosmetics; seed sold as bird feed; kopakopa as rongoā for ulcers, boils, burns, cuts and bites (medicinal — out of scope unless decision 1 changes) | Wikipedia 'Plantago major'; Useful Temperate Plants 'Plantago major'; Rongoā Mauri 'KOPAKOPA'; Ngā Rauropi Whakaoranga 'Plantago spp.'; On the Land 'Plantain for pain' (bird feed) |
| Water plantain (`water-plantain`) | Root and leaves in Chinese and European herbal medicine ('mad-dog weed') (medicinal — out of scope unless decision 1 changes) | Useful Temperate Plants 'Alisma plantago-aquatica'; Wikipedia; Botanical Society of Scotland plant of the week 19/08/2024 (Gerard's Herbal 1597, Chinese 'zexie'); herbs2000.com |
| Water plantain (`water-plantain`) | Removing heavy metals from stormwater and industrial wastewater (phytoremediation; stored in the roots) | Botanical Society of Scotland plant of the week 19/08/2024, citing Ushakumary and Madhu 2014 |
| Wild radish (`wild-radish`) | Seed oil (up to 48 %) as a potential biofuel feedstock — Wikipedia says it is not suitable for human consumption, while Useful Temperate Plants lists an edible seed oil; reconcile before writing either | Wikipedia 'Radish' (Other uses, citing Southeast Farm Press 2009); Useful Temperate Plants 'Raphanus raphanistrum' |
| Radish (`radish`) | Seed pressed for radish seed oil; daikon types grown as a cover or catch crop to raise soil fertility, scavenge nutrients, suppress weeds and ease compaction | Wikipedia 'Radish' (Other uses) |
| Hedge mustard (`hedge-mustard`) | Medicinal (out of scope): the 'singer's plant', infusion or syrup for sore throats and lost voice; also a honey plant | PFAF / Useful Temperate Plants 'Sisymbrium officinale'; Wikipedia 'Sisymbrium officinale'; Grieve, A Modern Herbal (1931); Herbiguide 'Hedge Mustard' ('Honey plant.') |
| Field mustard (`field-mustard`) | Medicinal (out of scope): leaves used medicinally by Māori ('Pleasant and refreshing', Servant 1973) | Ngā Rauropi Whakaoranga 'Brassica rapa subsp. sylvestris' |
| Field mustard (`field-mustard`) | Fuel oil: the oilseed form's seed oil was burned in lamps and steam engines before it became an edible oil; non-food rapeseed oil is called colza oil | NordGen 'Brassica rapa' plant portrait; Wikipedia 'Brassica rapa' |
| Creeping saltbush (`creeping-saltbush`) | The plant used as a source of potash | Useful Temperate Plants 'Atriplex prostrata' (citing Komarov, Flora of the USSR) |
| Common orache (`common-orache`) | Medicinal (out of scope): antiscorbutic; just-ripe seeds as a laxative | Ngā Rauropi Whakaoranga 'Atriplex patula. Orache.'; Useful Temperate Plants 'Atriplex patula' |
| Garden orache (`garden-orache`) | Ornamental: seed pods dried for floral decorations; a blue dye from the seed; a potential biomass crop | Useful Temperate Plants 'Atriplex hortensis'; Owairaka Seeds and Susie Ripley Gardening 'Ruby Gold' listings |

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
