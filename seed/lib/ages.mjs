// Shared age / period / schedule-fact helpers for seed/build.mjs and eval.
// periodIds and the schedule TaxonFact are ALWAYS derived from final ages so
// Deep Time, Identify, and Kids Mode stay on one catalog.

/** Flag when envelope and core differ by more than this many Ma. */
export const GAP_MA = 5;

/** Ma ranges overlap when each starts (older) after the other's end (younger). */
export const agesOverlap = (a, b) => a.startMa > b.endMa && b.startMa > a.endMa;

export const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

export const median = (xs) => {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
};

export const plausibleAge = (b, t) =>
  b != null && t != null && b > t && b - t <= 40 && b <= 550 && t >= 0;

/**
 * Period membership from a final age span. Period tables may come from the
 * ICS pin, PBDB, or a parallel Deep Time branch — this stays a pure overlap.
 */
export function periodIdsFor(startMa, endMa, periods) {
  return Object.entries(periods)
    .filter(([, p]) => p.startMa > endMa && p.endMa < startMa)
    .sort((a, b) => a[1].order - b[1].order || b[1].startMa - a[1].startMa)
    .map(([id]) => id);
}

/** Schedule chip regenerated from final ages + period membership. */
export function ageFact(startMa, endMa, periodIds, periods) {
  const old = Math.round(startMa);
  const young = Math.round(endMa);
  const value = old === young ? `${old}Ma` : `${old}–${young}Ma`;
  const first = periods[periodIds[0]]?.name;
  const last = periods[periodIds.at(-1)]?.name;
  const label = first === last ? (first ?? 'Age') : `${first}–${last}`;
  return { icon: 'schedule', value, label };
}

/**
 * Keep non-schedule facts (range, diet, etc.) but always replace the schedule
 * chip from the final age range so facts never lag ages.
 */
export function syncScheduleFact(facts, startMa, endMa, periodIds, periods) {
  const schedule = ageFact(startMa, endMa, periodIds, periods);
  const rest = (facts ?? []).filter((f) => f && f.icon !== 'schedule');
  return [schedule, ...rest];
}

export function rangeOf(dated) {
  if (!dated.length) return null;
  return {
    startMa: Math.max(...dated.map((d) => d.startMa)),
    endMa: Math.min(...dated.map((d) => d.endMa)),
  };
}

/**
 * Drop outermost start/end percentiles when the sample is large enough.
 * Helps Campanian Laramidia dinosaurs stuck at coarse 83.6 bins.
 */
export function percentileTrim(dated, { dropFraction = 0.1, minCount = 20 } = {}) {
  if (dated.length < minCount) return dated;
  const starts = [...dated.map((d) => d.startMa)].sort((a, b) => a - b);
  const ends = [...dated.map((d) => d.endMa)].sort((a, b) => a - b);
  const lo = Math.floor(dated.length * dropFraction);
  const hi = Math.max(lo + 1, Math.ceil(dated.length * (1 - dropFraction)) - 1);
  const startFloor = starts[lo];
  const startCeil = starts[hi];
  const endFloor = ends[lo];
  const endCeil = ends[hi];
  const kept = dated.filter(
    (d) =>
      d.startMa >= startFloor && d.startMa <= startCeil
      && d.endMa >= endFloor && d.endMa <= endCeil,
  );
  return kept.length >= Math.max(2, Math.floor(dated.length * 0.5)) ? kept : dated;
}

/**
 * Drop edges supported by only one occurrence and only one formation.
 * When the sample is large, require ≥2 formations for an edge (stricter).
 */
export function trimToCore(dated, { largeSample = 12 } = {}) {
  if (dated.length === 0) return null;
  let remaining = [...dated];
  const needTwoFormations = dated.length >= largeSample;

  for (let pass = 0; pass < 20; pass++) {
    if (remaining.length < 2) break;
    const start = Math.max(...remaining.map((d) => d.startMa));
    const end = Math.min(...remaining.map((d) => d.endMa));
    const edgeTol = 0.2;

    const oldEdge = remaining.filter((d) => Math.abs(d.startMa - start) <= edgeTol);
    const youngEdge = remaining.filter((d) => Math.abs(d.endMa - end) <= edgeTol);
    const oldFms = new Set(oldEdge.map((d) => d.formation).filter(Boolean));
    const youngFms = new Set(youngEdge.map((d) => d.formation).filter(Boolean));

    const oldOk = needTwoFormations
      ? oldFms.size >= 2
      : oldEdge.length >= 2 || oldFms.size >= 2;
    const youngOk = needTwoFormations
      ? youngFms.size >= 2
      : youngEdge.length >= 2 || youngFms.size >= 2;

    let next = remaining;
    if (!oldOk) {
      const drop = new Set(oldEdge);
      next = next.filter((d) => !drop.has(d));
    }
    if (!youngOk && next.length >= 2) {
      const drop = new Set(youngEdge);
      next = next.filter((d) => !drop.has(d));
    }

    if (next.length === remaining.length || next.length === 0) break;
    remaining = next;
  }

  if (remaining.length === 0) remaining = dated;
  return {
    startMa: Math.max(...remaining.map((d) => d.startMa)),
    endMa: Math.min(...remaining.map((d) => d.endMa)),
    occCount: remaining.length,
  };
}

/**
 * Reject a young edge that alone crosses a major boundary (e.g. K–Pg 66)
 * without multi-formation support — keeps Hell Creek dinosaurs out of Paleogene.
 */
export function clampMajorBoundaryYoungEdge(core, dated, boundaries = [66]) {
  if (!core) return core;
  let { startMa, endMa, occCount } = core;
  for (const boundary of boundaries) {
    if (endMa >= boundary || startMa <= boundary) continue;
    const youngEdge = dated.filter((d) => d.endMa < boundary);
    const fms = new Set(youngEdge.map((d) => d.formation).filter(Boolean));
    if (youngEdge.length < 2 && fms.size < 2) {
      endMa = boundary;
    }
  }
  return { startMa, endMa, occCount };
}

/** Absolute error helpers for gold-age eval. */
export function ageErrors(got, gold) {
  const startErr = Math.abs(got.ageStartMa - gold.ageStartMa);
  const endErr = Math.abs(got.ageEndMa - gold.ageEndMa);
  return {
    startErr,
    endErr,
    maxErr: Math.max(startErr, endErr),
    meanErr: (startErr + endErr) / 2,
  };
}

export function withinTol(got, gold, tolMa) {
  const { startErr, endErr } = ageErrors(got, gold);
  return startErr <= tolMa && endErr <= tolMa;
}
