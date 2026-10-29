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
| Calendula (`calendula`) | Yellow dye from boiled flowers and petal food colouring; golden hair rinse; seed oil (calendic acid) for paints and coatings; compost activator, eelworm deterrent, companion plant; cosmetics. Medicinal (out of scope): skin remedy, mouth rinse | Useful Temperate Plants 'Calendula officinalis'; Wikipedia; EMA HMPC monograph; MSK; CONECT-e |
| Common lawn daisy (`common-lawn-daisy`) | Insect-repellent spray from a leaf infusion; daisy chains. Medicinal (out of scope): wound herb, bruise ointment | Useful Temperate Plants 'Bellis perennis'; Wikipedia; CONECT-e; Eatweeds |
| German chamomile (`german-chamomile`), Roman chamomile (`roman-chamomile`) | Yellow to gold dye from the flowers; fair-hair rinse; plant tonic / liquid feed and compost activator; strewing herb and insect repellent; essential oil for perfume and cosmetics; Roman chamomile as a lawn plant; German chamomile infusion sprayed on seedlings against damping-off and on courgettes and cucumbers against mildew, a companion plant; flower-infused oil for soap (adds a soft yellow), lip balm, lotion and bath salts. Medicinal (out of scope) | Useful Temperate Plants 'Matricaria chamomilla', 'Chamaemelum nobile'; Flora of New Zealand vol. IV; EMA HMPC monographs; Herb Federation of New Zealand 'Chamomile'; The Nerdy Farm Wife '10 Things to Make with Chamomile' |
| Stinking chamomile (`stinking-chamomile`) | Gold dye from the whole plant; repels mice and fleas, insecticide | Useful Temperate Plants 'Anthemis cotula'; BSBI Fermanagh Flora |
| Pineappleweed (`pineappleweed`) | Insect repellent (plant, dried flowers); flower-infused oils, balms and salves; herbal baths and body oils | Useful Temperate Plants 'Matricaria matricarioides'; Pukerau Wild and Cured (Southland), 'The Arrival of Sun & Pineapple Weed' |
| Yarrow (`yarrow`) | Yellow and green dyes from the flowers; liquid plant feed and compost activator; insect repellent; beer bittering (gruit); skin cleanser; insectary plant, drought-tolerant pasture, erosion control; long-lasting cut flowers and dried floral crafts; perfume. Medicinal (out of scope): wound herb, fever and cold remedies | Useful Temperate Plants 'Achillea millefolium'; Wikipedia; Massey NZ Weeds Database; CONECT-e; The Plant Store NZ 'Achillea Butterscotch'; ACHS 'Herb of the Year Yarrow' |
| Horseweed / broad-leaved fleabane (`horseweed`) | Crushed seeds repel fleas; leaf oil active against Aspergillus niger. Medicinal (out of scope) | Massey NZ Weeds Database 'Broad-leaved fleabane'; PROSEA (van Valkenburg 2003); Alfinandah et al. 2025 |
| Mouse-ear hawkweed (`mouse-ear-hawkweed`) | Allelopathic root exudates. Medicinal (out of scope): urinary tea, wound leaves | Wikipedia 'Pilosella officinarum'; EMA HMPC monograph; CONECT-e |
| Nipplewort (`nipplewort`) | Seed oil (about 6%) investigated. Medicinal (out of scope): purgative tea, poultice | Botanical Society of Scotland 07/08/2023; Useful Temperate Plants; CONECT-e |
| Ox-eye daisy (`ox-eye-daisy`) | Medicinal (out of scope): lotions, eye wash, flower tea | Useful Temperate Plants 'Leucanthemum vulgare'; Wikipedia |
| Prickly lettuce (`prickly-lettuce`), wild lettuce (`wild-lettuce`) | Seed oil for soap, paints and varnish; birdlime from boiled roots; fodder; leaf extract in cosmetics. Medicinal (out of scope): lactucarium, wart latex | Useful Temperate Plants 'Lactuca serriola', 'Lactuca virosa'; CONECT-e; Wikipedia 'Lactucarium' |
| Salsify (`salsify`) | Root latex as chewing gum; rabbit fodder. Medicinal (out of scope): latex on cuts | Useful Temperate Plants 'Tragopogon porrifolius'; CONECT-e |
| Variegated thistle (`variegated-thistle`) | Flower heads and seeds as rennet for cheese; seed oil; bee forage, green manure; fodder. Medicinal (out of scope): silymarin | CONECT-e 'Silybum marianum'; Useful Temperate Plants; EMA HMPC monograph |
| Beaked hawksbeard (`beaked-hawksbeard`) | Rosettes gathered for pig fodder | CONECT-e 'Crepis vesicaria' (Aceituno-Mata 2010) |
| Sea celery (`sea-celery`) | After-sun and sensitive-skin care (claimed by a retailer, no source given). Medicinal (out of scope): anti-scorbutic, used by Cook | Warndu 'Sea Parsley – Parsley with a punch!'; Ngā Rauropi Whakaoranga 'Apium prostratum' |
| Celery (`celery`) | Seed essential oil, used in the perfume industry | Wikipedia 'Celery' |
| Nasturtium (`nasturtium`) | Decoy (trap) plant in vegetable gardens: aphids, mites, caterpillars and whiteflies go to it first; a flower-and-leaf brew sprayed on plants against insects (one blog). Medicinal (out of scope): tincture, antibiotic, hair and skin claims | Yates NZ 'How to grow bright, edible and versatile Nasturtium'; Goodness is… 'nasturtiums – a tea, a pesto and a cure'; Practical Self Reliance 'Nasturtium Tincture' |
| Broadleaf sea lettuce (`broadleaf-sea-lettuce`) | Fishing bait for blackfish (luderick) in New South Wales; Ulva biomass for land-based aquaculture (genus, not this species alone) | Milkwood 'Foraging + Eating Sea Lettuce'; The Forager's Year 'Sea lettuce (Ulva lactuca)'; Lawton et al. 2021, Algal Research 56: 102320 (abstract) |
| Bog yellow cress (`bog-yellow-cress`) | Medicinal (out of scope): leaves antiscorbutic, possibly the plant de Surville's crew used in 1769; whole plant in traditional Chinese medicine | Useful Temperate Plants 'Rorippa palustris'; Ngā Rauropi Whakaoranga (L'Horne in McNab 1914); Mitochondrial DNA Part B 2024 (PMC11425686) |
| Honesty (`honesty`) | Seed oil (30–40%, erucic and nervonic acids) proposed for high-temperature lubricants and nylons; dried seed-pod septa in dried-flower arrangements and floristry; bee, butterfly and moth plant | Useful Temperate Plants 'Lunaria annua'; Molecules 2024 (PMC11357284); Wikipedia 'Lunaria annua'; CONECT-e 'Lunaria annua'; Yates NZ 'How to grow Honesty'; Kings Seeds NZ 'Honesty'; Addenbrooke NZ 'Lunaria annua'; BBC Gardeners' World 'How to grow honesty' |
| Land cress (`land-cress`) | Seed oil, studied as a potential oilseed crop | Useful Temperate Plants 'Barbarea verna' |
| Perennial wall-rocket (`perennial-wall-rocket`) | Insect food plant (eleven insect species in Britain); the flowers draw beneficial insects into gardens, especially hover flies. Medicinal (out of scope): wild rocket cooked in wine in Trotula's Treatments for Women | Wikipedia 'Diplotaxis tenuifolia'; Virgil Evetts, 'Wild About Rocket', Foodlovers (2009) |
| Sea rocket (`sea-rocket`) | Seed oil (high erucic acid) for industrial uses. Medicinal (out of scope): diuretic, antiscorbutic, digestive, purgative | Wikipedia 'Cakile maritima'; Plants 2024 review (PMC11511379) |
| Shepherd's purse (`shepherds-purse`) | Seed in water traps mosquito larvae; phytoremediation (accumulates Cd, Cu, Cr, Zn, Fe; roots for 2,4-dichlorophenol soil); reclaiming salty or marshy land; fodder for rabbits, poultry, goats, sheep; wild and domestic birds eat the seeds, and hens fed the fresh plant lay darker, stronger-tasting yolks; ratafía liqueur (Girona). Medicinal (out of scope): EMA traditional-use monograph for heavy menstrual bleeding; Spanish folk haemostatic; First World War wound extract; alcohol tincture (WishGarden) | Useful Temperate Plants 'Capsella bursa-pastoris'; Nutrients 2024 16(24):4390; CONECT-e 'Capsella bursa-pastoris'; EMA/HMPC/262766/2010; LearningHerbs 'Shepherd's Purse Uses'; WishGarden 'How to Make a Shepherd's Purse Tincture' |
| Stock (`stock`) | Dark blue or purple dye from the flowers; ornamental, cut flower and florist flower (clove-scented); bees visit the flowers. Medicinal (out of scope): seed and infusion uses; traditional medicine in Iran, India, Ecuador, Bolivia, Italy | Useful Temperate Plants 'Matthiola incana'; Taviano et al. 2020, Biology 9:163; Wikipedia 'Matthiola incana'; Kings Plant Barn 'Stock' growing guide; The Hampshire Seed Company 'Matthiola Incana Grow Along'; Emerden 'Stock' collection |
| Sweet alyssum (`sweet-alyssum`) | Insect repellent and garden edging (Mallorca); bee and butterfly plant; draws beneficial insects into gardens. Medicinal (out of scope): antiscorbutic, diuretic, tisanes; veterinary use | Useful Temperate Plants 'Lobularia maritima'; CONECT-e 'Lobularia maritima'; Yates NZ 'How to grow alyssum' |
| Twin cress (`twin-cress`) | Phytoremediation of lead-polluted soil (accumulates lead, mainly in roots); animal fodder. Medicinal (out of scope): dried plant sold in South America; Cantabrian folk remedy for colds | Useful Temperate Plants 'Lepidium didymum'; CONECT-e 'Coronopus didymus'; Wild Food UK 'Lesser Swine Cress' |
| Wood blewit (`wood-blewit`) | Grass-green dye for fabric or paper: the chopped mushrooms boiled in water in an iron pot. Medicinal (out of scope): extracts inhibit some bacterial and fungal pathogens and a plant pathogen (*Phytophthora capsici*); water extract affects sugar and fat metabolism in mice | First Nature 'Lepista nuda'; Woodland Trust 'Wood blewit'; Michigan State University Bonito Lab 'Clitocybe Nuda' |

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
