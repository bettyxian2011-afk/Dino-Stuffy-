# Iteration 7 — Identify & Species Facts Roadmap

Versioned plan to turn Strata’s mock Identify path into a reliable **photo → ranked fossil match → species facts** experience. This expands Iteration 7 from [app-development-plan.md](./app-development-plan.md), prioritizing Identify and species facts first.

**Versions:** 0.1 → 0.2 → … → 1.0  
Each version adds **one feature**, is **fully tested**, and **builds on** the previous version.

---

## Goal

Ship a demoable end-to-end flow:

1. Open Identify (Scan FAB / Scan now)
2. Capture or pick a fossil photo
3. Get ranked genus candidates with confidence
4. Open a species profile with real Paleobiology Database (PBDB) facts

## Non-goals (this roadmap)

Leave these for later phases (see main plan out-of-scope):

- Dig Map / Camp Prep
- Deep Time timeline
- Museums detail
- At Risk conservation explorer
- Live Translate API
- Auth / Sign in
- In-app live camera preview / Live ID streaming

---

## Current architecture (starting point)

Do **not** restart Identify from scratch. Build on existing code:

| Piece | Location |
| ----- | -------- |
| Capture UI | `dino_app/lib/screens/identify/identify_screen.dart` |
| Image handoff | `dino_app/lib/models/captured_specimen.dart` |
| Identify API | `IdentifyRepository.identify(bytes)` |
| Mock adapter | `MockIdentifyRepository` |
| Live adapter | `GeminiIdentifyRepository` + `GeminiVisionService` |
| Catalog | `IdCatalog` ← `assets/data/id_results.json` |
| Taxon API | `TaxonRepository` / `PbdbTaxonRepository` |
| DI / switch | `StrataServices` + `StrataConfig` (`GEMINI_API_KEY`) |
| Result UI | `IdResultScreen` |
| Profile UI | `SpeciesProfileScreen` (stub today) |

```mermaid
flowchart TD
  Capture[Identify capture or gallery] --> Bytes[CapturedSpecimen bytes]
  Bytes --> Repo[IdentifyRepository]
  Repo -->|no API key| Mock[MockIdentifyRepository]
  Repo -->|GEMINI_API_KEY set| Gemini[GeminiIdentifyRepository]
  Gemini --> Vision[GeminiVisionService]
  Gemini --> Catalog[IdCatalog]
  Gemini --> Taxon[TaxonRepository PBDB]
  Mock --> Result[IdResultScreen]
  Gemini --> Result
  Result --> Profile[SpeciesProfileScreen]
  Profile --> Taxon
```

**Priority order:** Identify reliability → catalog → result UX → species profile → open-world match → capture polish → persistence → v1.0 milestone.

---

## Version summary


| Version | Feature | Status | Builds on | Tests | Done when |
| ------- | ------- | ------ | --------- | ----- | --------- |
| **0.1** | Live Identify smoke path | **Completed** | Iteration 6 capture + Gemini wiring | Unit: mock identify + adapter select | Live Gemini adapter loads with key |
| **0.2** | Expand curated catalog | **Completed** | v0.1 | Unit: `IdCatalog.load` | ~20–30 preferred genera |
| **0.3** | Identify result resilience | **Completed** | v0.2 | Widget: success + failure + retry | Retry works; no dead-end errors |
| **0.4** | Species profile from PBDB | **Completed** | v0.3 | Fixture + fake repo screen | Profile shows real PBDB fields |
| **0.5** | Taxonomy + facts merge | Pending | v0.4 | Unit: PBDB → facts mappers | Out-of-catalog matches still show facts |
| **0.6** | Open-world match quality | Pending | v0.5 | Heuristics + JSON parser tests | Non-catalog taxa still rank + enrich |
| **0.7** | Capture reliability | Pending | v0.6 | Manual emulator checklist | Gallery works when camera fails |
| **0.8** | Persist recent IDs | Pending | v0.7 | Persistence round-trip | Home shows real recent matches |
| **0.9** | Quality gates | Pending | v0.8 | Full `flutter test` suite | Identify/species well covered |
| **1.0** | Milestone: photo → match | Pending | v0.9 | Demo script + runbook | Identify + species facts declared done |


```mermaid
flowchart LR
  v01[v0.1 Live smoke] --> v02[v0.2 Catalog]
  v02 --> v03[v0.3 ID UX]
  v03 --> v04[v0.4 PBDB profile]
  v04 --> v05[v0.5 Taxonomy facts]
  v05 --> v06[v0.6 Open match]
  v06 --> v07[v0.7 Capture]
  v07 --> v08[v0.8 Recents]
  v08 --> v09[v0.9 Quality]
  v09 --> v10[v1.0 Milestone]
```

---

## Version 0.1 — Live Identify smoke path — completed

### Feature

Documented, reliable Gemini on/off path so the app clearly uses live vision when a key is present.

### Tasks

- [x] Confirm `flutter run --dart-define=GEMINI_API_KEY=...` selects `GeminiIdentifyRepository` in `StrataServices`
- [x] Confirm missing key falls back to `MockIdentifyRepository` (no crash)
- [x] Document the run command in README + this runbook
- [x] Add unit test for `MockIdentifyRepository.identify` (deterministic canned result)
- [x] Startup `debugPrint` shows which adapter is active
- [x] Local `run_live.local.ps1` (gitignored) for key without committing secrets

### Files touched

- `dino_app/lib/data/strata_services.dart`
- `dino_app/test/identify_repository_test.dart`
- `dino_app/README.md`
- `dino_app/.gitignore` (`*.local.ps1`, `.env*`)

### Tests

| Type | What |
| ---- | ---- |
| Unit | `MockIdentifyRepository.identify` returns a valid `IdResult` |
| Unit | `buildIdentifyRepository` selects Mock vs Gemini from key flag |
| Manual | With key → pick photo → candidates from live vision |

### Done when

A teammate can run with a Gemini key and get non-mock genera from a real fossil photo.

---

## Version 0.2 — Expand curated fossil catalog — completed

### Feature

Grow the local catalog so Gemini’s “prefer these genera” list is useful (~20–30 common fossil genera).

### Tasks

- [x] Expand `assets/data/id_results.json` (ammonites, trilobites, plants, vertebrates, etc.)
- [x] Ensure `IdCatalog` indexes every candidate genus
- [x] Keep thumbnails/tips/facts coherent (reuse assets where needed)
- [x] Add unit test for `IdCatalog.load` genus count + `entryFor('Dactylioceras')`

### Files touched

- `dino_app/assets/data/id_results.json` (10 curated result groups → 30 genera)
- `dino_app/test/id_catalog_test.dart`

### Tests

| Type | What |
| ---- | ---- |
| Unit | `IdCatalog.load` genus count ≥ 20; `entryFor('Dactylioceras')` non-null |
| Unit | Catalog spans ammonites, trilobites, plants, vertebrates, brachiopods, corals |

### Done when

The vision prompt receives a meaningful preferred genus list (not just two or three names).

---

## Version 0.3 — Identify result resilience — completed

### Feature

Harden ID Result for loading, error, and retry so flaky networks never leave a dead screen.

### Tasks

- [x] Improve `IdResultScreen` loading copy/indicator
- [x] Error state with **Retry** that re-calls `identify` / `getMockResult`
- [x] Avoid re-creating `Future` on every rebuild (stateful future + explicit retry)
- [x] Widget tests: fake repo success → genus; failure → retry succeeds

### Files touched

- `dino_app/lib/screens/id_result/id_result_screen.dart`
- `dino_app/test/id_result_screen_test.dart`

### Tests

| Type | What |
| ---- | ---- |
| Widget | Fake repo success → shows genus |
| Widget | Fake repo failure → error + retry succeeds |

### Done when

Failed network never dead-ends; retry restores a result screen.

---

## Version 0.4 — Species profile from PBDB — completed

### Feature

Replace the stub species profile with live `TaxonRepository.findTaxon` data.

### Tasks

- [x] Expose `TaxonRepository` from `StrataServices`
- [x] Load name, rank, age range, occurrence count on `SpeciesProfileScreen`
- [x] Loading / error / empty states matching Strata theme
- [x] Keep navigation from ID Result **View full profile**
- [x] Fix `PbdbTaxon.fromJson` for numeric PBDB rank codes
- [x] Fixture + fake repo profile tests

### Files touched

- `dino_app/lib/data/strata_services.dart`
- `dino_app/lib/screens/id_result/species_profile_screen.dart`
- `dino_app/lib/models/pbdb_taxon.dart`
- `dino_app/test/species_profile_test.dart`
- `dino_app/test/fixtures/pbdb_dactylioceras.json`

### Tests

| Type | What |
| ---- | ---- |
| Unit | `PbdbTaxon.fromJson` with fixture JSON |
| Widget | Fake `TaxonRepository` → profile shows fields; loading/error/empty states |

### Done when

View full profile shows real PBDB fields for a known genus (e.g. *Dactylioceras*).

---

## Version 0.5 — Taxonomy + facts on profile and result

### Feature

Use PBDB parent chain for taxonomy breadcrumbs; merge PBDB attrs into ID Result quick-facts when catalog facts are missing.

### Tasks

- Call `getTimelineChain` for hierarchy chips on profile (and optionally ID Result)
- Add mapper helpers: PBDB → `List<TaxonFact>` / taxonomy labels
- On `GeminiIdentifyRepository` (or result assembly), fill facts from PBDB when catalog entry is absent

### Files likely touched

- `dino_app/lib/data/repositories/gemini_identify_repository.dart`
- `dino_app/lib/data/repositories/taxon_repository.dart`
- New helper e.g. `dino_app/lib/data/services/taxon_fact_mapper.dart`
- `dino_app/lib/screens/id_result/species_profile_screen.dart`
- `dino_app/lib/screens/id_result/id_result_screen.dart`

### Tests

| Type | What |
| ---- | ---- |
| Unit | Mapper: PBDB record → facts/taxonomy chips |

### Done when

Out-of-catalog best matches still show useful era/location-style facts when PBDB provides them.

---

## Version 0.6 — Open-world match quality

### Feature

Improve “any fossil” matching so genera outside the local JSON are first-class.

### Tasks

- Tune `GeminiVisionService` prompt for open-set suggestions + catalog preference
- Adjust `IdentificationHeuristics` (catalog hit, PBDB hit, occurrence boost)
- Drive tip callout from high / medium / low confidence bands
- Harden Gemini JSON parsing edge cases (markdown fences, empty list)

### Files likely touched

- `dino_app/lib/data/services/gemini_vision_service.dart`
- `dino_app/lib/data/services/identification_heuristics.dart`
- `dino_app/lib/data/repositories/gemini_identify_repository.dart`
- `dino_app/test/` heuristics + parser tests

### Tests

| Type | What |
| ---- | ---- |
| Unit | Heuristics confidence adjustments |
| Unit | Parser accepts messy / fenced JSON |

### Done when

Photos of taxa absent from local JSON still return ranked candidates with PBDB enrichment.

---

## Version 0.7 — Capture reliability (Android emulator + device)

### Feature

One capture UX improvement: when camera fails, offer a clear **Pick from library** path (no full live preview).

### Tasks

- On camera error, show snackbar/dialog with gallery action
- Permission-denied messaging
- Keep web on gallery path (`kIsWeb`)
- Document emulator AVD camera vs gallery workaround

### Files likely touched

- `dino_app/lib/screens/identify/identify_screen.dart`
- This roadmap runbook (emulator notes)

### Tests

| Type | What |
| ---- | ---- |
| Manual | Emulator: camera fail → gallery → ID Result |
| Optional unit | Error-branch helper strings / flags |

### Done when

A Pixel emulator can complete Identify → Result via gallery even when the AVD camera is broken.

---

## Version 0.8 — Persist recent real identifications

### Feature

Save the last N successful identifications so Home “Recently identified” reflects real sessions.

### Tasks

- Persist compact records (genus, confidence, era label, thumbnail path or small bytes)
- Update `MockFossilRepository` / Home to read persisted list with mock fallback
- Cap list size (e.g. last 10)

### Files likely touched

- New: e.g. `dino_app/lib/data/repositories/recent_identification_store.dart`
- `dino_app/lib/screens/home/home_screen.dart`
- `dino_app/lib/data/repositories/fossil_repository.dart`
- `dino_app/lib/screens/id_result/id_result_screen.dart` (write on success)
- `pubspec.yaml` if adding `shared_preferences`

### Tests

| Type | What |
| ---- | ---- |
| Unit | Save → load round-trip; cap at N |

### Done when

After identifying a photo, Home shows that match without only hardcoding mock Velociraptor / Dactylioceras.

---

## Version 0.9 — Quality gates before milestone

### Feature

Confidence-threshold UX, documented failure modes, and a solid automated suite.

### Tasks

- Surface low-confidence tips consistently on ID Result
- Confirm `ImageCompressor` limits are applied on the live path
- Expand tests (catalog, heuristics, mock identify, profile mappers, persistence)
- Document quota / offline / invalid key failure modes in this file

### Files likely touched

- `dino_app/test/**`
- ID Result tip logic
- This roadmap (failure modes section)

### Tests

| Type | What |
| ---- | ---- |
| Gate | `flutter test` green; Identify/species coverage beyond onboarding-only |

### Done when

Local CI-style test suite meaningfully covers the Identify and species path.

---

## Version 1.0 — Milestone: photo → ranked fossil match

### Feature

End-to-end polish and declaration that Iteration 7 **Identify + species facts** is complete.

### Tasks

- Walk the demo script below on emulator and/or device
- Finalize runbook
- Update [app-development-plan.md](./app-development-plan.md) Iteration 7 status/notes
- Explicitly leave Sites / Translate API / Auth for later phases

### Done when

Demo script succeeds: open app → Scan → capture/pick any fossil photo → ranked candidates → View full profile with PBDB facts.

### Demo script

1. `flutter run --dart-define=GEMINI_API_KEY=<key> -d <device>`
2. Get Started → Home → Scan FAB
3. Prefer **Library** on emulator if camera fails; otherwise shutter
4. Confirm ID Result shows ranked candidates + confidence
5. Tap **View full profile** → PBDB-backed facts visible
6. Return Home → recent identification includes the new match (after v0.8+)

---

## Test strategy


| Layer | Use for | Examples |
| ----- | ------- | -------- |
| **Unit** | Repos, parsers, heuristics, mappers, persistence | No network; fixture JSON |
| **Widget** | ID Result / Profile loading & error UI | Fake repositories |
| **Manual** | Gemini live calls, emulator camera/gallery, demo script | Real device or AVD |

**Rule:** every version merges only when its listed tests pass.

---

## Failure modes (document fully by v0.9)


| Situation | Expected behavior |
| --------- | ----------------- |
| No `GEMINI_API_KEY` | Mock identify; app still demoable |
| Invalid / quota key | Error UI + retry; optional mock fallback message |
| Offline | Error UI; retry when back online |
| Camera unavailable | Gallery fallback (v0.7+) |
| Genus not in catalog | Still show Gemini + PBDB enrichment (v0.5–0.6) |
| Genus not in PBDB | Show model result; facts may be thinner |

---

## Runbook (draft — finalize in v1.0)

```bash
# Mock path (no key)
cd dino_app
flutter run

# Live Identify (v0.1+)
flutter run --dart-define=GEMINI_API_KEY=your_key_here

# Optional model override
flutter run --dart-define=GEMINI_API_KEY=your_key_here --dart-define=GEMINI_MODEL=gemini-3.6-flash
```

**Never commit API keys.** Pass them only via `--dart-define`, a gitignored `run_live.local.ps1`, or CI secrets.

On launch, check the debug console for:

- `StrataServices: GeminiIdentifyRepository (live vision)` — live path
- `StrataServices: MockIdentifyRepository (no GEMINI_API_KEY)` — mock path

**Android emulator camera:** if shutter fails, use Library / gallery (v0.7 makes this explicit). Enable AVD virtual camera under Device Manager if you want system camera.

---

## Out of scope pointer

Broader product deferrals (At Risk tab, Dig Map, Deep Time, Museums, auth, live Translate) remain listed under **Out of scope** in [app-development-plan.md](./app-development-plan.md). This roadmap only completes Iteration 7’s **Identify** and **species facts** slice.
