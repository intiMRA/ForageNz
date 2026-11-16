# Plan: "Grows with" — symbiotic links between species

**Status:** proposed 16/11/2026; owner decisions 16/11/2026 below. Nothing built yet.

## Owner decisions (16/11/2026) — these override the sections below where they differ

- **Scope: anything that requires a specific other species.** Root partners, parasites and
  hosts, and also wood-rotting fungi *when they need one particular tree* (olive oyster on southern
  beech). A generalist on any dead wood (wood ear, velvet shank) gets no link.
- **Partners with no food use get entries anyway** — do-not-eat entries (southern beeches, fly
  agaric and the like) so the fungi have a page to link to.
- **Genus-level sources ("under beech") are researched to the species** before linking. No
  link rests on a genus line; if research can't name the species, there is no link yet.
- **Death cap shows on its hosts' pages** (oak, sweet chestnut, European beech) with its
  poisonous badge — it is a symbiotic partner like any other.

## Goal

A species page shows the living partners it depends on, as tappable cards that open the partner's
page — the way lookalike cards do. Birch bolete shows a silver birch card; the silver birch page
shows birch bolete (and every other fungus that grows with it) back. Two uses:

- **Finding food.** "Under silver birch" is the single best clue for birch bolete. From the tree's
  page the forager sees every fungus worth looking for underneath it.
- **Safety.** The oak and sweet chestnut pages would list death cap among their partners — the
  most useful warning the catalogue can give someone standing under an oak looking for porcini.

## What counts as a link

Only **living partnerships** where one species is found with the other:

| Kind | Meaning | Examples in the catalogue today |
|---|---|---|
| `mycorrhizalPartner` | Root partner; the fungus fruits only near the tree | birch bolete – silver birch, slippery jack – radiata pine, larch bolete – larch, western painted suillus – Douglas fir, tawai milkcap – beech |
| `parasiteOf` / `hostOf` | One lives off the other | peppery bolete – fly agaric (reported mycoparasite), and later mistletoes, dodder, *Dactylanthus* |
| `growsOnDeadWoodOf` / `deadWoodHostOf` | Decays the wood of one particular tree only | olive oyster – southern beech (species to research) |

**Not links:** fungi that rot the dead wood of many trees (wood ear, velvet shank, brown oyster) —
nothing specific is required, and habitat already says "on dead mānuka, kānuka, gorse…".
Pollinators, food plants of insects and companion planting are out too.

Each link is a **claim on a page**, so the same rules as lookalike cards apply: a source that
states the partnership for *this* species (NZ source preferred; overseas only when it names the
same species), recorded as a dated sources line on both entries. A genus-level line ("with
*Nothofagus*") never links on its own: research it to the species (Virtual Mycota collection
hosts, Biota/Landcare records, papers) and link only the species a source names.

## Model

```swift
public nonisolated struct Association: Codable, Sendable, Hashable {
    public let kind: AssociationKind
    /// Typed like `Lookalike.entry`: an unknown id fails to decode, so a link can only name a
    /// species the catalogue has.
    public let entry: SpeciesID
    /// One short line for the card, e.g. "Its only root partner in New Zealand."
    public let note: String
}

public nonisolated enum AssociationKind: String, Codable, Sendable {
    case mycorrhizalPartner   // symmetric
    case parasiteOf, hostOf   // each other's inverse
    case growsOnDeadWoodOf, deadWoodHostOf   // each other's inverse
}
```

`ForageSpecies` gains `associations: [Association]` (decoded with `[]` as the default so existing
JSON loads unchanged). The JSON stays the source of truth; the macOS editor gets a section like
Lookalikes.

### Validation (`SpeciesValidation` + `CatalogueTests`)

- Blocking: not its own partner; empty note.
- Blocking (catalogue-wide test): **every link has its reverse** — A `mycorrhizalPartner` B ⇔
  B `mycorrhizalPartner` A; A `parasiteOf` B ⇔ B `hostOf` A; A `growsOnDeadWoodOf` B ⇔
  B `deadWoodHostOf` A. Same idea as "cards both ways", but
  enforced by a test rather than by hand.
- Shipped entries may link to drafts (a shipped card that opens a draft is a note to self, as
  with lookalikes).

## UI

- **Species page:** a "Grows with" section after Habitat, horizontal cards reusing the lookalike
  card's layout (photo from the target entry, name, scientific name, the note) without the risk
  badge. When a partner is poisonous (death cap) the card shows the target's caution badge, so
  the danger is visible without opening it.
- Section hidden when empty. Accessibility id `association.<id>` for UI tests.
- No new tab or filter for now. Later, possibly: a "Grows with" filter on the Map's finds
  ("show my oaks, then what grows under them").

## Catalogue round — seed links from what is already written

Habitat text already names most partners. Hosts **already in the catalogue**:

| Host entry | Fungi whose habitat names it |
|---|---|
| `monterey-pine` | slippery jack, saffron milk cap, rufous milkcap, peppery bolete, porcini, bluefoot bolete |
| `larch` | larch bolete |
| `douglas-fir` | western painted suillus |
| `english-oak`, `holm-oak` | death cap, oakbug milkcap, porcini, bluefoot bolete, riverine bolete |
| `sweet-chestnut` | porcini, death cap |
| `manuka`, `kanuka` | skirt webcap |

Hosts **not in the catalogue yet** (would need entries before they can be linked):

| Host | Fungi whose habitat names it | Food records to check |
|---|---|---|
| **Silver birch** *Betula pendula* | birch bolete, porcini, bluefoot, riverine bolete, coconut milkcap, downy milk-cap, ugly milkcap | sap, young leaves (PFAF + others) |
| European beech *Fagus sylvatica* | bluefoot, death cap, slimy milkcap | beech nuts (PFAF, Knox?) |
| Southern beeches — hard, red, silver, black, mountain | tawai, umere, NZ milkcap (hard beech), chalciporus aurantiacus, skirt webcap, olive oyster | probably none → doNotEat "partner" entries; which beech each fungus needs is researched first |
| Fly agaric *Amanita muscaria* | peppery bolete | poisonous → doNotEat |
| Poplar, willow, alder | riverine bolete | check each |

**Silver birch first** (the owner's example): an introduced tree with food records for sap and
leaves, checked against the usual standards (NZ presence threshold, PFAF line, NZ-source text,
two food records, sourced months, photos). Then link the seven fungi to it.

Each linked entry gets a dated line: `Associations round <date>: <partner> — '<quote>' (<source>)`.

## Steps

1. Model + decoding default + validation + reverse-link test (unit tests first).
2. Species page section + factory model + UI test on one pair.
3. Editor section (macOS tool).
4. `catalogue_report.py`: show links per entry and flag one-way links.
5. Silver birch entry (owner reviews like any group), then the seed links above, group by group.

## Still open

- Which wood-rotting fungi in the catalogue need one particular tree — to be checked fungus by
  fungus during the round, not assumed from habitat wording.
