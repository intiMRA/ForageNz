# Plan: show the edible part in a photo

**Status:** planned, not started. Written 26/11/2026 at the owner's request; decisions settled
the same day (see *Decisions*). **Built after `useful-plants.md`, and only when the owner
explicitly says to build it.

## Goal

The Edible parts section is text only: "Young stems, no thicker than about 1.5 cm… also the leafy
side stalks, the flowering heads, the black seeds, and the root, cooked." A forager reading that on
a hillside has to map each phrase onto the plant in front of them. The page should *show* it:

1. **Part photos** — a photo is tagged with the edible part it shows, and the Edible parts section
   carries a strip of those photos, each labelled with the part ("Young stems", "Flowering heads").
2. **Marked photos** — on top of that, the part can be circled on the photo, so a photo of a whole
   plant can still point at the one bit you pick.

Part photos are cheap and come first; marks build on them.

## ⚠️ Why this is a safety surface

A circle on a photo says "eat this bit" more loudly than any sentence on the page. A wrong one is
worse than none: a circle on unripe fruit, on the raw root of a plant that is only safe cooked, or
on the leaves of a plant whose leaves are poisonous will be believed. So the same rules apply as
for any edibility text (README; memory: edibility states, not reports):

- **A mark only shows what the Edible parts text already says.** Its label is a part named in
  `edibleParts.text`, in those words, with the text's qualifier where there is one ("Root —
  cooked", "Berries — ripe, seeds removed"). No mark adds a part, a stage or a preparation the text
  does not carry; if the text needs changing, change the text (with a source) first.
- **No edible marks on "Do not eat" or "Psychoactive" entries** (126 of 500 today). Blocking rule.
- **The stage in the photo must match the stage that is eaten.** Unripe fruit, flowered-out woody
  stems or old fronds do not get the mark, even if they are the right organ. The harvest window
  (`months`, owner 12/10) already dates the collected part; a photo outside it is not used.
- **Only photos of the right species.** iNaturalist research grade, NZPCN, or the owner's own —
  the photos already shipped meet this. A photo whose identification is in any doubt is not marked.
- **Verified by the owner, every one.** Claude proposes; nothing ships until the owner has
  confirmed it in the editor (owner, 26/11). See *Decisions*.
- **A mark is not an identification.** The Edible parts strip sits below Identification and the
  lookalike cards, and on any entry with a lookalike card the strip carries one line: "Check the
  identification and lookalikes first."

## Model

`SpeciesPhoto` gains an optional list of marks:

```swift
public struct PhotoMark: Codable, Sendable, Hashable {
    /// The edible part this photo shows, in the words of `edibleParts.text`.
    public let part: String
    /// Ellipse around the part, in unit coordinates of the image (0…1, origin top-left).
    /// nil = the whole photo shows the part (a part photo, step 1).
    public let region: UnitRect?
    /// The use this mark belongs to (food, fibre, dye…), from `useful-plants.md`.
    public let use: UseKind
    /// false until the owner confirms it in the editor; Claude's proposals land as false.
    public let reviewed: Bool
}
```

- `marks` is omitted from the JSON when empty (`decodeIfPresent`), so the 2,044 existing photos
  keep their bytes; the `swiftjson.py` dumper must keep that true.
- **Drawn at run time, never burned into the HEIC.** The file stays the photographer's image; the
  app strokes the ellipse over it. That keeps one file per photo (no second marked copy in the
  bundle), lets the mark be edited without re-encoding, and keeps the licence simple: every shipped
  photo is CC0, CC BY or CC BY-NC (no ND, no SA today), which all allow adaptation with attribution,
  and the credit line on a marked photo adds "edible part marked by ForageNZ" as CC BY's
  "indicate if changes were made" asks. A future ND photo must not be marked (validation).
- Marks are part of the photo, so they follow it if it is reordered or re-captioned.

## Validation (`SpeciesValidation`)

Blocking:

- a mark on a `doNotEat` or `psychoactive` entry;
- a mark whose `part` does not appear in `edibleParts.text` (folded for case, macrons and hyphens,
  the same folding as search);
- a region outside 0…1 or with zero size;
- a mark on a photo whose credit is ND.
- a mark with `reviewed: false` on a non-draft entry.

Report only (`catalogue_report.py` gains an "Edible part photos" column):

- edible parts named in the text with no photo showing them — the to-do list for staging;
- an entry with marks on more than one photo for the same part (fine, but worth a look).

## App

- **Edible parts section:** a horizontal strip under the text, reusing the detail photo strip and
  the 64 MB decode cache (`7a778c8`). Each tile shows the photo, its marks, and the part label as a
  caption chip. Tapping opens the photo larger with the mark.
- **Mark style:** a 3 pt ellipse stroke in a fixed accent with a dark halo so it reads on pale
  flowers and dark leaves alike, light and dark mode. No fill — the part must stay visible.
- **Main photo strip:** shows the marks too (owner, 26/11), with the same style and label chip, so
  a marked photo looks the same wherever it appears.
- **VoiceOver:** "Photo, edible part marked: young stems." The label is the accessibility text.
- **Non-food uses:** this is built after `useful-plants.md`, so `PhotoMark` carries the use it
  belongs to (food, fibre, dye…) from the start, and a harakeke photo can mark the leaf used for
  weaving the same way. Validation then checks the label against that use's part text rather than
  only `edibleParts.text`.

## Editor (CatalogueEditor)

- Photos tab: select a photo, **Mark edible part**, drag an ellipse, pick the part from a menu of
  phrases taken from the entry's Edible parts text (free text allowed but validated as above).
  "Whole photo" makes a part photo with no region.
- The Safety tab's blocking list shows mark failures with the other edibility blockers.

## Content work

1. **Survey.** Script lists, per non-blocked entry, the parts named in Edible parts and the
   photos whose captions suggest them ("Ripe fruit", "Flower head", "Leafy shoots"…). Caption
   matching is a suggestion list for review, not a tag — nothing is written by the script.
2. **Part tags.** Group by group (memory: group-by-group review), confirm or reject each
   suggestion. Many entries already have the photo: captions today include Ripe fruit (9),
   Berries (6+), Flower/Flowers (90), Leaves/Leaf (114), Seeds (6), Leafy shoots (3).
3. **Missing parts.** Roots, young shoots and seeds are under-photographed. Stage them through
   the existing iNaturalist pipeline (research grade, open licence, captions per memory: photo
   caption style); never `--write` after review (memory: photo tool refetches). Owner photo
   curation stands — removed photos are not re-added for this.
4. **Marks.** Only where a part photo shows more than the part, or the part is small in frame.

## Tests

- `SpeciesValidationTests`: each blocking rule above, plus a valid mark passing.
- `CatalogueTests`: every shipped mark passes validation; JSON round-trip leaves unmarked photos'
  bytes unchanged.
- A snapshot or UI test of the Edible parts strip with one marked and one whole-photo tile.
- Targeted runs only while building; the full suite before push (memory: test scope).

## Decisions (owner, 26/11/2026)

1. **Claude proposes, the owner verifies every mark and tag.** Each proposal carries
   `reviewed: false` in the JSON; validation blocks shipping an unreviewed mark, and the editor's
   confirm button is the only thing that sets it. Owner: "unless there is a cheaper way that is as
   accurate". The cheaper way for **part tags** is the caption survey: where a photo's caption
   already names the part in the Edible parts text's own words ("Ripe fruit" against "ripe
   fruit"), the script proposes the tag without Claude looking at the photo. It is still only a
   proposal, so the owner's check stays; the saving is in proposing, not verifying. **Ellipses**
   have no cheaper route that is as accurate — they need someone looking at the photo — so Claude
   views each photo and proposes the region.
2. **Circles or part photos only:** decided during the build, once part photos are in use.
3. **Marks show on the main photo strip too**, not only in the Edible parts section.
4. **Poisonous-part marks:** out of this plan.
5. **Order:** after `useful-plants.md`, and only when the owner explicitly says to build.
