Identification photos, one directory for the whole catalogue.

Files are named `<species-id>-<n>.heic` and referenced by name from `species.json`.
Add them through the CatalogueEditor scheme rather than by hand: it downscales to
1400px, re-encodes as HEIC, and records the caption and credit that the licence and
the app both require.

These ship inside the app, so `PhotoAuditTests` enforces a per-photo ceiling and a
total budget. `swift run catalogue-tool --photos` reports the current usage.
