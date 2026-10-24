# WWDC26 framework ideas — ForageNZ

Source: https://blog.eidinger.info/all-new-frameworks-presented-at-wwdc26 (frameworks announced 08/06/2026). Verify the API docs before starting — the source gives one line per framework.

Constraint: the app never claims to identify anything. Every idea below must respect that.

## FoundationModels — on-device, so offline-safe
- Q&A over the bundled catalogue ("what's in season on the coast in October?") using tool calling against `SpeciesRepository`.
- Ground every answer in catalogue data; never let the model state what a plant is or that something is safe to eat.

## Evaluations
- Eval set that checks AI output never makes identification or safety claims, and only cites catalogue facts. Required before shipping any AI text.

## MediaIntelligence (use with care)
- Only for organising the user's own photos (e.g. grouping a session's shots), never for identification.

## App Intents + AppIntentsTesting
- "What's in season now" intent and species as `AppEntity` for Spotlight; AppIntentsTesting to cover them.
