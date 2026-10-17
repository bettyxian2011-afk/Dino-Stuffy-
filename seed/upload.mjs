// Writes dino_app/assets/data/periods.json and taxa.json to Firestore.
// Periods are always overwritten. Taxa docs with reviewed:true already in
// Firestore are skipped so console corrections survive. Uses the Admin SDK,
// which bypasses security rules.
//
// Usage:
//   node seed/upload.mjs --key C:\path\outside\repo\service-account.json
//   node seed/upload.mjs --dry-run      (no key needed)

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'dino-app-90aa2';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assetsDir = path.join(root, 'dino_app', 'assets', 'data');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

const collections = {
  periods: JSON.parse(await readFile(path.join(assetsDir, 'periods.json'), 'utf8')),
  taxa: JSON.parse(await readFile(path.join(assetsDir, 'taxa.json'), 'utf8')),
};

if (dryRun) {
  for (const [name, docs] of Object.entries(collections)) {
    console.log(`[dry run] ${name}: ${Object.keys(docs).length} docs (${Object.keys(docs).join(', ')})`);
  }
  process.exit(0);
}

const keyPath = args.includes('--key') ? args[args.indexOf('--key') + 1] : undefined;
if (!keyPath) {
  console.error('Pass --key <path to service-account JSON>. Keep that file outside the repo.');
  process.exit(1);
}
if (path.resolve(keyPath).startsWith(root + path.sep)) {
  console.error('The service-account key is inside the repo. Move it outside before uploading.');
  process.exit(1);
}
const key = JSON.parse(await readFile(keyPath, 'utf8'));
if (key.project_id !== PROJECT_ID) {
  console.error(`Key is for ${key.project_id}, expected ${PROJECT_ID}.`);
  process.exit(1);
}

initializeApp({ credential: cert(key), projectId: PROJECT_ID });
const db = getFirestore();

{
  const batch = db.batch();
  for (const [id, data] of Object.entries(collections.periods)) {
    batch.set(db.collection('periods').doc(id), data);
  }
  await batch.commit();
  console.log(`periods: wrote ${Object.keys(collections.periods).length} docs`);
}

{
  const existing = await db.collection('taxa').get();
  const reviewed = new Set(
    existing.docs.filter((d) => d.data().reviewed === true).map((d) => d.id),
  );

  const toWrite = Object.entries(collections.taxa).filter(([id]) => !reviewed.has(id));
  const skipped = Object.keys(collections.taxa).filter((id) => reviewed.has(id));

  // Firestore batches max out at 500 ops.
  const CHUNK = 400;
  for (let i = 0; i < toWrite.length; i += CHUNK) {
    const batch = db.batch();
    for (const [id, data] of toWrite.slice(i, i + CHUNK)) {
      batch.set(db.collection('taxa').doc(id), data);
    }
    await batch.commit();
  }

  console.log(`taxa: wrote ${toWrite.length} docs`);
  if (skipped.length) {
    console.log(`taxa: skipped ${skipped.length} reviewed (${skipped.join(', ')})`);
  }
}
