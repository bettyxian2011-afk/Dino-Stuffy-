# Iteration 8 v0.3 — Identify reads Firestore (cloud first)

Handoff plan for wiring Strata’s Identify pipeline so fossil knowledge comes from **Cloud Firestore** (`dino-app-90aa2`), not from treating local JSON as the live source of truth.

See also: [iteration-8-firestore-roadmap.md](./iteration-8-firestore-roadmap.md) (Version 0.3, “How algorithms use `taxa`”).

---

## Hard constraints (do not violate)

1. **Do not write to Firestore.** No `upload.mjs`, no Admin SDK writes, no console edits, no `set` / `update` / `delete` on any collection.
2. **Do not modify local taxa/periods data files**, including:
   - `dino_app/assets/data/taxa.json`
   - `dino_app/assets/data/periods.json`
   - `seed/curated/taxa.json`
   - `seed/curated/periods.json`
   - Do not run `seed/build.mjs` or `seed/export.mjs` unless the user explicitly asks later.
3. **Firestore is the source of truth** for taxon facts when available. Local bundled JSON is **offline / empty-cloud fallback only**, not something to “fix” from the DB in this task.
4. **Do not change Identify confidence / heuristic scoring rules** in this version (roadmap v0.3).
5. **Do not commit secrets.** `lib/firebase_options.dart`, `google-services.json`, service-account JSON, and Gemini keys stay gitignored / out of band.
6. Prefer minimal, focused code changes. Match existing patterns in `dino_app/`.

---

## Context to read first

- `docs/iteration-8-firestore-roadmap.md` — Version 0.3, “How algorithms use `taxa`”, access rules
- Models: `dino_app/lib/models/fossil_taxon.dart`, `geologic_period.dart`
- Loaders: `dino_app/lib/data/catalog/id_catalog.dart`, `knowledge_assets.dart`
- Identify path: `gemini_identify_repository.dart`, `identification_heuristics.dart`, `strata_services.dart`, `firebase_bootstrap.dart`
- Tests: `test/id_catalog_test.dart`, `test/identify_repository_test.dart`, `test/knowledge_seed_test.dart`, `test/firebase_bootstrap_test.dart`

---

## What to implement

### 1. `FossilKnowledgeRepository` interface

Name can match repo style. At least:

- get / watch a taxon by id
- `taxaForIdentify()` → docs with `useInIdentify == true`
- `iconicForPeriod(periodId)` (shape for Deep Time later)
- `kidPool(realm, periodId)` (query shape only; Kids Mode later)

### 2. Two implementations

- **Firestore** (read-only): query `taxa` (and periods only if needed for the API shape). Use the already-initialized Firebase app from `FirebaseBootstrap` / `StrataServices` when `isFirebaseReady`.
- **Asset / bundled**: read existing `KnowledgeAssets` / `assets/data/taxa.json` — **read only, no file writes**.

### 3. Merge into the catalog Identify already uses

`IdCatalog` / `GeminiIdentifyRepository`:

- When Firestore returns identify taxa, **merge by genus**.
- **Cloud wins** for `facts`, `taxonomy`, `family`, `commonGroup` when present.
- Local JSON may fill gaps (thumbnails, tips, etc.) when cloud fields are missing.
- If Firestore errors, times out, or Firebase is not configured → behavior matches **end of Iteration 7 / current local Identify** (no crash).

### 4. Wire through `StrataServices.init`

Screens keep using repositories; don’t call Firestore from UI widgets directly.

### 5. Tests (required by roadmap v0.3)

- Unit: offline / no-Firebase fallback still works.
- Unit: when a cloud taxon is supplied (mock/fake repository is fine — **do not hit production DB in tests**), fact fields come from that cloud doc.
- Do not require network or real credentials in CI tests.

---

## Done when

- With Firebase disabled / offline / empty read failure: Identify still returns the same *shape* of result as today (local path).
- With Firebase ready and a cloud taxon available: Identify uses **cloud** `facts` / taxonomy / family / commonGroup for that genus.
- No Firestore writes occurred; local `taxa.json` / curated seed files unchanged.
- `flutter test` for the touched Identify / knowledge tests passes.

---

## Out of scope

- Deep Time UI (v0.5), Auth (v0.4), rules (v0.6), museums, Kids Mode
- Re-seeding or “fixing” local JSON from the DB
- Changing Gemini prompts beyond what’s needed to consume the merged catalog
- Committing `firebase_options.dart` or any keys

---

## Working notes

- Project id: `dino-app-90aa2`. Client config is local via `flutterfire configure` (gitignored).
- The team manually corrected many taxa ages **in Firestore**; those corrections must be what Identify sees when online. Do not overwrite them from local files.
- If you need to inspect cloud data while coding, **read-only** gets only; prefer fakes in unit tests.
