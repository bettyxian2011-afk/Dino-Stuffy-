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
  });

  final String genus;
  final String commonGroup;
  final String family;
  final int confidence;
  final String thumbnail;
  final bool isBestMatch;

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
  });

  final String id;
  final String specimenImage;
  final String confidenceLabel;
  final String matchLabel;
  final String tip;
  final List<String> taxonomy;
  final List<IdCandidate> candidates;
  final List<TaxonFact> facts;

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
    );
  }
}
