// Applies curated / gold ages onto dino_app/assets/data/taxa.json and
// recomputes periodIds + schedule TaxonFact from those final ages.
// Does NOT call PBDB/Macrostrat and does NOT write Firestore.
//
// Use when you want the offline catalog to match gold/manual ages without a
// full seed/build.mjs network rebuild.
//
// Usage: node seed/apply-catalog-ages.mjs

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { periodIdsFor, syncScheduleFact } from './lib/ages.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assetsDir = path.join(root, 'dino_app', 'assets', 'data');
const curatedDir = path.join(root, 'seed', 'curated');
const fixturesDir = path.join(root, 'seed', 'fixtures');

const readJson = async (file) => JSON.parse(await readFile(file, 'utf8'));
const writeJson = (file, data) =>
  writeFile(file, `${JSON.stringify(data, null, 2)}\n`, 'utf8');

const periods = await readJson(path.join(assetsDir, 'periods.json'));
const taxa = await readJson(path.join(assetsDir, 'taxa.json'));
const curated = await readJson(path.join(curatedDir, 'taxa.json'));
const gold = await readJson(path.join(fixturesDir, 'gold-ages.json'));

const overrides = new Map();
for (const [genus, hand] of Object.entries(curated)) {
  if (hand.ageStartMa != null && hand.ageEndMa != null) {
    overrides.set(genus.toLowerCase(), {
      ageStartMa: hand.ageStartMa,
      ageEndMa: hand.ageEndMa,
      ageSource: 'manual',
      via: 'curated',
    });
  }
}
for (const [id, g] of Object.entries(gold.taxa ?? {})) {
  if (!overrides.has(id) && g.ageStartMa != null && g.ageEndMa != null) {
    overrides.set(id, {
      ageStartMa: g.ageStartMa,
      ageEndMa: g.ageEndMa,
      ageSource: 'manual',
      via: 'gold',
    });
  }
}

let updated = 0;
for (const [id, doc] of Object.entries(taxa)) {
  if (doc.reviewed === true) {
    console.log(`skip ${id} (reviewed)`);
    continue;
  }
  const over = overrides.get(id);
  if (over) {
    doc.ageStartMa = over.ageStartMa;
    doc.ageEndMa = over.ageEndMa;
    doc.ageSource = over.ageSource;
  }
  if (doc.ageStartMa == null || doc.ageEndMa == null) continue;

  doc.periodIds = periodIdsFor(doc.ageStartMa, doc.ageEndMa, periods);
  doc.facts = syncScheduleFact(
    doc.facts,
    doc.ageStartMa,
    doc.ageEndMa,
    doc.periodIds,
    periods,
  );
  updated += 1;
  const tag = over ? ` ← ${over.via}` : ' (resync facts/periods)';
  console.log(
    `${id}: ${doc.ageStartMa}–${doc.ageEndMa} Ma → [${doc.periodIds.join(', ')}] `
    + `${doc.facts[0]?.value}${tag}`,
  );
}

await writeJson(path.join(assetsDir, 'taxa.json'), taxa);
console.log(`\nUpdated ${updated} taxa in dino_app/assets/data/taxa.json (no Firestore writes).`);
