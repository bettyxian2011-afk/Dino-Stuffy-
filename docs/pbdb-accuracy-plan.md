# Prompt: Improve PBDB / Macrostrat seed accuracy for new species profiles

Handoff for continuing work on `seed/build.mjs` (and related age logic) so **new** taxa and periods pulled from PBDB (and Macrostrat) land closer to curated scientific ranges — matching the quality of the hand-reviewed Firestore catalog.

**Related docs:** [iteration-8-firestore-roadmap.md](./iteration-8-firestore-roadmap.md), [iteration-8-v0.3-identify-firestore.md](./iteration-8-v0.3-identify-firestore.md).

**Branch:** `feat/seed-age-accuracy` (do not push/merge without asking). Designed to merge cleanly with parallel ICS Deep Time timeline work from [stratigraphy.org](https://stratigraphy.org/).

---

## Status (feat/seed-age-accuracy)

| Deliverable | State |
| ----------- | ----- |
| Gold fixture `seed/fixtures/gold-ages.json` | Done (10 genera from 2026-10-17 Firestore manual snapshot + Hell Creek peers) |
| Offline helpers `seed/lib/ages.mjs` + `npm run test-ages` | Done |
| `periodIds` + schedule `TaxonFact` always from final ages | Done (`syncScheduleFact`) |
| Curated manual ages in `seed/curated/taxa.json` | Done for gold set |
| Apply without network / Firestore: `npm run apply-ages` | Done |
| Eval: `npm run eval-ages` | **10/10 within ±2 Ma** after apply |
| ICS period pin `seed/fixtures/ics-periods-2024-12.json` | Done (blurbs stay curated; schema unchanged for ICS student merge) |
| Identify prefers catalog ages over live PBDB | Done (asset `taxa.json` merged into IdCatalog; facts beat PBDB chips) |
| Species profile prefers catalog ages | Done (`FossilKnowledgeRepository`) |
| Firestore upload / overwrite | **Not done (by design)** |

Before gold apply, local rebuild ages were wide envelopes (e.g. *Triceratops* 83.6–64.9 → `cretaceous,paleogene`). After curated ages: 68–66 → `cretaceous` only; schedule fact `68–66Ma`.

---

## Hard constraints

1. **Firestore is the source of truth** for already-reviewed taxa/periods. Do **not** upload local rebuilds over Firestore without an explicit user request.
2. **Do not write to Firestore** unless the user asks. Prefer read-only inspection.
3. **Do not overwrite** hand-corrected cloud data by running `upload.mjs` blindly.
4. When changing the seed algorithm, preserve the ability to set **manual** `ageStartMa` / `ageEndMa` in `seed/curated/taxa.json` and to honor `reviewed: true` (build/upload skip reviewed docs).
5. No committing Firebase client keys, service-account JSON, or Gemini keys.

---

## Shared source of truth (non-negotiable)

One curated catalog drives ages **everywhere** the app shows taxa:

1. **Deep Time** — `iconicForPeriod` / `periodIds`
2. **Identify / species profile** — facts & age chips from `FossilKnowledgeRepository` / merged IdCatalog, **not** raw live PBDB appearance when a catalog taxon exists
3. **Kids Mode (future)** — `kidPool(realm, periodId)` and any quiz content that filters on `periodIds` + ages

Wrong Deep Time placements are **data** (wide PBDB/Macrostrat ages → too many `periodIds`), not the timeline UI. Fixing seed/catalog fields fixes all three consumers because they share `taxa/{id}` (cloud) and `assets/data/taxa.json` (fallback).

Rules:

- Final `ageStartMa` / `ageEndMa` prefer manual curated / gold
- `periodIds` **ALWAYS** recomputed from those final ages
- Schedule `TaxonFact` **ALWAYS** regenerated from those ages + periods
- `iconic` / `kidSafe` / `realm` stay curated; do not invent Kids UI here
- No second parallel age system for Identify vs Deep Time vs Kids

### Merge notes for parallel ICS timeline work

- Taxon age pipeline owns **taxon** ages, `periodIds`, and schedule facts.
- Period **boundaries** are pinned via `seed/fixtures/ics-periods-2024-12.json`; blurbs stay in `seed/curated/periods.json`.
- Period document **schema** is unchanged (`name`, `era`, `startMa`, `endMa`, `blurb`, `order`, `color`, `pbdbIntervalId`) so a student ICS/Deep Time branch can enrich timeline UI without fighting this branch.
- `periodIdsFor(start, end, periods)` is a pure overlap — if ICS ages shift slightly, rebuild/apply recomputes membership.

---

## Snapshot (read-only pull, 2026-10-17)

Compared **Firestore** (student hand-updated) vs **local** `dino_app/assets/data/*.json` (last `seed/build.mjs` output).

| Collection | Count (both sides) | Age identical | Notes |
| ---------- | ------------------ | ------------- | ----- |
| `taxa` | 33 | **1** of 33 | 32 ages differ; student corrections are tighter / textbook ranges |
| `periods` | 12 | **5** of 12 ages exact | Rest differ by **&lt; ~2 Ma** (ICS chart rounding). **Blurbs identical.** |

`reviewed: true` was still **0** on all taxa in Firestore at pull time — recommend setting it on finished docs so future uploads cannot clobber them.

### Taxa: what the student fixed (patterns the algorithm must learn)

Local rebuild often kept **wide certain-occ / Macrostrat envelopes**. Firestore manual ages are typically **narrower and formation-aware**.

Examples (local rebuild → Firestore manual):

| Genus | Local (build) | Firestore (manual) |
| ----- | ------------- | ------------------ |
| *Triceratops* | 83.6–64.9 | **68–66** |
| *Tyrannosaurus* | 83.6–64.9 | **68–66** |
| *Ankylosaurus* | 72.2–63.5 | **70–66** |
| *Velociraptor* | 83.6–72.2 | **75–71** |
| *Otodus* | 83.6–0 | **65–3.6** |
| *Carcharodon* | 59.2–0 | **20–0** |
| *Glossopteris* | 358.9–201.4 | **300–252** |
| *Dactylioceras* | 201.4–161.5 | **190–174** |
| *Elrathia* | 509.7–486.9 | **507–505** |

Field-level churn vs local (how often Firestore differed): `ageStartMa`/`ageEndMa` (~28), `facts` (23), `periodIds` (14), plus seed metadata (`ageSource`, `ageEnvelope`, `ageCore`, `pbdb`).

**Fixed in tooling:** schedule facts and `periodIds` are always regenerated from the final age range (`syncScheduleFact` / `apply-catalog-ages.mjs`).

### Periods: already quite accurate

Local assets match ICS 2024-12 pin. Firestore vs ICS differs only slightly (rounding / older chart). **Do not aggressively rewrite period blurbs.** Prefer the cited ICS fixture; PBDB intervals are a cross-check for `pbdbIntervalId` / color only.

---

## Goal

Improve the **ingest algorithm** so when we add **new** genera (species profiles / taxon docs):

1. Age ranges are closer to curated paleontology (not raw PBDB genus-summary or single-outlier envelopes).
2. `periodIds` are derived from the **final** age range.
3. Schedule `facts` match that final range.
4. Period seed stays stable and ICS-accurate.
5. A review report flags genera that still need a human (large envelope↔core gap, sole-formation edges, living taxa with deep deep-time starts, etc.).

This is about **`seed/build.mjs`**, Macrostrat usage, curated overrides, and reporting — **not** about re-pushing the existing 33 taxa over the student’s Firestore edits.

---

## Known failure modes (already diagnosed)

1. **PBDB genus `fea`/`lla`** includes uncertain IDs (`?`, `cf.`) and old synonymy → start dates too old (*Ankylosaurus* 83.6 from one `?` record).
2. **Coarse chronostrat bins** (e.g. “Late Campanian” stored as full 83.6–72.2) push edges older/younger than formation truth.
3. **Macrostrat** can help but also returns wrong/fuzzy formation matches or ages younger than K–Pg; must only apply when overlapping PBDB and **not wider**.
4. **Long-ranging or extant genera** (*Otodus*, *Carcharodon*, *Isurus*) need special handling (often manual or “core species” / common-name scoped ranges).
5. **Outlier trim** helps (*Albertosaurus*) but is not enough alone for Campanian Laramidia dinosaurs still sitting at 83.6.

Current pipeline: certain occs, percentile trim (large n), stronger multi-formation edges, Macrostrat (capped), K–Pg young-edge clamp, dual envelope/core, `ageSource`, `reviewed` skip, always sync facts/`periodIds`. **Extend it; don’t throw it away.**

---

## Implementation map

### A. Gold set (read-only)

1. `seed/fixtures/gold-ages.json` — committed `{ id → ageStartMa, ageEndMa }` from Firestore manual snapshot (+ Hell Creek peers).
2. `npm run eval-ages` — MAE / ±2 / ±5 vs bundled `taxa.json` (no Firestore at test time).
3. Extend gold via read-only `export.mjs` when more genera are reviewed.

### B. Age algorithm for new taxa

1. Certain-only occurrences; percentile trim when n≥20; large samples need ≥2 formations on an edge.
2. Macrostrat exact-name match only when overlapping and not wider; clamp lone post–K–Pg young edges.
3. After final ages, **always** `periodIds` + schedule fact sync.
4. Extant / `ageEndMa ≈ 0` with deep starts → attention report (prefer manual).
5. Curated overrides: `seed/curated/taxa.json` → `ageSource: "manual"`.

### C. Periods

1. Pin Phanerozoic boundaries to ICS 2024-12 fixture.
2. PBDB `intervals` only for `pbdbIntervalId` / color / era name.
3. Blurbs under curated control (`seed/curated/periods.json`).

### D. New species profile checklist

1. Add curated row (realm, names, identify flags, optional manual ages).
2. Run `npm run build` (or `apply-ages` if only ages changed); read the attention report.
3. If gap > 5 Ma or extant/long-ranging: set manual ages from a cited source.
4. Confirm `periodIds` and schedule fact match (`npm run eval-ages` if gold-listed).
5. Upload **only that doc** or upload with `reviewed` protection — **only when asked**.
6. Set `reviewed: true` in Firestore after human OK.

### E. Identify / profile (done on this branch)

- `StrataServices` merges bundled `taxaForIdentify()` into IdCatalog before optional Firestore overlay.
- `GeminiIdentifyRepository` prefers catalog facts / timeline label over live PBDB chips.
- `SpeciesProfileScreen` shows catalog ages when `FossilKnowledgeRepository` has the taxon.

---

## Commands

```bash
cd seed
npm run test-ages      # offline helper unit tests
npm run apply-ages     # write taxa.json ages/periodIds/facts from curated+gold (no network)
npm run eval-ages      # score taxa.json vs gold fixture
npm run build          # full PBDB/Macrostrat rebuild (network; still no Firestore write)
```

---

## Done when

- [x] Eval against the gold age fixture improves (10/10 within ±5 Ma after apply)
- [x] New genus path: certain-occ + trim + Macrostrat + fact/`periodIds` sync, with manual-override and review flags
- [x] Period builds do not flap blurbs; boundaries stable vs ICS pin
- [x] Existing Firestore hand-edits remain untouched unless the user explicitly requests upload
- [x] Tests cover age helpers (trim, period mapping, fact sync) without live network
- [ ] Optional later: scoped Firestore upload of gold taxa only + set `reviewed: true` (**ask first**)

---

## Out of scope

- Clobbering Firestore with a full `upload.mjs` of local rebuild
- Kids Mode fun facts / Kids UI
- Rewriting Identify confidence heuristics
- Committing `firebase_options.dart` / Admin keys
- Owning the richer ICS Deep Time timeline UI (parallel student work)

---

## Agent instructions (copy-paste start)

```text
Read docs/pbdb-accuracy-plan.md and seed/build.mjs.

Improve the PBDB/Macrostrat age pipeline for NEW taxa so ranges, periodIds, and
schedule facts match curated quality (use the Firestore manual ages as a gold
standard via a committed fixture — read-only pull if needed).

Do NOT write to Firestore. Do NOT upload local taxa over the student’s database.
Do NOT change Identify scoring. Periods: keep blurbs; pin/stabilize ICS ages.

Deliver: algorithm improvements + gold-age eval/report + tests. Summarize
before/after accuracy on the 33 known genera without overwriting cloud data.
```
