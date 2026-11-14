// Scores dino_app/assets/data/taxa.json ages against seed/fixtures/gold-ages.json.
// No network, no Firestore. Run after build or apply-catalog-ages.
//
// Usage: node seed/eval-ages.mjs

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { ageErrors, withinTol } from './lib/ages.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const taxa = JSON.parse(
  await readFile(path.join(root, 'dino_app', 'assets', 'data', 'taxa.json'), 'utf8'),
);
const goldDoc = JSON.parse(
  await readFile(path.join(root, 'seed', 'fixtures', 'gold-ages.json'), 'utf8'),
);
const gold = goldDoc.taxa;

const rows = [];
for (const [id, g] of Object.entries(gold)) {
  const got = taxa[id];
  if (!got || got.ageStartMa == null || got.ageEndMa == null) {
    rows.push({ id, missing: true });
    continue;
  }
  const err = ageErrors(
    { ageStartMa: got.ageStartMa, ageEndMa: got.ageEndMa },
    g,
  );
  rows.push({
    id,
    got: `${got.ageStartMa}–${got.ageEndMa}`,
    gold: `${g.ageStartMa}–${g.ageEndMa}`,
    source: got.ageSource,
    periods: (got.periodIds ?? []).join(','),
    schedule: got.facts?.find((f) => f.icon === 'schedule')?.value,
    ...err,
    within2: withinTol(got, g, 2),
    within5: withinTol(got, g, 5),
  });
}

const scored = rows.filter((r) => !r.missing);
const mae = scored.length
  ? scored.reduce((s, r) => s + r.meanErr, 0) / scored.length
  : null;

console.log('Gold-age eval (catalog vs fixture)\n');
console.log(
  'id'.padEnd(22),
  'got'.padEnd(14),
  'gold'.padEnd(14),
  'maxΔ'.padStart(6),
  '±2',
  '±5',
  'periods',
);
for (const r of rows) {
  if (r.missing) {
    console.log(r.id.padEnd(22), 'MISSING');
    continue;
  }
  console.log(
    r.id.padEnd(22),
    r.got.padEnd(14),
    r.gold.padEnd(14),
    r.maxErr.toFixed(1).padStart(6),
    r.within2 ? 'Y' : 'n',
    r.within5 ? 'Y' : 'n',
    r.periods,
  );
}

const within2 = scored.filter((r) => r.within2).length;
const within5 = scored.filter((r) => r.within5).length;
console.log(`\nScored ${scored.length} / ${Object.keys(gold).length} gold taxa`);
console.log(`Within ±2 Ma: ${within2}/${scored.length}`);
console.log(`Within ±5 Ma: ${within5}/${scored.length}`);
if (mae != null) console.log(`MAE (mean of start/end errors): ${mae.toFixed(2)} Ma`);

const badFacts = scored.filter((r) => {
  const rounded = `${Math.round(taxa[r.id].ageStartMa)}–${Math.round(taxa[r.id].ageEndMa)}Ma`;
  const single = `${Math.round(taxa[r.id].ageStartMa)}Ma`;
  return r.schedule && r.schedule !== rounded && r.schedule !== single
    && Math.round(taxa[r.id].ageStartMa) !== Math.round(taxa[r.id].ageEndMa);
});
if (badFacts.length) {
  console.log('\nSchedule facts out of sync:');
  for (const r of badFacts) console.log(`  - ${r.id}: ages ${r.got} but fact ${r.schedule}`);
} else {
  console.log('\nSchedule facts match rounded ages for all scored gold taxa.');
}
