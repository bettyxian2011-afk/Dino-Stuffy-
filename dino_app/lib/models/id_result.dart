class TaxonFact {
  const TaxonFact({
    required this.icon,
    required this.value,
    required this.label,
  });

  final String icon;
  final String value;
  final String label;

  factory TaxonFact.fromJson(Map<String, dynamic> json) {
    return TaxonFact(
      icon: json['icon'] as String,
      value: json['value'] as String,
      label: json['label'] as String,
    );
  }
}

class IdCandidate {
  const IdCandidate({
    required this.genus,
    required this.commonGroup,
    required this.family,
    required this.confidence,
    required this.thumbnail,
    required this.isBestMatch,
    this.modelConfidence,
  });

  final String genus;
  final String commonGroup;
  final String family;
  /// Heuristic-adjusted confidence shown in the UI.
  final int confidence;
  final String thumbnail;
  final bool isBestMatch;
  /// Raw model score before PBDB/catalog adjustments.
  final int? modelConfidence;

  String get classificationLabel => '$commonGroup · Family $family';

  factory IdCandidate.fromJson(Map<String, dynamic> json) {
    return IdCandidate(
      genus: json['genus'] as String,
      commonGroup: json['commonGroup'] as String,
      family: json['family'] as String,
      confidence: json['confidence'] as int,
      thumbnail: json['thumbnail'] as String,
      isBestMatch: json['isBestMatch'] as bool? ?? false,
    );
  }
}

enum IdentificationSource { mock, geminiPbdb }

/// Vision assessment for the whole photo (not per-candidate).
enum IdentifyAssessment {
  fossil,
  mayNotBeFossil,
  uncertain;

  static IdentifyAssessment fromWire(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'may_not_be_fossil':
      case 'may-not-be-fossil':
      case 'rock':
      case 'non_fossil':
        return IdentifyAssessment.mayNotBeFossil;
      case 'uncertain':
      case 'unclear':
        return IdentifyAssessment.uncertain;
      case 'fossil':
      default:
        return IdentifyAssessment.fossil;
    }
  }

  String get wireValue => switch (this) {
        IdentifyAssessment.fossil => 'fossil',
        IdentifyAssessment.mayNotBeFossil => 'may_not_be_fossil',
        IdentifyAssessment.uncertain => 'uncertain',
      };
}

class IdResult {
  const IdResult({
    required this.id,
    required this.specimenImage,
    required this.confidenceLabel,
    required this.matchLabel,
    required this.tip,
    required this.taxonomy,
    required this.candidates,
    required this.facts,
    this.timelineLabel,
    this.pbdbVerified = false,
    this.source = IdentificationSource.mock,
    this.assessment = IdentifyAssessment.fossil,
    this.rockType,
    this.reason,
    this.primaryConfidence,
  });

  final String id;
  final String specimenImage;
  final String confidenceLabel;
  final String matchLabel;
  final String tip;
  final List<String> taxonomy;
  final List<IdCandidate> candidates;
  final List<TaxonFact> facts;
  final String? timelineLabel;
  final bool pbdbVerified;
  final IdentificationSource source;
  final IdentifyAssessment assessment;
  final String? rockType;
  final String? reason;
  /// Overall confidence used for “needs more info” gating (0–100).
  final int? primaryConfidence;

  bool get isFossilMatch =>
      assessment == IdentifyAssessment.fossil && candidates.isNotEmpty;

  bool get isRockAssessment =>
      assessment == IdentifyAssessment.mayNotBeFossil;

  bool get isUncertain => assessment == IdentifyAssessment.uncertain;

  /// Show the notes / re-identify panel.
  ///
  /// Always true for rocks & other non-biogenic assessments (high confidence
  /// is often misleading — many rocks look alike). Also true when uncertain
  /// or displayed confidence is under 60%.
  bool get needsMoreInfo {
    if (isRockAssessment || isUncertain) return true;
    final score = primaryConfidence ??
        (candidates.isNotEmpty ? bestMatch.confidence : null);
    if (score == null) return false;
    return score < 60;
  }

  IdCandidate get bestMatch =>
      candidates.firstWhere((c) => c.isBestMatch, orElse: () => candidates.first);

  List<IdCandidate> get alternatives =>
      candidates.where((c) => !c.isBestMatch).toList();

  factory IdResult.fromJson(Map<String, dynamic> json) {
    return IdResult(
      id: json['id'] as String,
      specimenImage: json['specimenImage'] as String,
      confidenceLabel: json['confidenceLabel'] as String,
      matchLabel: json['matchLabel'] as String,
      tip: json['tip'] as String,
      taxonomy: (json['taxonomy'] as List<dynamic>).cast<String>(),
      candidates: (json['candidates'] as List<dynamic>)
          .map((e) => IdCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      facts: (json['facts'] as List<dynamic>)
          .map((e) => TaxonFact.fromJson(e as Map<String, dynamic>))
          .toList(),
      assessment: IdentifyAssessment.fromWire(json['assessment'] as String?),
      rockType: json['rockType'] as String?,
      reason: json['reason'] as String?,
      primaryConfidence: json['primaryConfidence'] as int?,
    );
  }
}
