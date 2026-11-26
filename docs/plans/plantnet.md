# Plan: suggest a plant from a photo with Pl@ntNet

**Status:** draft, 26/11/2026. Nothing built. Waiting on the owner's answers to the open
questions at the end.

**History.** `docs/plans/ai-search.md` records "No photo identification" (owner, 16/10). The owner
asked for this plan on 26/11/2026, which reverses that call for plants only, on the condition that
the app warns hard that a photo match is not a trusted ID. Owner, 26/11: if this plan goes ahead,
the "no photo identification" constraint in `ai-search.md` is dropped (edit that plan when this
one is approved).

## ⚠️ The rule this has to fit: a photo match is never an identification

**Pl@ntNet is a guess from a picture. It is wrong often enough to kill someone who eats on it.**
Every screen this plan adds must say so, in words a tired person on a hillside cannot miss, and
nothing it adds may make eating easier to decide:

- **Do not eat anything you are not 100% sure of.** A Pl@ntNet match is a starting point for
  checking the page, never the check itself. If any doubt is left after working through the
  page's identification text and every lookalike card, do not eat it.
- **Deadly plants look like food in photos.** Hemlock, tutu, foxglove, ongaonga and
  celery-leaved buttercup are in the catalogue as "Do not eat", each with lookalike cards to
  edibles (wild carrot, cow parsley, elderflower, docks, nettle, celery). A photo can miss the
  very feature those cards tell you to check, and a high score does not change that.
- **Pl@ntNet says so itself:** its terms give results "without any warranty whatsoever" and take
  no responsibility for "the accuracy of the results obtained". The app inherits that, not the
  other way round.

How that is enforced in the design, not just in prose:

1. **Warning before the camera, every time.** The first screen is a full-page warning (above)
   with a button that reads "I understand — this is not an identification". No "don't show
   again". It is shown on every session that opens the identifier.
2. **Results never say "this is".** Rows read "Pl@ntNet suggests" with the score as a plain
   percentage and a fixed banner on the results list: "Suggestions only — not an ID. Check the
   page and every lookalike before you eat anything. If in doubt, leave it." The banner cannot be
   dismissed or scrolled away.
3. **No edibility on the results screen.** No "edible" badge, no edible parts, no recipes. The
   only caution shown is the catalogue's own *danger* badges ("Do not eat", "Psychoactive"),
   so a match never hides a warning.
4. **Lookalikes come first.** Opening a suggested entry from the identifier lands on its page
   with the lookalike cards expanded above edible parts, and a banner "You got here from a photo
   guess. Rule out every lookalike below." If any of the top results is a catalogue lookalike of
   another top result, the results screen says so in red: "Pl@ntNet can't tell these apart."
5. **Danger always wins.** If any result above a low floor (say 5%) is a "Do not eat" entry, a
   red banner leads the list: "One possible match is poisonous. Do not eat this plant on a
   photo match." This fires even when the top result is a safe edible.
6. **No confidence theatre.** No green ticks, no "high confidence" labels, no single "best match"
   hero card. Scores are shown as Pl@ntNet gives them, with "a score is not a probability that it
   is safe to eat" under them.
7. **Fungi are refused, not guessed.** Pl@ntNet identifies plants; it is not a mushroom
   identifier. The identifier says so before the camera, and if a result maps to a fungus entry
   (it should not) it is dropped. Seaweed is also refused until the owner decides otherwise.
8. **Nothing written by a model reaches a page** (README "Playbook"). Pl@ntNet's output is used
   only as a scientific name to look up a catalogue entry. Its common names, images and text are
   not shown, except the scientific name of a result with no catalogue entry, labelled "Not in
   this guide — do not eat it on Pl@ntNet's word."

Tests fail the build if any of the warning strings above go missing from the identifier screens,
the same way the safety copy is pinned elsewhere.

## Goal

Point the camera at a plant you have found and get up to five catalogue entries to check against,
each opening the page a person wrote. The guide stays the authority; Pl@ntNet only narrows where
to look.

## What Pl@ntNet offers (checked 26/11/2026)

- `POST https://my-api.plantnet.org/v2/identify/{project}?api-key=…`, multipart `images` (1–5
  photos of the same plant, JPEG/PNG, ≤ 50 MB total, shorter side resized to 1280 px, accuracy
  not guaranteed under 800×800), `organs` per image (`leaf`, `flower`, `fruit`, `bark`, `auto`),
  `nb-results`, `lang`, `no-reject`.
- Returns `results[]` sorted by `score` (0–1) with `species.scientificNameWithoutAuthor`,
  `commonNames`, `gbif.id`, `powo`; plus `predictedOrgans`, `version`,
  `remainingIdentificationRequests`. A non-plant photo returns 404 "Species not found".
- Free plan: 500 identifications a day, all features, commercial use allowed under the cap;
  "Powered by Pl@ntNet" appreciated, not required (pricing page). Terms say free use "might"
  acknowledge Pl@ntNet — we credit it anyway.
- Submitted photos are kept only in volatile memory during the request; the query's date, time
  and image URLs are logged for quotas.
- Returned reference images are Pl@ntNet content; showing them needs written permission. We do
  not show them.

## Can it run offline? No — checked 26/11/2026

The owner asked whether the network itself, not just the app, can be embedded so the identifier
works with no signal.

- **Pl@ntNet's own model cannot be embedded.** Its offline mode (Android 08/2022, iOS 3.16.0
  06/2023, 2025 model in 3.22.2) is a compressed copy of the server model, "exclusively available
  on the mobile application", needs a Pl@ntNet account, and its weights are not published.
  Sources: plantnet.org blog 18/10/2022, docs.plantnet.org "Install the offline/embedded mode".
- **The open Pl@ntNet-300K models are not fit for this guide.** They are trained on a 1,000-species
  research dataset. Checked against `species.json` (v2 `species_metadata.csv` from
  huggingface.co/PlantNet/plantnet-300k-v2-cnxb; v1 `plantnet300K_species_id_2_name.json` from
  huggingface.co/cpoisson/plantnet300k-resnet18):

  | | v2 (ConvNeXt/ViT, DINOv3 licence) | v1 (ResNet-18, Apache-2.0) |
  |---|---|---|
  | Catalogue non-fungus entries covered | 28 of 450 | 27 of 450 |
  | Native or endemic entries covered | 0 of 121 | 0 of 121 |
  | "Do not eat" entries covered | 5 of 111 | 5 of 111 |

  Both know wild carrot (*Daucus carota*) but **not hemlock** (*Conium maculatum*), and neither
  knows tutu, ongaonga, foxglove or celery-leaved buttercup. A closed-set classifier can only
  answer with a species it knows, so a hemlock photo would most likely come back as wild carrot.
  **Rejected on safety grounds, not only coverage.**
- **Only real offline path:** train our own model on NZ photos of the catalogue's species,
  including every "Do not eat" entry. Large, separate project; same rule applies — a species
  outside the model can never be ruled out. Not part of this plan.

### Other free, open models that run on the phone (checked 26/11/2026)

Owner asked for any free, open-source model fit for the purpose, iNaturalist's included.
Coverage = the entry's `scientificName` (first two words, folded) found in the model's label
list; script in the 26/11 session scratchpad (`cov.py`).

| Model | Licence | Taxa | Plants (of 450) | Native/endemic (of 139) | Do not eat (of 121) | Verdict |
|---|---|---|---|---|---|---|
| iNaturalist full model (app, Seek) | private | ~80k | — | — | — | Not released: trained on all-rights-reserved photos ([inaturalist/model-files](https://github.com/inaturalist/model-files)); only ~500-taxon sample models are public |
| Pl@ntNet-300K v2 | DINOv3 | 1,000 | 28 | 0 | 5 | Rejected (above) |
| PlantCLEF 2024 ViT-B DINOv2 (Pl@ntNet, Zenodo 10848263) | CC BY 4.0 | 7,806 SW Europe | 268 | 4 | 61 | Rejected: no tutu, ongaonga, karaka, mountain carrot, southern nettle |
| timm EVA-02 L iNat21 | CC BY-NC 4.0 | 10,000 | 281 | 49 | 57 | In the bake-off: NC is fine while the app stays free (below); closed set, misses 64 Do-not-eat entries |
| **BioCLIP 2** ([imageomics/bioclip-2](https://huggingface.co/imageomics/bioclip-2)) | **MIT** | **~862k (TreeOfLife-200M)** | **425** | **125** | **112** | **Only candidate** |

BioCLIP 2's misses are mostly naming: NZ beeches are in it as *Nothofagus* (the catalogue uses
iNaturalist's *Fuscospora*/*Lophozonia*), mower's mushroom as *Panaeolina foenisecii*. Truly
absent: *Caulerpa parvifolia*, *Populus candicans*, *Coprosma distantia* and a few others.

Why it could fit where the others can't: it is a CLIP model, so the app supplies the list of
names to choose between. The list would be **every wild NZ plant and fungus** (NZ Flora
checklist plus NZTCS), not only the catalogue, so a plant outside the guide gets its own name
instead of the nearest catalogue entry. Only the image encoder ships (ViT-L/14, about 300M
parameters: roughly 600 MB at 16-bit, 300 MB at 8-bit, Core ML on the Neural Engine); the names
are embedded once on the Mac and bundled (5,000 names × 768 numbers ≈ 8 MB). The older BioCLIP
(ViT-B/16, MIT, about a third the size) is the fallback if the app gets too big.

Not proven: the model card's 96.8% "PlantNet" zero-shot score is on a small benchmark label set,
not thousands of NZ names, and it warns that predictions lean toward well-photographed species
(NZ natives are not). Which model the app uses is decided by the bake-off below, not by these
coverage numbers.

**CC BY-NC and a free app (owner, 26/11: "this app is free").** NonCommercial means not
primarily for commercial advantage or money. A free app with no ads, in-app purchases,
subscriptions, sponsorship or paid tier fits that, so EVA-02 could ship with a credit line
(model, authors, licence, link) on the About screen. If the app ever earns money, the model
must be replaced or relicensed first. It is still not open source in the OSI sense, which is
why BioCLIP 2 (MIT) wins a tie.

## Model bake-off on random iNaturalist photos (owner, 26/11)

Before any app work, every candidate is run over the same random NZ photos and the best one for
this guide is chosen on the numbers. Runs on the Mac; nothing ships from it.

**Candidates.** Pl@ntNet API (online baseline, its 500/day free quota spread over days),
BioCLIP 2, BioCLIP (v1, the smaller fallback), PlantCLEF 2024 ViT-B, and EVA-02 iNat21 (CC BY-NC
4.0: can ship while the app is free, see below). BioCLIP models get the full NZ
wild flora and fungi name list (NZ Flora checklist plus NZTCS); closed-set models answer from
their own labels, and a species they don't know counts as a miss.

**Photos** (`Tools/model_bakeoff.py`, Python because it reaches the network, fixed random seed so
a run can be repeated):

- **Catalogue set:** for every catalogue entry, up to 10 random iNaturalist observations with
  `place_id` New Zealand, `quality_grade=research`, `captive=false`, photo licence CC0/CC BY/CC
  BY-NC/CC BY-SA, one photo per observation, at most two observations per observer so one
  photographer's style can't carry a species.
- **Not-in-guide set:** 500 random NZ wild plant and fungus observations of species with no
  catalogue entry. Tests whether a model matches a stranger to a guide entry, which is the
  dangerous failure.
- **Training leak:** BioCLIP 2's and EVA-02's training data include iNaturalist photos, so only
  observations created after each model's data cutoff are used; the cutoff dates are looked up
  and written into the report.
- Photos are downloaded to a gitignored cache for the run only and never bundled or committed;
  each result row keeps the observation URL, observer and licence.

**What is measured, per model:**

1. Top-1 and top-5 correct, overall, per app group, per origin (native/endemic vs introduced),
   and per entry.
2. **Deadly confusions:** a "Do not eat" photo whose top-1 is an edible entry, and an edible
   photo whose top-1 is a "Do not eat" entry, listed one by one (hemlock ↔ wild carrot, tutu ↔
   elderflower, foxglove ↔ broad-leaved dock, ongaonga ↔ nettle, celery-leaved buttercup ↔
   celery and every other catalogue lookalike pair).
3. **Strangers matched to the guide:** share of the not-in-guide set whose top-1 is a catalogue
   entry.
4. Score when wrong: how high the model's score runs on its wrong answers, to set the floors.
5. On-device cost for the local models: size at 8-bit and 16-bit, and time per photo on the
   owner's iPhone 13 Pro once converted to Core ML (winner only).

**Report:** `docs/model-bakeoff.md`, one table per measure plus the deadly-confusion list in
full, regenerated by the tool.

**Choosing.** The deadly-confusion count ranks first, strangers matched to the guide second,
top-1 on native/endemic third, overall top-1 fourth. A local model is chosen over the Pl@ntNet
API only if it is no worse on the first two. **If no model keeps deadly confusions to a
handful in the whole set, the identifier is not built**, whatever the other numbers say. The
owner reads the report and makes the call.

All the warning rules above apply to whichever model wins.

## The offline rule

The guide is offline first (README) and v1 makes no network calls. This feature needs the
network, so:

- It is the only network call in the app, behind its own entry point; everything else stays
  offline. With no signal the identifier says "Needs a connection — work through the page's
  identification text instead", and offers to keep the photo in Finds to try later.
- `NetworkLayerSPM` stays out; a single `URLSession` upload in its own small type is enough.
- The API key: Pl@ntNet's terms do not cover a key shipped in a binary. For a one-user app the
  owner's key in a gitignored `Secrets.xcconfig` is enough; anything wider needs a small proxy or
  Pl@ntNet's answer. Open question 3.

## Matching results to the catalogue

- Map `scientificNameWithoutAuthor` to entries by folded scientific name, then by GBIF id (add
  `gbifID` to entries via the existing tools, one lookup per entry, so renames and synonyms
  match). iNaturalist-style names stay as they are on the page (memory: prefer iNat names).
- A result in the same genus but not a catalogue species is shown as "Not in this guide" — never
  matched to a congener. Genus-level foods are not inferred from a photo.
- Drafts are not shown, as elsewhere.
- Results under a floor (Pl@ntNet's own scores drop fast; start at 10%, tune on the owner's
  photos) are hidden behind "Show weaker guesses", except for "Do not eat" entries, which the
  danger rule above shows down to 5%.

## Screens

1. **Entry point:** a "Suggest from a photo" button on the Field guide tab (not the Safety tab,
   not the Finds tab).
2. **Warning page** (rule 1), naming fungi and seaweed as out of scope.
3. **Capture:** camera or library, 1–5 photos, organ picker per photo (defaults to `auto`), a hint
   that a flower or fruit plus a leaf works better than one leaf.
4. **Results:** fixed banner, danger banner if any, lookalike-pair warning if any, then rows:
   catalogue photo, name, scientific name, Pl@ntNet score, danger badge if any. "Not in this
   guide" rows below. "Powered by Pl@ntNet" footer.
5. **Species page from a suggestion:** banner + lookalikes first (rule 4).
6. **Optional:** "Save to Finds" keeps the photo and the suggested names, marked "unconfirmed
   photo guess", never "identified".

## Privacy

Photos leave the phone only on a tap of "Ask Pl@ntNet", stripped of location and EXIF first.
Nothing else is sent. The warning page says photos are sent to Pl@ntNet in France. The README
gains a Network and privacy note.

## Tests

- Unit: response decoding (fixture JSON, including 404 and 429), name and GBIF matching, the
  floors, the danger-wins rule, the lookalike-pair rule, fungus results dropped, EXIF stripped.
- Copy pinning: every warning string in rules 1–8 present on its screen.
- UI test with a stubbed client: warning shown each launch of the identifier and cannot be
  skipped; banner present on results; a poisonous low-score result produces the red banner.
- No test calls the live API.

## Steps

1. Owner answers the open questions.
2. Model bake-off (above); owner picks the model or stops here.
3. Add `gbifID` to entries (tool round, no prose touched).
4. Client, matcher and rules with unit tests against fixtures.
5. Screens with the copy above; owner reviews the wording before anything else.
6. Owner tries it on real plants, including the catalogue's own lookalike pairs (hemlock / wild
   carrot / cow parsley, tutu / elderflower, foxglove / broad-leaved dock, ongaonga / nettle,
   celery-leaved buttercup / celery), and records misses in this
   plan. If it routinely puts a safe edible above its deadly lookalike, the feature does not
   ship.

## Open questions for the owner

1. Plants only, or seaweed as well? (Fungi stay out either way.)
2. Score floors: 10% to show, 5% for "Do not eat" — or other numbers after trying it?
3. API key: owner's own key in a gitignored config, fine for one user?
4. Save unconfirmed photo guesses to Finds, or keep the identifier separate from Finds?
5. Any extra wording you want in the warning page?
