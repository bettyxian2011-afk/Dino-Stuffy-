// Reads the Firestore `taxa` collection and replaces
// dino_app/assets/data/taxa.json with it, so corrections made in the Firebase
// console reach the app's offline copy. Read-only against Firestore.
//
// Every doc is checked against what FossilTaxon.fromJson needs; if any doc is
// invalid, nothing is written.
//
// Usage (from the repo root):
//   node seed/export.mjs --key C:\path\outside\repo\service-account.json --dry-run
//   node seed/export.mjs --key C:\path\outside\repo\service-account.json

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';
import path from 'node:path';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, Timestamp, DocumentReference } from 'firebase-admin/firestore';

const PROJECT_ID = 'dino-app-90aa2';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const taxaPath = path.join(root, 'dino_app', 'assets', 'data', 'taxa.json');

// Same field order build.mjs writes, so diffs stay readable.
const FIELD_ORDER = [
  'scientificName', 'commonName', 'commonGroup', 'family', 'taxonomy', 'realm',
  'periodIds', 'ageStartMa', 'ageEndMa', 'ageSource', 'ageEnvelope', 'ageCore',
  'reviewed', 'facts', 'funFacts', 'tip', 'imageAsset', 'useInIdentify',
  'kidSafe', 'iconic', 'pbdb',
];
const REALMS = ['land', 'sky', 'ocean'];

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

const keyPath = args.includes('--key') ? args[args.indexOf('--key') + 1] : undefined;
if (!keyPath) {
  console.error('Pass --key <path to service-account JSON>. Keep that file outside the repo.');
  process.exit(1);
}
if (path.resolve(keyPath).startsWith(root + path.sep)) {
  console.error('The service-account key is inside the repo. Move it outside before exporting.');
  process.exit(1);
}
const key = JSON.parse(await readFile(keyPath, 'utf8'));
if (key.project_id !== PROJECT_ID) {
  console.error(`Key is for ${key.project_id}, expected ${PROJECT_ID}.`);
  process.exit(1);
}

/** Converts Firestore-only types into plain JSON values. */
function toPlain(value) {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof DocumentReference) return value.path;
  if (Array.isArray(value)) return value.map(toPlain);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, toPlain(v)]));
  }
  return value;
}

function ordered(doc) {
  const known = FIELD_ORDER.filter((f) => f in doc).map((f) => [f, doc[f]]);
  const extra = Object.keys(doc).filter((f) => !FIELD_ORDER.includes(f)).map((f) => [f, doc[f]]);
  return Object.fromEntries([...known, ...extra]);
}

/** Problems that would make FossilTaxon.fromJson throw or mislead the app. */
function problemsWith(id, doc) {
  const problems = [];
  const isString = (v) => typeof v === 'string';
  const isNumber = (v) => typeof v === 'number' && Number.isFinite(v);
  const isStringList = (v) => Array.isArray(v) && v.every(isString);

  for (const f of ['scientificName', 'commonGroup', 'family', 'imageAsset']) {
    if (!isString(doc[f]) || doc[f] === '') problems.push(`${f} must be a non-empty string`);
  }
  if (doc.commonName != null && !isString(doc.commonName)) problems.push('commonName must be a string or null');
  if (doc.tip != null && !isString(doc.tip)) problems.push('tip must be a string');
  if (!REALMS.includes(doc.realm)) problems.push(`realm must be one of ${REALMS.join(', ')}`);
  if (!isStringList(doc.taxonomy)) problems.push('taxonomy must be a list of strings');
  if (!isStringList(doc.periodIds)) problems.push('periodIds must be a list of strings');
  if (doc.funFacts != null && !isStringList(doc.funFacts)) problems.push('funFacts must be a list of strings');
  for (const f of ['ageStartMa', 'ageEndMa']) {
    if (doc[f] != null && !isNumber(doc[f])) problems.push(`${f} must be a number (not text)`);
  }
  if (isNumber(doc.ageStartMa) && isNumber(doc.ageEndMa) && doc.ageStartMa < doc.ageEndMa) {
    problems.push('ageStartMa must be older (larger) than ageEndMa');
  }
  if (!Array.isArray(doc.facts)
      || !doc.facts.every((f) => f && isString(f.icon) && isString(f.value) && isString(f.label))) {
    problems.push('facts must be a list of {icon, value, label} strings');
  }
  for (const f of ['useInIdentify', 'kidSafe', 'iconic', 'reviewed']) {
    if (doc[f] != null && typeof doc[f] !== 'boolean') problems.push(`${f} must be true or false`);
  }
  if (doc.ageSource != null
      && !['manual', 'macrostrat', 'pbdb-core', 'pbdb-envelope'].includes(doc.ageSource)) {
    problems.push('ageSource must be manual, macrostrat, pbdb-core, or pbdb-envelope');
  }
  if (doc.pbdb != null && !isString(doc.pbdb.taxonNo)) problems.push('pbdb.taxonNo must be a string');
  if (id !== id.toLowerCase()) problems.push('doc id must be lowercase');
  return problems;
}

initializeApp({ credential: cert(key), projectId: PROJECT_ID });
const snapshot = await getFirestore().collection('taxa').get();

const exported = {};
const invalid = [];
for (const doc of [...snapshot.docs].sort((a, b) => a.id.localeCompare(b.id))) {
  const data = ordered(toPlain(doc.data()));
  const problems = problemsWith(doc.id, data);
  if (problems.length) invalid.push(`taxa/${doc.id}: ${problems.join('; ')}`);
  exported[doc.id] = data;
}

if (snapshot.empty) {
  console.error('Firestore taxa collection is empty. Not touching taxa.json.');
  process.exit(1);
}
if (invalid.length) {
  console.error(`Not writing taxa.json. Fix these in the Firebase console first:\n  - ${invalid.join('\n  - ')}`);
  process.exit(1);
}

const current = JSON.parse(await readFile(taxaPath, 'utf8'));
const added = Object.keys(exported).filter((id) => !(id in current));
const removed = Object.keys(current).filter((id) => !(id in exported));
const changed = Object.keys(exported)
  .filter((id) => id in current)
  .map((id) => {
    const fields = [...new Set([...Object.keys(current[id]), ...Object.keys(exported[id])])]
      .filter((f) => !isDeepStrictEqual(current[id][f], exported[id][f]));
    return fields.length ? `${id} (${fields.join(', ')})` : null;
  })
  .filter(Boolean);

console.log(`Firestore taxa: ${Object.keys(exported).length} docs`);
console.log(`  added:   ${added.length ? added.join(', ') : 'none'}`);
console.log(`  removed: ${removed.length ? removed.join(', ') : 'none'}`);
console.log(`  changed: ${changed.length ? `\n    ${changed.join('\n    ')}` : 'none'}`);

if (dryRun) {
  console.log('\n[dry run] taxa.json not written.');
  process.exit(0);
}

await writeFile(taxaPath, `${JSON.stringify(exported, null, 2)}\n`, 'utf8');
console.log(`\nWrote ${path.relative(root, taxaPath)}.`);
