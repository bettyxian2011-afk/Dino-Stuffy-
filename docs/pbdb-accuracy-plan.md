# Prompt: Improve PBDB / Macrostrat seed accuracy for new species profiles

Handoff for continuing work on `seed/build.mjs` (and related age logic) so **new** taxa and periods pulled from PBDB (and Macrostrat) land closer to curated scientific ranges — matching the quality of the hand-reviewed Firestore catalog.

**Related docs:** [iteration-8-firestore-roadmap.md](./iteration-8-firestore-roadmap.md), [iteration-8-v0.3-identify-firestore.md](./iteration-8-v0.3-identify-firestore.md).

---

## Hard constraints

1. **Firestore is the source of truth** for already-reviewed taxa/periods. Do **not** upload local rebuilds over Firestore without an explicit user request.
2. **Do not write to Firestore** unless the user asks. Prefer read-only inspection.
3. **Do not overwrite** hand-corrected cloud data by running `upload.mjs` blindly.
4. When changing the seed algorithm, preserve the ability to set **manual** `ageStartMa` / `ageEndMa` in `seed/curated/taxa.json` and to honor `reviewed: true` (build/upload skip reviewed docs).
5. No committing Firebase client keys, service-account JSON, or Gemini keys.

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

**Inconsistency to fix in tooling (not necessarily in DB this task):** some taxa have corrected `ageStartMa`/`ageEndMa` but **stale schedule facts** still showing the old wide label (e.g. *Triceratops* ages 68–66 while a fact still says `84–66Ma` / Campanian–Maastrichtian). New profiles should regenerate the age fact (and `periodIds`) from the final age range.

### Periods: already quite accurate

Firestore vs local ICS/PBDB boundaries differ only slightly (examples):

| Period | Local | Firestore |
| ------ | ----- | --------- |
| Ordovician | 486.85–443.1 | 486.4–443.8 |
| Jurassic | 201.4–143.1 | 201.3–145 |
| Cretaceous | 143.1–66 | 145–66 |

Blurbs match. Diffs are mostly `startMa`/`endMa` rounding and `pbdbIntervalId`. **Do not aggressively rewrite period blurbs.** Prefer pinning period ages to a cited ICS chart version and treating PBDB intervals as a cross-check.

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

Current pipeline already has: certain occs, outlier trim, Macrostrat (capped), dual envelope/core, `ageSource`, `reviewed` skip. **Extend it; don’t throw it away.**

---

## Suggested implementation work

### A. Treat Firestore manual ages as a gold set (read-only)

1. Read-only export or one-off compare script (no upload).
2. Build a **gold fixture** (e.g. `seed/fixtures/gold-ages.json`) listing `{ id, ageStartMa, ageEndMa }` from Firestore for the 33 genera — **committed**, no secrets.
3. Add a test or `node seed/eval-ages.mjs` that runs the age algorithm on those genera and reports MAE / how many fall within ±2 Ma / ±5 Ma of gold. Goal: improve scores without requiring Firestore at test time.

### B. Tighten age algorithm for new taxa

1. Keep **certain-only** occurrences; strengthen outlier rules (e.g. require ≥2 formations for an edge when `certainOccurrences` is large).
2. Prefer **formation-dated** cores (Macrostrat exact-name match only); reject ages that cross major boundaries without multi-formation support (e.g. single edge before 72.2 for Hell Creek–type dinosaurs).
3. Optional: **percentile / trimmed range** (e.g. drop outermost 5–10% of occ starts/ends) when n is large.
4. After computing core ages, **always** recompute `periodIds` and the schedule `TaxonFact` from that range (so facts never lag ages).
5. For genera marked extant / `ageEndMa ≈ 0`, flag for manual review instead of publishing a Paleozoic–Recent envelope.
6. Preserve curated overrides: `seed/curated/taxa.json` `ageStartMa`/`ageEndMa` → `ageSource: "manual"`.

### C. Periods

1. Pin Phanerozoic period boundaries to a single cited ICS source (document chart version in `periods.json` / runbook).
2. Use PBDB `intervals` only to verify / fill `pbdbIntervalId`, not to silently drift boundaries every build.
3. Leave blurbs under curated control (`seed/curated/periods.json`).

### D. New species profile checklist

When adding a genus to the catalog / seed:

1. Add curated row (realm, names, identify flags, optional manual ages).
2. Run build; read the attention report (envelope vs core gaps).
3. If gap &gt; 5 Ma or extant/long-ranging: set manual ages from a cited source (museum / primary lit / PBDB formation consensus).
4. Confirm `periodIds` and schedule fact match.
5. Upload **only that doc** or upload with `reviewed` protection for existing gold taxa.
6. Set `reviewed: true` in Firestore after human OK.

### E. Species profile UI / Identify (only if needed)

If profile screens still show PBDB live appearance ages instead of Firestore taxon ages, point them at `FossilKnowledgeRepository` / cloud taxon fields — but **do not** expand scope into full v0.3 unless asked; this prompt is primarily seed accuracy.

---

## Done when

- Eval against the gold age fixture improves (document before/after counts within ±5 Ma).
- New genus path: certain-occ + trim + Macrostrat + fact/`periodIds` sync, with clear manual-override and review flags.
- Period builds do not flap blurbs; boundaries stable vs ICS pin.
- Existing Firestore hand-edits remain untouched unless the user explicitly requests an export or carefully scoped upload.
- Tests cover age helpers (trim, period mapping, fact sync) without live network when possible (cached fixtures OK).

---

## Out of scope

- Clobbering Firestore with a full `upload.mjs` of local rebuild
- Kids Mode fun facts
- Rewriting Identify confidence heuristics
- Committing `firebase_options.dart` / Admin keys

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
