// Offline unit checks for seed/lib/ages.mjs (no network).
// Usage: node seed/test-ages.mjs
// Exit 1 on failure.

import {
  ageFact,
  clampMajorBoundaryYoungEdge,
  periodIdsFor,
  percentileTrim,
  syncScheduleFact,
  trimToCore,
  withinTol,
} from './lib/ages.mjs';

let failed = 0;
function assert(cond, msg) {
  if (!cond) {
    console.error(`FAIL: ${msg}`);
    failed += 1;
  } else {
    console.log(`ok: ${msg}`);
  }
}

const periods = {
  cretaceous: { name: 'Cretaceous', startMa: 143.1, endMa: 66, order: 9 },
  paleogene: { name: 'Paleogene', startMa: 66, endMa: 23.04, order: 10 },
  jurassic: { name: 'Jurassic', startMa: 201.4, endMa: 143.1, order: 8 },
};

assert(
  periodIdsFor(68, 66, periods).join(',') === 'cretaceous',
  '68–66 Ma is Cretaceous only',
);
assert(
  periodIdsFor(70, 64, periods).join(',') === 'cretaceous,paleogene',
  '70–64 Ma spans Cretaceous–Paleogene',
);

const fact = ageFact(68, 66, ['cretaceous'], periods);
assert(fact.value === '68–66Ma' && fact.label === 'Cretaceous', 'ageFact label');

const synced = syncScheduleFact(
  [
    { icon: 'schedule', value: '84–66Ma', label: 'Campanian–Maastrichtian' },
    { icon: 'public', value: 'Laramidia', label: 'Range' },
  ],
  68,
  66,
  ['cretaceous'],
  periods,
);
assert(synced[0].value === '68–66Ma', 'sync replaces stale schedule fact');
assert(synced[1].value === 'Laramidia', 'sync keeps non-schedule facts');

const dated = [
  { startMa: 83.6, endMa: 72.2, formation: 'Kirtland' },
  { startMa: 72.2, endMa: 66, formation: 'Hell Creek' },
  { startMa: 72.0, endMa: 66, formation: 'Lance' },
  { startMa: 70, endMa: 66, formation: 'Hell Creek' },
];
const core = trimToCore(dated);
assert(core.startMa <= 72.2, 'trim drops lone 83.6 edge');
assert(core.endMa === 66, 'trim keeps multi-formation young edge');

const leak = clampMajorBoundaryYoungEdge(
  { startMa: 72.2, endMa: 63.5, occCount: 3 },
  [
    { startMa: 72.2, endMa: 66, formation: 'Hell Creek' },
    { startMa: 70, endMa: 66, formation: 'Lance' },
    { startMa: 68, endMa: 63.5, formation: 'Odd' },
  ],
);
assert(leak.endMa === 66, 'clamp lone post–K-Pg young edge');

const many = Array.from({ length: 30 }, (_, i) => ({
  startMa: 70 + (i === 0 ? 20 : i * 0.1),
  endMa: 66,
  formation: `Fm${i}`,
}));
const pct = percentileTrim(many);
assert(pct.every((d) => d.startMa < 90), 'percentile trim drops extreme old start');

assert(
  withinTol({ ageStartMa: 68, ageEndMa: 66 }, { ageStartMa: 68, ageEndMa: 66 }, 2),
  'withinTol exact',
);
assert(
  !withinTol({ ageStartMa: 83.6, ageEndMa: 64.9 }, { ageStartMa: 68, ageEndMa: 66 }, 5),
  'withinTol rejects wide PBDB envelope',
);

if (failed) {
  console.error(`\n${failed} failure(s)`);
  process.exit(1);
}
console.log('\nAll age helper tests passed.');
