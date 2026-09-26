/// Combines model scores with local catalog + PBDB corroboration.
///
/// PBDB “name exists” alone never boosts confidence. Soft boosts apply only
/// when raw model confidence is at least [boostFloor].
class IdentificationHeuristics {
  const IdentificationHeuristics._();

  /// Raw model confidence below this receives no catalog/PBDB additives.
  static const int boostFloor = 60;

  static int adjustedConfidence({
    required int modelConfidence,
    required bool inLocalCatalog,
    required bool pbdbGenusRank,
    int? pbdbOccurrences,
  }) {
    final raw = modelConfidence.clamp(0, 100);
    if (raw < boostFloor) {
      return raw;
    }

    var score = raw.toDouble();
    if (inLocalCatalog) score += 3;
    if (pbdbGenusRank) score += 2;
    if (pbdbOccurrences != null) {
      if (pbdbOccurrences >= 100) {
        score += 3;
      } else if (pbdbOccurrences >= 10) {
        score += 1;
      }
    }
    return score.round().clamp(0, 99);
  }

  static String confidenceLabel(int confidence) {
    if (confidence >= 80) return 'HIGH CONFIDENCE';
    if (confidence >= 55) return 'MEDIUM CONFIDENCE';
    return 'LOW CONFIDENCE';
  }

  /// Honest copy: PBDB is a double-check / fact source, not photo proof.
  static String doubleCheckNote({
    required int modelConfidence,
    required bool inPbdb,
    required bool inLocalCatalog,
    required int? pbdbOccurrences,
  }) {
    if (modelConfidence < boostFloor) {
      return 'Provisional ID (model ${modelConfidence}%). '
          'PBDB/catalog were not used to boost this score — '
          'add a clearer photo or scale bar.';
    }
    if (inPbdb && inLocalCatalog) {
      final count = pbdbOccurrences;
      final occ = count == null ? '' : ' ($count published occurrences)';
      return 'In the Strata catalog; PBDB also has a record for this name$occ. '
          'Treat PBDB as a double-check, not proof from the photo.';
    }
    if (inPbdb) {
      return 'PBDB has a record for this name — use as a double-check, '
          'not proof from the photo.';
    }
    if (inLocalCatalog) {
      return 'Matches the Strata reference set; PBDB has no record under '
          'this spelling.';
    }
    return 'Provisional ID — add clearer photos or a scale bar to improve accuracy.';
  }

  /// @nodoc Kept for older call sites; prefer [doubleCheckNote].
  @Deprecated('Use doubleCheckNote')
  static String verificationNote({
    required bool inPbdb,
    required bool inLocalCatalog,
    required int? pbdbOccurrences,
  }) {
    return doubleCheckNote(
      modelConfidence: boostFloor,
      inPbdb: inPbdb,
      inLocalCatalog: inLocalCatalog,
      pbdbOccurrences: pbdbOccurrences,
    );
  }
}
