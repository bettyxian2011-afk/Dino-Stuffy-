import 'id_result.dart';

/// Where an animal lived, for the Kids explorer. Sky covers pterosaurs and
/// early birds.
enum TaxonRealm {
  land,
  sky,
  ocean;

  static TaxonRealm fromWire(String raw) => TaxonRealm.values.byName(raw);
}

/// PBDB record a [FossilTaxon] was built from. PBDB data is CC BY 4.0, so
/// keep [attribution] with the taxon.
class PbdbSource {
  const PbdbSource({
    required this.taxonNo,
    this.attribution,
    this.firstInterval,
    this.lastInterval,
    this.occurrences,
    this.extant = false,
  });

  /// PBDB identifier, e.g. `txn:38862`.
  final String taxonNo;
  final String? attribution;
  final String? firstInterval;
  final String? lastInterval;
  final int? occurrences;
  final bool extant;

  factory PbdbSource.fromJson(Map<String, dynamic> json) {
    return PbdbSource(
      taxonNo: json['taxonNo'] as String,
      attribution: json['attribution'] as String?,
      firstInterval: json['firstInterval'] as String?,
      lastInterval: json['lastInterval'] as String?,
      occurrences: (json['occurrences'] as num?)?.toInt(),
      extant: json['extant'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'taxonNo': taxonNo,
        'attribution': attribution,
        'firstInterval': firstInterval,
        'lastInterval': lastInterval,
        'occurrences': occurrences,
        'extant': extant,
      };
}

/// One `taxa/{id}` document: a genus shared by Identify, Deep Time, and
/// Kids Mode. The id is the lowercase genus name.
class FossilTaxon {
  const FossilTaxon({
    required this.id,
    required this.scientificName,
    required this.commonGroup,
    required this.family,
    required this.taxonomy,
    required this.realm,
    required this.periodIds,
    required this.facts,
    required this.imageAsset,
    this.commonName,
    this.ageStartMa,
    this.ageEndMa,
    this.funFacts = const [],
    this.tip = '',
    this.useInIdentify = false,
    this.kidSafe = false,
    this.iconic = false,
    this.pbdb,
  });

  final String id;
  final String scientificName;

  /// Kid-friendly name. `null` when nobody has written one; show
  /// [scientificName] instead.
  final String? commonName;
  final String commonGroup;
  final String family;
  final List<String> taxonomy;
  final TaxonRealm realm;
  final List<String> periodIds;

  /// Oldest age in millions of years.
  final double? ageStartMa;

  /// Youngest age in millions of years. `0` for living genera.
  final double? ageEndMa;
  final List<TaxonFact> facts;
  final List<String> funFacts;
  final String tip;
  final String imageAsset;
  final bool useInIdentify;
  final bool kidSafe;
  final bool iconic;
  final PbdbSource? pbdb;

  String get displayName => commonName ?? scientificName;

  factory FossilTaxon.fromJson(String id, Map<String, dynamic> json) {
    final pbdb = json['pbdb'] as Map<String, dynamic>?;
    return FossilTaxon(
      id: id,
      scientificName: json['scientificName'] as String,
      commonName: json['commonName'] as String?,
      commonGroup: json['commonGroup'] as String,
      family: json['family'] as String,
      taxonomy: (json['taxonomy'] as List<dynamic>).cast<String>(),
      realm: TaxonRealm.fromWire(json['realm'] as String),
      periodIds: (json['periodIds'] as List<dynamic>).cast<String>(),
      ageStartMa: (json['ageStartMa'] as num?)?.toDouble(),
      ageEndMa: (json['ageEndMa'] as num?)?.toDouble(),
      facts: (json['facts'] as List<dynamic>)
          .map((e) => TaxonFact.fromJson(e as Map<String, dynamic>))
          .toList(),
      funFacts:
          (json['funFacts'] as List<dynamic>? ?? const []).cast<String>(),
      tip: json['tip'] as String? ?? '',
      imageAsset: json['imageAsset'] as String,
      useInIdentify: json['useInIdentify'] as bool? ?? false,
      kidSafe: json['kidSafe'] as bool? ?? false,
      iconic: json['iconic'] as bool? ?? false,
      pbdb: pbdb == null ? null : PbdbSource.fromJson(pbdb),
    );
  }

  Map<String, dynamic> toJson() => {
        'scientificName': scientificName,
        'commonName': commonName,
        'commonGroup': commonGroup,
        'family': family,
        'taxonomy': taxonomy,
        'realm': realm.name,
        'periodIds': periodIds,
        'ageStartMa': ageStartMa,
        'ageEndMa': ageEndMa,
        'facts': facts.map((f) => f.toJson()).toList(),
        'funFacts': funFacts,
        'tip': tip,
        'imageAsset': imageAsset,
        'useInIdentify': useInIdentify,
        'kidSafe': kidSafe,
        'iconic': iconic,
        'pbdb': pbdb?.toJson(),
      };
}
