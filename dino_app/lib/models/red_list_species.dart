/// IUCN Red List categories, stored by their two-letter code.
enum IucnStatus {
  extinctInTheWild('EW', 'Extinct in the Wild'),
  criticallyEndangered('CR', 'Critically Endangered'),
  endangered('EN', 'Endangered'),
  vulnerable('VU', 'Vulnerable'),
  nearThreatened('NT', 'Near Threatened'),
  leastConcern('LC', 'Least Concern'),
  dataDeficient('DD', 'Data Deficient');

  const IucnStatus(this.code, this.label);

  final String code;
  final String label;

  static IucnStatus fromCode(String code) =>
      values.firstWhere((s) => s.code == code);
}

/// One `redListSpecies/{id}` document. Living species only, kept out of
/// `taxa` so Identify can never match a photo to them.
class RedListSpecies {
  const RedListSpecies({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.status,
    required this.habitat,
    required this.imageAsset,
    this.threats = const [],
    this.funFacts = const [],
    this.kidSafe = false,
    this.iucnUrl,
  });

  final String id;
  final String commonName;
  final String scientificName;
  final IucnStatus status;
  final String habitat;
  final List<String> threats;
  final List<String> funFacts;
  final String imageAsset;
  final bool kidSafe;

  /// The species' page on iucnredlist.org, credited wherever [status] shows.
  final String? iucnUrl;

  factory RedListSpecies.fromJson(String id, Map<String, dynamic> json) {
    return RedListSpecies(
      id: id,
      commonName: json['commonName'] as String,
      scientificName: json['scientificName'] as String,
      status: IucnStatus.fromCode(json['status'] as String),
      habitat: json['habitat'] as String,
      threats: (json['threats'] as List<dynamic>? ?? const []).cast<String>(),
      funFacts:
          (json['funFacts'] as List<dynamic>? ?? const []).cast<String>(),
      imageAsset: json['imageAsset'] as String,
      kidSafe: json['kidSafe'] as bool? ?? false,
      iucnUrl: json['iucnUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'commonName': commonName,
        'scientificName': scientificName,
        'status': status.code,
        'habitat': habitat,
        'threats': threats,
        'funFacts': funFacts,
        'imageAsset': imageAsset,
        'kidSafe': kidSafe,
        'iucnUrl': iucnUrl,
      };
}
