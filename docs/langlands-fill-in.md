# Fill-in checklist after the Langlands cross-check

Source: Langlands, Peter. *Foraging New Zealand* (Penguin Random House NZ, 2024).
Cited by entry title because e-book pagination differs from print.

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

## Facts changed to match the book

- Months: porcini Jan–May, field mushroom Feb–Apr, slippery jack Feb–Jun, elderflower
  Sep–Dec and Feb–Apr, walnut Feb–Apr, karaka Feb–Apr, onionweed Jun–Dec, cleavers Jun–Nov,
  poroporo Feb–Apr, hawthorn Jan–May, pikopiko Jun–Aug (winter), fat hen Sep–May,
  nasturtium and pūhā year-round. Elderflower's `edibleParts` month ranges were updated to
  match.
- Māori and alternative names on dandelion, pikopiko, kareao, poroporo, horopito, karaka,
  karengo. Slippery jack broadened to *Suillus* spp.; kawakawa carries its synonym.

## Not in the book (19), still `pendingVerification`

tutu, death-cap, rosehip, saffron-milk-cap, sea-lettuce (book covers *Ulva lactuca* as
"Broadleaf sea lettuce" — our entry is *Ulva* spp.; cite if you narrow it), yellow-stainer,
petty-spurge, scarlet-pimpernel, bracken, horse-chestnut, snowflake, straw-mushroom,
bitter-bolete, red-pored-boletes (book's "Peppery bolete", *Chalciporus piperatus*, is a
related edible), other-milk-caps, hemlock-water-dropwort, feijoa, wild-plum, cherry-guava.
