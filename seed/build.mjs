// Builds dino_app/assets/data/periods.json and taxa.json from PBDB plus the
// hand-curated files in seed/curated/. The app bundles both outputs as its
// offline fallback, and upload.mjs writes the same files to Firestore.
//
// Age ranges (when not set by hand):
//   1. Load certain PBDB occurrences (idqual=certain), not the genus summary.
//   2. Prefer Macrostrat formation ages over PBDB's coarse interval bounds.
//   3. Percentile-trim large samples; envelope = widest; core = outlier-trimmed
//      (large samples need ≥2 formations on an edge). Clamp lone K–Pg leaks.
//   4. Flag when envelope and core differ by more than GAP_MA, and extant
//      genera with deep starts.
//
// Final ageStartMa / ageEndMa ALWAYS drive periodIds and the schedule
// TaxonFact (Deep Time, Identify, Kids Mode share taxa/{id}).
//
// Taxa marked reviewed:true in the previous taxa.json are left untouched so
// console corrections survive a rebuild.
//
// Precedence per non-age field: seed/curated/taxa.json, then the Identify
// catalog (id_results.json), then PBDB. Curated ageStartMa / ageEndMa win
// and set ageSource to "manual".
//
// Periods: blurbs from curated; ages pinned to ICS 2024-12 fixture when the
// curated row does not set startMa/endMa. PBDB fills pbdbIntervalId / color.
// Parallel ICS timeline work can own richer period docs — this pin keeps
// periodIds stable and merge-friendly.
//
// Usage: node seed/build.mjs

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  GAP_MA,
  agesOverlap,
  clampMajorBoundaryYoungEdge,
  num,
  median,
  periodIdsFor,
  percentileTrim,
  plausibleAge,
  rangeOf,
  syncScheduleFact,
  trimToCore,
} from './lib/ages.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assetsDir = path.join(root, 'dino_app', 'assets', 'data');
const curatedDir = path.join(root, 'seed', 'curated');
const fixturesDir = path.join(root, 'seed', 'fixtures');
const cacheDir = path.join(root, 'seed', 'cache');

const PBDB = 'https://paleobiodb.org/data1.2';
const MACROSTRAT = 'https://macrostrat.org/api';
const PERIOD_NAMES = [
  'Cambrian', 'Ordovician', 'Silurian', 'Devonian', 'Carboniferous', 'Permian',
  'Triassic', 'Jurassic', 'Cretaceous', 'Paleogene', 'Neogene', 'Quaternary',
];

const readJson = async (file) => JSON.parse(await readFile(file, 'utf8'));
const writeJson = (file, data) =>
  writeFile(file, `${JSON.stringify(data, null, 2)}\n`, 'utf8');

async function cachedGet(url, cacheKey) {
  const file = path.join(cacheDir, `${cacheKey}.json`);
  try {
    return JSON.parse(await readFile(file, 'utf8'));
  } catch {
    const res = await fetch(url, { signal: AbortSignal.timeout(20_000) });
    if (!res.ok) throw new Error(`${res.status} for ${url}`);
    const body = await res.json();
    await mkdir(cacheDir, { recursive: true });
    await writeJson(file, body);
    return body;
  }
}

async function pbdbGet(endpoint, cacheKey) {
  const body = await cachedGet(`${PBDB}/${endpoint}`, `pbdb-${cacheKey}`);
  return body.records ?? [];
}

async function buildPeriods(report) {
  console.log('Fetching PBDB period intervals…');
  const curated = await readJson(path.join(curatedDir, 'periods.json'));
  const ics = await readJson(path.join(fixturesDir, 'ics-periods-2024-12.json'));
  const intervals = await pbdbGet('intervals/list.json?scale=1&max_ma=540', 'intervals');
  console.log(`Got ${intervals.length} intervals.`);
  const byId = new Map(intervals.map((i) => [i.oid, i]));

  const periods = {};
  PERIOD_NAMES.forEach((name, index) => {
    const interval = intervals.find((i) => i.itp === 'period' && i.nam === name);
    if (!interval) throw new Error(`PBDB has no period named ${name}`);
    const id = name.toLowerCase();
    const blurb = curated[id]?.blurb ?? '';
    if (!blurb) report.push(`periods/${id}: blurb is empty`);
    const pin = ics[id] ?? {};
    const startMa = curated[id]?.startMa ?? pin.startMa ?? interval.eag;
    const endMa = curated[id]?.endMa ?? pin.endMa ?? interval.lag;
    // Schema stays {name,era,startMa,endMa,blurb,order,color,pbdbIntervalId}
    // so parallel ICS timeline work can merge without fighting extra fields.
    periods[id] = {
      name,
      era: byId.get(interval.pid)?.nam,
      startMa,
      endMa,
      blurb,
      order: index + 1,
      color: interval.col ?? null,
      pbdbIntervalId: interval.oid,
    };
  });
  return periods;
}

/** Genus -> { candidate, result } from the Identify catalog. */
async function loadCatalog() {
  const results = await readJson(path.join(assetsDir, 'id_results.json'));
  const byGenus = new Map();
  for (const result of Object.values(results)) {
    for (const candidate of result.candidates) {
      if (!byGenus.has(candidate.genus)) {
        byGenus.set(candidate.genus, { candidate, result });
      }
    }
  }
  return byGenus;
}

const usable = (rank) => rank && !rank.startsWith('NO_');

/**
 * Macrostrat formation ages. Exact name match preferred; result must be a
 * plausible Phanerozoic span. Cached per formation.
 */
async function formationAge(formation, cache) {
  const key = formation.trim().toLowerCase();
  if (!key || key.length < 3) {
    cache.set(key, null);
    return null;
  }
  if (cache.has(key)) return cache.get(key);

  let result = null;
  const norm = (s) => (s || '').trim().toLowerCase().replace(/\s+fm\.?$/, '').replace(/\s+formation$/, '');
  const want = norm(formation);

  try {
    const defs = await cachedGet(
      `${MACROSTRAT}/defs/strat_names?strat_name=${encodeURIComponent(formation)}`,
      `ms-defs-${key.replace(/\s+/g, '_')}`,
    );
    const candidates = (defs.success?.data ?? [])
      .map((d) => ({
        ...d,
        b: num(d.b_age),
        t: num(d.t_age),
        exact: norm(d.strat_name) === want || norm(d.strat_name) === `${want} fm`,
      }))
      .filter((d) => plausibleAge(d.b, d.t));
    const exact = candidates.filter((d) => d.exact);
    const pool = (exact.length ? exact : candidates)
      .sort((a, b) => (a.b - a.t) - (b.b - b.t));
    if (pool.length) {
      result = {
        startMa: pool[0].b,
        endMa: pool[0].t,
        source: 'macrostrat',
        stratName: pool[0].strat_name,
      };
    }
  } catch {
    // fall through to units
  }

  if (!result) {
    try {
      const units = await cachedGet(
        `${MACROSTRAT}/units?strat_name=${encodeURIComponent(formation)}&response=long`,
        `ms-units-${key.replace(/\s+/g, '_')}`,
      );
      const rows = (units.success?.data ?? []).filter((u) => {
        const b = num(u.b_age);
        const t = num(u.t_age);
        const fm = norm(u.Fm || u.unit_name);
        return plausibleAge(b, t) && (fm === want || fm.startsWith(want));
      });
      const start = median(rows.map((u) => num(u.b_age)));
      const end = median(rows.map((u) => num(u.t_age)));
      if (plausibleAge(start, end)) {
        result = { startMa: start, endMa: end, source: 'macrostrat', stratName: formation };
      }
    } catch {
      result = null;
    }
  }

  cache.set(key, result);
  return result;
}

/**
 * Only the most common formations are worth a Macrostrat round-trip.
 * Genera like Atrypa have 300+ formation names.
 */
function formationsForMacrostrat(occs, { minCount = 2, maxFormations = 12 } = {}) {
  const counts = new Map();
  for (const occ of occs) {
    const fm = (occ.formation || '').trim();
    if (fm.length < 3) continue;
    counts.set(fm, (counts.get(fm) || 0) + 1);
  }
  return [...counts.entries()]
    .filter(([, n]) => n >= minCount)
    .sort((a, b) => b[1] - a[1])
    .slice(0, maxFormations)
    .map(([name]) => name);
}

/** Use Macrostrat only when it overlaps PBDB and is not wider. */
function dateOccurrence(occ, formationAges) {
  const formation = (occ.formation || '').trim() || null;
  const pbdbStart = num(occ.max_ma);
  const pbdbEnd = num(occ.min_ma);
  if (pbdbStart == null || pbdbEnd == null || pbdbStart > 550) return null;

  const pbdb = { startMa: pbdbStart, endMa: pbdbEnd };
  const fm = formation ? formationAges.get(formation.trim().toLowerCase()) : null;
  if (fm && agesOverlap(fm, pbdb)) {
    const msSpan = fm.startMa - fm.endMa;
    const pbSpan = pbdbStart - pbdbEnd;
    // Accept tighter or roughly equal Macrostrat ages only.
    if (msSpan <= pbSpan + 2) {
      return {
        startMa: fm.startMa,
        endMa: fm.endMa,
        formation,
        source: 'macrostrat',
        collectionNo: occ.collection_no,
      };
    }
  }
  return {
    startMa: pbdbStart,
    endMa: pbdbEnd,
    formation,
    source: 'pbdb',
    collectionNo: occ.collection_no,
  };
}

async function computeAgeRanges(genus, formationCache, report) {
  const id = genus.toLowerCase();
  let occs = [];
  try {
    occs = await pbdbGet(
      `occs/list.json?base_name=${encodeURIComponent(genus)}&idqual=certain&show=strat&vocab=pbdb`,
      `occs-${id}`,
    );
  } catch (e) {
    report.push(`taxa/${id}: certain-occ fetch failed (${e.message})`);
    return null;
  }

  // Warm Macrostrat only for the common formations of this genus.
  const toLookup = formationsForMacrostrat(occs);
  for (const name of toLookup) {
    await formationAge(name, formationCache);
  }

  const dated = [];
  for (const occ of occs) {
    const d = dateOccurrence(occ, formationCache);
    if (d) dated.push(d);
  }
  if (!dated.length) {
    report.push(`taxa/${id}: no certain dated occurrences`);
    return null;
  }

  const trimmed = percentileTrim(dated);
  const envelope = rangeOf(dated);
  let core = trimToCore(trimmed);
  core = clampMajorBoundaryYoungEdge(core, trimmed);
  const macroCount = dated.filter((d) => d.source === 'macrostrat').length;
  const ageSource = macroCount >= dated.length / 2 ? 'macrostrat' : 'pbdb-core';
  const formations = [...new Set(dated.map((d) => d.formation).filter(Boolean))];

  if (envelope && core) {
    const startGap = Math.abs(envelope.startMa - core.startMa);
    const endGap = Math.abs(envelope.endMa - core.endMa);
    if (startGap > GAP_MA || endGap > GAP_MA) {
      report.push(
        `taxa/${id}: envelope ${envelope.startMa.toFixed(1)}–${envelope.endMa.toFixed(1)} `
        + `vs core ${core.startMa.toFixed(1)}–${core.endMa.toFixed(1)} `
        + `(gap start ${startGap.toFixed(1)} / end ${endGap.toFixed(1)} Ma)`,
      );
    }
  }

  return {
    envelope,
    core,
    ageSource,
    certainOccurrences: dated.length,
    formationsUsed: formations,
  };
}

async function buildTaxa(periods, report) {
  const curated = await readJson(path.join(curatedDir, 'taxa.json'));
  const catalog = await loadCatalog();
  let previous = {};
  try {
    previous = await readJson(path.join(assetsDir, 'taxa.json'));
  } catch {
    previous = {};
  }

  for (const genus of catalog.keys()) {
    if (!curated[genus]) {
      report.push(`${genus}: in Identify catalog but missing from seed/curated/taxa.json`);
    }
  }

  const formationCache = new Map();
  const taxa = {};
  const genera = Object.entries(curated);
  let index = 0;

  for (const [genus, hand] of genera) {
    const id = genus.toLowerCase();
    index += 1;
    process.stdout.write(`[${index}/${genera.length}] ${genus}… `);

    // Reviewed docs are locked: keep the previous offline copy untouched.
    if (previous[id]?.reviewed === true) {
      taxa[id] = previous[id];
      console.log('reviewed (kept)');
      report.push(`taxa/${id}: reviewed — kept previous document (skipped PBDB rebuild)`);
      continue;
    }

    const fromCatalog = catalog.get(genus);
    const [record] = await pbdbGet(
      `taxa/single.json?name=${encodeURIComponent(genus)}&show=app,attr,class`,
      `taxon-${id}`,
    );
    if (!record) {
      console.log('not in PBDB');
      report.push(`taxa/${id}: not found in PBDB`);
      continue;
    }
    if (record.nam !== genus) report.push(`taxa/${id}: PBDB returned ${record.nam}`);

    const isBestMatch = fromCatalog?.candidate.isBestMatch ?? false;
    const ranges = await computeAgeRanges(genus, formationCache, report);

    let ageStartMa;
    let ageEndMa;
    let ageSource;
    let ageEnvelope = ranges?.envelope ?? null;
    let ageCore = ranges?.core
      ? { startMa: ranges.core.startMa, endMa: ranges.core.endMa }
      : null;

    if (hand.ageStartMa != null && hand.ageEndMa != null) {
      ageStartMa = hand.ageStartMa;
      ageEndMa = hand.ageEndMa;
      ageSource = 'manual';
    } else if (ranges?.core) {
      ageStartMa = ranges.core.startMa;
      ageEndMa = ranges.core.endMa;
      ageSource = ranges.ageSource;
    } else {
      // Last resort: genus-summary first/last appearance (old behaviour).
      ageStartMa = record.fea;
      ageEndMa = record.lla;
      ageSource = 'pbdb-envelope';
      report.push(`taxa/${id}: fell back to genus-summary appearance ages`);
    }

    const extant = record.ext === '1' || record.ext === 1;
    if (extant && ageEndMa <= 0.1 && ageStartMa > 50) {
      report.push(
        `taxa/${id}: extant / living with deep start ${ageStartMa} Ma — prefer manual ages`,
      );
    }

    const periodIds = periodIdsFor(ageStartMa, ageEndMa, periods);
    // Catalog / hand non-schedule facts may remain; schedule chip always syncs.
    const seedFacts = hand.facts ?? (isBestMatch ? fromCatalog?.result?.facts : null);
    const facts = syncScheduleFact(seedFacts, ageStartMa, ageEndMa, periodIds, periods);

    const doc = {
      scientificName: genus,
      commonName: hand.commonName ?? null,
      commonGroup: hand.commonGroup ?? fromCatalog?.candidate.commonGroup,
      family: hand.family ?? fromCatalog?.candidate.family
        ?? (usable(record.fml) ? record.fml : undefined),
      taxonomy: hand.taxonomy ?? fromCatalog?.result.taxonomy,
      realm: hand.realm,
      periodIds,
      ageStartMa,
      ageEndMa,
      ageSource,
      ageEnvelope,
      ageCore,
      reviewed: false,
      facts,
      funFacts: hand.funFacts ?? [],
      tip: hand.tip ?? fromCatalog?.result.tip ?? '',
      imageAsset: hand.imageAsset ?? fromCatalog?.candidate.thumbnail,
      useInIdentify: hand.useInIdentify ?? fromCatalog != null,
      kidSafe: hand.kidSafe ?? false,
      iconic: hand.iconic ?? false,
      pbdb: {
        taxonNo: record.oid,
        attribution: record.att ?? null,
        firstInterval: record.tei ?? null,
        lastInterval: record.tli ?? null,
        occurrences: record.noc ?? null,
        certainOccurrences: ranges?.certainOccurrences ?? null,
        formationsUsed: ranges?.formationsUsed ?? [],
        extant,
      },
    };

    for (const field of ['commonGroup', 'family', 'taxonomy', 'realm', 'imageAsset']) {
      if (doc[field] == null) throw new Error(`taxa/${id}: no value for ${field}`);
    }
    if (fromCatalog && fromCatalog.candidate.family !== doc.family) {
      report.push(`taxa/${id}: family differs from Identify catalog`);
    }
    if (doc.periodIds.length === 0) {
      report.push(`taxa/${id}: no period overlaps ${ageStartMa}–${ageEndMa} Ma`);
    }
    if (doc.kidSafe && doc.funFacts.length < 2) {
      report.push(`taxa/${id}: kidSafe but has ${doc.funFacts.length} fun facts (need 2–3)`);
    }
    taxa[id] = doc;
    const src = ageSource;
    console.log(
      `${ageStartMa.toFixed(1)}–${ageEndMa.toFixed(1)} Ma (${src}`
      + `${ranges ? `, ${ranges.certainOccurrences} certain occs` : ''})`,
    );
  }

  for (const periodId of Object.keys(periods)) {
    const iconic = Object.values(taxa).filter((t) => t.iconic && t.periodIds.includes(periodId));
    if (iconic.length === 0) report.push(`periods/${periodId}: no iconic taxa`);
  }
  return Object.fromEntries(Object.entries(taxa).sort(([a], [b]) => a.localeCompare(b)));
}

const report = [];
const periods = await buildPeriods(report);
const taxa = await buildTaxa(periods, report);
await writeJson(path.join(assetsDir, 'periods.json'), periods);
await writeJson(path.join(assetsDir, 'taxa.json'), taxa);

console.log(`Wrote ${Object.keys(periods).length} periods and ${Object.keys(taxa).length} taxa to dino_app/assets/data/.`);
if (report.length) {
  console.log(`\nNeeds attention (${report.length}):`);
  for (const line of report) console.log(`  - ${line}`);
}
