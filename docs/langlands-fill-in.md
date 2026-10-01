# Fill-in checklist after the book cross-checks

Sources, all used the same way — facts only, nothing copied:

- Langlands, Peter. *Foraging New Zealand* (Penguin Random House NZ, 2024). Cited by entry
  title, because e-book pagination differs from print.
- Knox, Johanna. *A Forager's Treasury* (Allen & Unwin, 2013).
- Greater Wellington Regional Council. *Wellington Regional Native Plant Guide* (2010).

What was taken from the book: names, Māori names, seasons, and which species it warns
are confusable. What was deliberately **not** taken: any description, tip or method. Those
fields are blank or untouched so the owner writes them in their own words.

## Recipes with a title and no method (39 species)

Every recipe added in this pass has `"method": ""`. The detail view hides the empty method.
Write each method yourself; the titles are generic dish names, not the book's.

## Lookalikes the book names that we do not yet card

Each needs a `howToTell` written in your own words (validation blocks an empty one), and the
last four need a new species page first because `Lookalike.entry` must be a `SpeciesID`.

| Species | Book flags confusion with | Page exists? |
|---|---|---|
| porcini | white-gilled *Amanita* buttons (death cap) | yes: `death-cap` |
| catsear | dandelion (and vice versa) | yes: `dandelion` |
| field-mushroom | rust-gilled *Cortinarius* (webcaps) | no |
| gorse | broom (*Cytisus*, *Genista*, *Spartium*) | no |
| onion-weed | white bluebell (*Hyacinthoides*), snowdrop (*Galanthus nivalis*), lily of the valley (*Convallaria majalis*) | no |

## Where the book disagrees with the catalogue (not changed)

- **water-celery** is `doNotEat` here; the book lists it as an edible with a carrot-like
  flavour. The real hazard is confusion with hemlock water dropwort and hemlock. Decide
  whether this becomes `careRequired` with edible parts written up.
- **black-nightshade** is `doNotEat` here; the book says fully ripe black berries are eaten
  in many countries, unripe berries and older leaves are not. Left conservative on purpose.
- **hemlock** and **ongaonga** have book entries but no season or caution block there, so
  only the citation was added.
- **fat-hen** was matched to the book's "Spear-leaved orache" entry, which is *Atriplex
  prostrata* — a different species that also goes by fat hen. Our entry is *Chenopodium
  album*, so that citation and the months read from it have been removed; it is sourced by
  Knox alone now. A book entry for *Chenopodium album* would be worth finding.

## Facts changed to match the book

- Months: porcini Jan–May, field mushroom Feb–Apr, slippery jack Feb–Jun, elderflower
  Sep–Dec and Feb–Apr, walnut Feb–Apr, karaka Feb–Apr, onionweed Jun–Dec, cleavers Jun–Nov,
  poroporo Feb–Apr, hawthorn Jan–May, pikopiko Jun–Aug (winter),
  nasturtium and pūhā year-round. Elderflower's `edibleParts` month ranges were updated to
  match.
- Māori and alternative names on dandelion, pikopiko, kareao, poroporo, horopito, karaka,
  karengo. Slippery jack broadened to *Suillus* spp.; kawakawa carries its synonym.

## Draft stubs for the book's other species (187)

Created by `Tools/import_book_stubs.py` from the book's names and seasons, then
`Tools/fetch_descriptions.py` copied description text verbatim from Wikipedia (CC BY-SA 4.0)
and Flora of New Zealand Online (CC BY 3.0 NZ). Every prose field is `{text, sources}`; a copied field carries its short credit in `sources`, and
the entry's Sources section names which fields each source supplied. Drafts are hidden from
the app until the `draft` toggle is cleared in the editor; the tests require a draft to be
both sourced and still failing validation.

What every draft still needs from you: `edibleParts`, `preparation`, at least one warning
or lookalike, and `harvestEthics` for the 49 natives and endemics. Review the
guessed `category` too (most defaulted to greens).

- Season: 28 of these read as year-round, which in the data is indistinguishable from a
  genuine year-round species. Four were known-unparseable (coprosma, yew, hounds-tongue-fern,
  fruit-salad-plant); the rest the book gave as year-round. Check before clearing a draft.

## Second source: Wellington Regional Native Plant Guide (2010)

Greater Wellington Regional Council, revised edition 2010. **© Greater Wellington, all rights
reserved** — no open licence, so only names were taken from it, never a sentence. It is a
guide to planting the region's indigenous species, not a foraging text: it says nothing about
edibility, and its zone pages are the only NZ-regional distribution data we have seen so far
(see the README's "no location awareness" gap).

- Māori names added to 11 drafts that had none: harakeke, kahikatea, kānuka/mānuka, karamū,
  kōhia, miro, raupō, rengarenga, rimu, taupata, tōtara.
- Its citation was added to the 21 entries it covers.
- Appearing in it establishes a species as indigenous, so rimu and New Zealand spinach moved
  off the defaulted `introduced`; harakeke moved after its scientific name was repaired.
  All are set to `native`, the floor — the guide cannot tell endemic from non-endemic, so
  confirm against NZOR before clearing a draft.
- Three stub scientific names were truncated by a parenthesis (`Phormium tenax (and`,
  `Sisymbrium officinale (formerly`, `Opuntia ficus-indica (Indian`) and are now repaired;
  the importer drops the parenthesised aside.

## Third source: A Forager's Treasury (Knox, 2013)

A New Zealand foraging book, so unlike the Wellington guide it speaks to edibility. Its text
is organised as prose under "Spotting it" / "Using it" rather than labelled fields, so only
coverage facts were taken — which species it treats as foraged here, and which it lists as
commonly poisonous. No season was inferred from its prose.

- It covers **28** shipped entries and **35** existing drafts, each of which now carries its
  citation; that took tutu, horse chestnut and rosehip off `pendingVerification`.
- Only 31 of its citations name a book entry. The scan's headings are unreliable — captions,
  truncations, and the heading of the species next along the page — so a heading is kept only
  when it matches the entry's own name in both directions. The rest cite the book alone, which
  is accurate; a citation pointing at the wrong entry would not be.
- Its "Common poisonous plants" chapter names hemlock, karaka, ongaonga, tutu, nightshades,
  yew and rangiora, all of which we have; its citation is on each.
- **Two it names as commonly poisonous that we have no page for**: Jerusalem cherry
  (*Solanum pseudocapsicum*) and oleander (*Nerium oleander*). Both are common garden plants
  in New Zealand. Worth adding as `doNotEat` entries — with warnings written by you.
- **74 new drafts came from it.** 238 candidate binomials were scraped from the scan and put
  through `Tools/validate_candidates.py`: NZOR had to know the name *and* give it a New
  Zealand biostatus, and iNaturalist supplied the common name and taxon page. 156 were
  rejected — 145 of them names NZOR has never heard of, which is what the OCR noise looks
  like from the outside. Seven of the survivors were already in the catalogue.
- Knox's prose carries no seasonality field, so all 74 have **no months** and are flagged
  year-round. That is the first thing to fix on each one.
- `Urtica aspera` was dropped: the book prints "No common name" for it and iNaturalist has
  none either, and an entry cannot be listed without a name.
- `manuka` (*Leptospermum scoparium*) arrived as its own draft even though the Langlands
  stub `kanuka-and-manuka` (*Kunzea ericoides*) covers both in one page. Merge or split when
  you get to them.

## Two species added from the second pass

- **Creeping saltbush** (*Atriplex prostrata*) — Langlands' "Spear-leaved orache" entry, the
  one `fat-hen` was wrongly matched to. It now has its own page, so the citation and its
  season sit where they belong.
- **Sterilised oat** (*Avena sterilis*) from Knox.

Re-pooling every candidate from both books left 170 not already in the catalogue; NZOR
recognised 6, and 4 of those were species we already hold under another name. One of those
four is worth a look: Knox's watercress entry is *Rorippa divaricata*, an endemic, which is a
different species from our *Nasturtium officinale* watercress and cannot use that id.

## Nine milk caps and a bolete, from the registers rather than a book

`Chalciporus piperatus` and every *Lactarius* on record in New Zealand were added from
iNaturalist's species list for the genus, checked against NZOR, and cited to their taxon
pages. They are the only drafts that come from neither book.

## Where the drafts stand

| | Count |
|---|---|
| Entries in the catalogue | 329 |
| Shipped (app shows these) | 58 |
| Drafts | 271 |
| Drafts with an identification paragraph | 250 |
| Drafts still needing one | 21 |

Every draft still needs `edibleParts`, `preparation`, a warning or lookalike, and
`harvestEthics` if native or endemic (64 are).

- No identification text found (21): algerian-oat, black-cherry, brown-oyster-mushroom, coprosma, geranium-species, hosta, lilly-pilly, linden-tree, magnolia, miro, new-zealand-kombu, new-zealand-milkcap, oak, red-straw-weed, scented-geraniums, sea-rimu, sea-rocket, stock, tawai-milkcap, umere-milkcap, wakame.

## Finding sources for the unsourced (`Tools/find_sources.py`)

Every candidate page is fetched and has to name the species before it becomes a citation, so
no URL here is guessed. Eight of the sixteen unsourced entries now have one:

- **NZPCN fact sheets** for cherry guava, wild plum, petty spurge, bracken and snowflake.
- **Landcare Research's Virtual Mycota** for the death cap.
- **iNaturalist NZ's observation record** for bitter bolete and hemlock water dropwort —
  cited for a narrower claim than the others: both pages already say the species may not
  occur here, and zero New Zealand observations is the evidence for that.

What a register cannot do is verify that something is safe to eat, so `find_sources.py` will
not write an NZOR name record into `sources`: doing so would flip `isVerified` and take an
entry off this list while claiming a check nobody made. Pass `--name-records` to see them.

Six more were then found by hand, each fetched and checked to name its species first:

| Entry | Source |
|---|---|
| scarlet-pimpernel | Massey University's New Zealand Weeds Database |
| saffron-milk-cap | Plant & Food Research, on *L. deliciosus* under *Pinus radiata* here |
| feijoa | NZ Feijoa Growers Association's variety guide, for the harvest windows |
| yellow-stainer | State Herbarium of South Australia fact sheet (confirmed by reading the PDF) |
| straw-mushroom | Beaty Biodiversity Museum, UBC — on the volva it shares with the death cap |
| sea-lettuce | Hurd et al., *NZ Journal of Marine and Freshwater Research* 49(4), 2015, by DOI |

Both group pages are sourced too — see the next section, which is where the answer came
from. `pendingVerification` is now empty.

## The two group pages, and what the registers said about them

`red-pored-boletes` and `other-milk-caps` are not species, so no fact sheet could source them.
Asking the registers which species they are *about* answered it, and changed one of them.

**The bolete rule looks overstated — your call, not mine.** Neither NZOR nor iNaturalist
records *Rubroboletus* (*R. satanas*, *R. pulcherrimus*) in New Zealand, nor any *Neoboletus*
with a New Zealand biostatus; those are the genera that make "red pores" a poisoning warning
overseas. What *is* established here is the peppery bolete, *Chalciporus piperatus*: NZOR
lists it as exotic, iNaturalist holds 550 New Zealand observations, and Langlands treats it as
edible, used as a flavouring rather than a meal. Both searches are cited on the entry.

I rewrote the page's text on that evidence and then reverted it: `red-pored-boletes` is a
shipped do-not-eat page, and its wording is yours. **The page still says what it said this
morning.** What changed is that the evidence now sits in its `sources`. Two things to decide:

- Does "several of them cause violent vomiting" still hold for New Zealand, where the genera
  behind that claim have no record? Bear in mind absence from two databases is not proof of
  absence, and this same file notes NZOR's fungal coverage is patchy.
- Porcini's card grades this lookalike `toxic`. If the answer above is no, `unpalatable`
  would match the peppery bolete, which is what a forager here will actually have picked.

**Ten species pages replace the guesswork.** Every *Lactarius* on record in New Zealand now
has a draft — *L. rufus*, *L. pubescens*, *L. turpis*, *L. glyciosmus*, *L. blennius*,
*L. quietus*, and the endemics *L. tawai*, *L. novae-zelandiae*, *L. umerensis* — as does
*Chalciporus piperatus*. Six got licensed descriptions; the three endemics have no Wikipedia
or Flora article, so they need theirs written. Once the peppery bolete draft is finished, porcini's card can point at it and the group page
can retire. Nothing in the app refers to it until then — a shipped card may not open a draft.

## Metric (`Tools/metricate.py`)

Wikipedia writes in feet and inches, so the copied descriptions arrived that way. 124 fields
are now metric, and each of their credits says "units converted to metric" — the CC BY-SA
licence allows the change and requires declaring it.

Most needed no arithmetic: the source gives metric first with imperial in brackets, so the
bracket goes. Where the imperial came first, or the two were offered as alternatives
("5–7 mm or 0.20–0.28 inches", "above 10°F or -12°C"), the metric already there is kept.
Only a genuinely imperial-only measurement is converted, and then the original stays in
square brackets — an editor's mark inside a quotation, and out of reach of the tool's own
round-bracket patterns, so a second run cannot strip what the first one preserved.

Three fields are left alone and reported rather than guessed at: `hioi` has a bare fraction
("1/6 to 1/2 inches"), `fishpole-bamboo` has an imperial-only value already inside brackets,
and `chilean-sea-fig`'s source used square brackets of its own. A wrong measurement in a
field guide is worse than an unconverted one.

The word "in" is only read as an inch where a bracket or a dimension word follows it, so
"flowers 3–12 in umbelliform cymes" is left as the prose it is.

## Name audit (`Tools/audit_names.py`)

Every scientific name in the catalogue was put to NZOR: is it a name, is it current, is it
recorded in New Zealand. All 318 entries at the time, 39 worth a look, three corrected:

| Entry | Was | Now | Why |
|---|---|---|---|
| cherry-guava | *Psidium cattleianum* | *Psidium cattleyanum* | spelling iNaturalist accepts |
| hounds-tongue-fern | *Zealandia pustulata* | *Lecanopteris pustulata* | NZOR's current name |
| choko | *Sechium edule* | *Sicyos edulis* | NZOR's current name |

Left alone, with reasons:

- **Genus-level entries** (`Ulva spp.`, `Lactarius spp.`, `Hosta spp.`, `Coprosma spp.`, and
  nine more) are deliberate: the page covers a group, not a species. NZOR answers about
  species, so it reports these as unknown. Not an error.
- **NZOR says synonym, we keep ours**: feijoa (*Acca sellowiana*, NZOR prefers *Feijoa
  sellowiana*), wild-plum (*Prunus domestica*, NZOR writes *Prunus ×domestica*), harakeke
  (NZOR's match was a cultivar). Judgement calls for you.
- **No New Zealand biostatus** on ten entries, including four shipped (chickweed, field
  mushroom, karengo, yellow stainer). NZOR's coverage of fungi and algae is patchier than its
  coverage of plants; iNaturalist has all of them. Worth a second look before shipping, not a
  sign the species is invented.
- **Spelling differences** iNaturalist prefers but NZOR does not settle: *Tetragonia
  tetragonioides* / *tetragonoides*, *Agarophyton chilense* / *Gracilaria chilensis*,
  *Crataegus germanica* / *Mespilus germanica*.

No entry in the catalogue is a species that does not exist.

## Not covered by any of the three books (16), sourced from registers and institutions

death-cap, yellow-stainer, bitter-bolete, red-pored-boletes (Langlands' "Peppery bolete",
*Chalciporus piperatus*, is a related edible), other-milk-caps, saffron-milk-cap,
straw-mushroom, hemlock-water-dropwort, petty-spurge, scarlet-pimpernel, bracken, snowflake,
sea-lettuce (Langlands covers *Ulva lactuca* as "Broadleaf sea lettuce" — our entry is *Ulva*
spp.; cite if you narrow it), feijoa, wild-plum, cherry-guava.

Mostly fungi and lookalike-only pages. A mushroom guide is the obvious next source.

## Online sourcing exhausted: wild-oat (*Avena fatua*) — 2026-10-01

Asked for after an NZPCN link was offered for the entry. Every route was fetched and read.
**Nothing online can close `edibleParts`, `preparation`, `habitat` or `months` on this
entry under a licence we accept, so it has to come from a book.**

| Source | Licence | What it gave |
|---|---|---|
| NZPCN fact sheet | all rights reserved | a features paragraph shorter than the one we hold, naturalised 1872, origin Eurasia/N Africa. No habitat, months, or uses. |
| Flora of NZ Online factsheet | CC BY 3.0 NZ | already quoted in `identification`; the page has no habitat, distribution, flowering or fruiting fields at all. |
| Wikipedia, *Avena fatua* | CC BY-SA 4.0 | already quoted in `summary`; **no uses or edibility section exists**, only description and weed impact. |
| Practical Plants wiki | CC BY-NC-SA | the only licensed edibility text found — see below. |
| PFAF | all rights reserved | same text as Practical Plants, which forked it. Cite, never copy. |
| Search results otherwise | — | SEO content farms with no named author or sources. Not citable. |

**The one usable source is weak, and it is your call whether to take it.** Practical Plants
gives `"Seed - cooked"`, seed ground to flour for porridge, biscuits and bread, sprouted for
salads, roasted as a coffee substitute, and `"The seed ripens in the latter half of summer
and, when harvested and dried, can store for several years. It has a floury texture and a
mild, somewhat creamy flavour."` Three reasons to hold off:

- It is a PFAF fork, and PFAF's edible-use lines here trace to Hedrick's *Sturtevant's
  Edible Plants of the World* (1972) and Usher's *A Dictionary of Plants Used by Man* (1974)
  — nineteenth- and twentieth-century compilations, not first-hand practice.
- It is not New Zealand. No habitat statement, and "latter half of summer" is a northern
  season that would be wrong in `months` without inverting it.
- **It omits the whole difficulty.** Every practical account of wild oat says the work is
  dehulling and de-awning the grain, and that the panicle shatters within a narrow window.
  An `edibleParts` that says "seed — cooked" and stops is the kind of entry this catalogue
  is meant not to ship.

**Knox is already in the entry's `sources` and is the right fill-in.** Same treatment as the
rest of this file: facts only, nothing copied. The other four *Avena* drafts — `algerian-oat`,
`bristle-oat`, `slender-wild-oat`, `sterilised-oat` — are empty in exactly the same four
fields and can be done in the same sitting.

**The verdict now lives on the entry, not only here.** `wild-oat` carries
`"needsBookSource": true` and a `sourcingNote` naming Knox and what each route failed to give,
so the editor shows it while you work and the sidebar's **Book only** filter is the queue. This
section stays as the evidence behind that one flag. The other four *Avena* drafts are
deliberately **not** flagged: they are empty in the same fields, but their online sourcing has
not actually been tried, and the flag has to mean "checked and exhausted" rather than "looks
similar" — otherwise it stops being a reason to skip a search.
