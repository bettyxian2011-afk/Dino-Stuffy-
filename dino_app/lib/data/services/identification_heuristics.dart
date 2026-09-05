/// Combines model scores with local catalog + PBDB signals.
class IdentificationHeuristics {
  const IdentificationHeuristics._();

  static int adjustedConfidence({
    required int modelConfidence,
    required bool inLocalCatalog,
    required bool inPbdb,
    int? pbdbOccurrences,
  }) {
    var score = modelConfidence.toDouble();
    if (inPbdb) score += 8;
    if (inLocalCatalog) score += 5;
    if (pbdbOccurrences != null) {
      if (pbdbOccurrences >= 100) {
        score += 4;
      } else if (pbdbOccurrences >= 10) {
        score += 2;
      }
    }
    return score.round().clamp(5, 99);
  }

  static String confidenceLabel(int confidence) {
    if (confidence >= 80) return 'HIGH CONFIDENCE';
    if (confidence >= 55) return 'MEDIUM CONFIDENCE';
    return 'LOW CONFIDENCE';
  }

  static String verificationNote({
    required bool inPbdb,
    required bool inLocalCatalog,
    required int? pbdbOccurrences,
  }) {
    if (inPbdb && inLocalCatalog) {
      final count = pbdbOccurrences ?? 0;
      return 'Verified against Strata catalog and PBDB ($count fossil occurrences).';
    }
    if (inPbdb) {
      return 'Genus found in the Paleobiology Database; refine with scale-bar photos.';
    }
    if (inLocalCatalog) {
      return 'Matches Strata reference set; PBDB has no record under this spelling.';
    }
    return 'Provisional ID — add clearer photos or a scale bar to improve accuracy.';
  }
}
