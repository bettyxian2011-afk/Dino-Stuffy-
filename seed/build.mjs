// Builds dino_app/assets/data/periods.json and taxa.json from PBDB plus the
// hand-curated files in seed/curated/. The app bundles both outputs as its
// offline fallback, and upload.mjs writes the same files to Firestore.
//
// Precedence per taxon field: seed/curated/taxa.json, then the Identify
// catalog (dino_app/assets/data/id_results.json), then PBDB. A curated
// ageStartMa / ageEndMa replaces the PBDB range and its periodIds.
//
// Usage: node seed/build.mjs

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assetsDir = path.join(root, 'dino_app', 'assets', 'data');
const curatedDir = path.join(root, 'seed', 'curated');

const PBDB = 'https://paleobiodb.org/data1.2';
const PERIOD_NAMES = [
  'Cambrian', 'Ordovician', 'Silurian', 'Devonian', 'Carboniferous', 'Permian',
  'Triassic', 'Jurassic', 'Cretaceous', 'Paleogene', 'Neogene', 'Quaternary',
];

const readJson = async (file) => JSON.parse(await readFile(file, 'utf8'));
const writeJson = (file, data) =>
  writeFile(file, `${JSON.stringify(data, null, 2)}\n`, 'utf8');

async function pbdbGet(endpoint) {
  const res = await fetch(`${PBDB}/${endpoint}`);
  if (!res.ok) throw new Error(`PBDB ${res.status} for ${endpoint}`);
  return (await res.json()).records;
}

async function buildPeriods(report) {
  const curated = await readJson(path.join(curatedDir, 'periods.json'));
  const intervals = await pbdbGet('intervals/list.json?scale=1&max_ma=540');
  const byId = new Map(intervals.map((i) => [i.oid, i]));

  const periods = {};
  PERIOD_NAMES.forEach((name, index) => {
    const interval = intervals.find((i) => i.itp === 'period' && i.nam === name);
    if (!interval) throw new Error(`PBDB has no period named ${name}`);
    const id = name.toLowerCase();
    const blurb = curated[id]?.blurb ?? '';
    if (!blurb) report.push(`periods/${id}: blurb is empty`);
    periods[id] = {
      name,
      era: byId.get(interval.pid)?.nam,
      startMa: interval.eag,
      endMa: interval.lag,
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

function periodIdsFor(startMa, endMa, periods) {
  return Object.entries(periods)
    .filter(([, p]) => p.startMa > endMa && p.endMa < startMa)
    .map(([id]) => id);
}

function ageFact(startMa, endMa, periodIds, periods, record) {
  const old = Math.round(startMa);
  const young = Math.round(endMa);
  const value = old === young ? `${old}Ma` : `${old}–${young}Ma`;
  const fromPbdb = startMa === record.fea && endMa === record.lla && record.tei;
  const [first, last] = fromPbdb
    ? [record.tei, record.tli ?? record.tei]
    : [periods[periodIds[0]]?.name, periods[periodIds.at(-1)]?.name];
  const label = first === last ? first : `${first}–${last}`;
  return { icon: 'schedule', value, label };
}

const usable = (rank) => rank && !rank.startsWith('NO_');

async function buildTaxa(periods, report) {
  const curated = await readJson(path.join(curatedDir, 'taxa.json'));
  const catalog = await loadCatalog();

  for (const genus of catalog.keys()) {
    if (!curated[genus]) report.push(`${genus}: in Identify catalog but missing from seed/curated/taxa.json`);
  }

  const taxa = {};
  for (const [genus, hand] of Object.entries(curated)) {
    const id = genus.toLowerCase();
    const fromCatalog = catalog.get(genus);
    const [record] = await pbdbGet(
      `taxa/single.json?name=${encodeURIComponent(genus)}&show=app,attr,class`,
    );
    if (!record) {
      report.push(`taxa/${id}: not found in PBDB`);
      continue;
    }
    if (record.nam !== genus) report.push(`taxa/${id}: PBDB returned ${record.nam}`);

    const isBestMatch = fromCatalog?.candidate.isBestMatch ?? false;
    // PBDB ranges come from raw occurrences and can include outliers, so a
    // curated range wins when one is given.
    const ageStartMa = hand.ageStartMa ?? record.fea;
    const ageEndMa = hand.ageEndMa ?? record.lla;
    const periodIds = periodIdsFor(ageStartMa, ageEndMa, periods);
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
      // Catalog facts are shared by every candidate in a result, so only the
      // best match's are accurate; other genera get their PBDB age instead.
      facts: hand.facts ?? (isBestMatch
        ? fromCatalog.result.facts
        : [ageFact(ageStartMa, ageEndMa, periodIds, periods, record)]),
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
        extant: record.ext === '1' || record.ext === 1,
      },
    };

    for (const field of ['commonGroup', 'family', 'taxonomy', 'realm', 'imageAsset']) {
      if (doc[field] == null) throw new Error(`taxa/${id}: no value for ${field}`);
    }
    if (fromCatalog && fromCatalog.candidate.family !== doc.family) {
      report.push(`taxa/${id}: family differs from Identify catalog`);
    }
    if (doc.periodIds.length === 0) report.push(`taxa/${id}: no period overlaps ${ageStartMa}–${ageEndMa} Ma`);
    if (doc.kidSafe && doc.funFacts.length < 2) report.push(`taxa/${id}: kidSafe but has ${doc.funFacts.length} fun facts (need 2–3)`);
    taxa[id] = doc;
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
