import 'id_result.dart';

/// Where an animal lived, for the Kids explorer. Sky covers pterosaurs and
/// early birds.
enum TaxonRealm {
  land,
  sky,
  ocean;

  static TaxonRealm fromWire(String raw) => TaxonRealm.values.byName(raw);
}

/// How [FossilTaxon.ageStartMa] / [ageEndMa] were chosen.
enum AgeSource {
  /// Hand-set in seed/curated or the Firebase console.
  manual,

  /// Majority of dated occurrences used Macrostrat formation ages.
  macrostrat,

  /// Outlier-trimmed range from certain PBDB occurrences.
  pbdbCore,

  /// Widest PBDB genus-summary appearance (last-resort fallback).
  pbdbEnvelope;

  static AgeSource? fromWire(String? raw) {
    if (raw == null) return null;
    return switch (raw) {
      'manual' => AgeSource.manual,
      'macrostrat' => AgeSource.macrostrat,
      'pbdb-core' => AgeSource.pbdbCore,
      'pbdb-envelope' => AgeSource.pbdbEnvelope,
      _ => null,
    };
  }

  String get wireValue => switch (this) {
        AgeSource.manual => 'manual',
        AgeSource.macrostrat => 'macrostrat',
        AgeSource.pbdbCore => 'pbdb-core',
        AgeSource.pbdbEnvelope => 'pbdb-envelope',
      };
}

/// A Ma range computed during seeding (envelope = all certain occs,
/// core = outlier-trimmed).
class AgeRange {
  const AgeRange({required this.startMa, required this.endMa});

  final double startMa;
  final double endMa;

  factory AgeRange.fromJson(Map<String, dynamic> json) => AgeRange(
        startMa: (json['startMa'] as num).toDouble(),
        endMa: (json['endMa'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'startMa': startMa,
        'endMa': endMa,
      };
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
    this.certainOccurrences,
    this.formationsUsed = const [],
    this.extant = false,
  });

  /// PBDB identifier, e.g. `txn:38862`.
  final String taxonNo;
  final String? attribution;
  final String? firstInterval;
  final String? lastInterval;
  final int? occurrences;

  /// Count of certain-identification occurrences used for the age range.
  final int? certainOccurrences;
  final List<String> formationsUsed;
  final bool extant;

  factory PbdbSource.fromJson(Map<String, dynamic> json) {
    return PbdbSource(
      taxonNo: json['taxonNo'] as String,
      attribution: json['attribution'] as String?,
      firstInterval: json['firstInterval'] as String?,
      lastInterval: json['lastInterval'] as String?,
      occurrences: (json['occurrences'] as num?)?.toInt(),
      certainOccurrences: (json['certainOccurrences'] as num?)?.toInt(),
      formationsUsed:
          (json['formationsUsed'] as List<dynamic>? ?? const []).cast<String>(),
      extant: json['extant'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'taxonNo': taxonNo,
        'attribution': attribution,
        'firstInterval': firstInterval,
        'lastInterval': lastInterval,
        'occurrences': occurrences,
        'certainOccurrences': certainOccurrences,
        'formationsUsed': formationsUsed,
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
    this.ageSource,
    this.ageEnvelope,
    this.ageCore,
    this.reviewed = false,
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

  /// Oldest age in millions of years (core range, or a manual override).
  final double? ageStartMa;

  /// Youngest age in millions of years. `0` for living genera.
  final double? ageEndMa;
  final AgeSource? ageSource;

  /// Widest span of certain dated occurrences, before outlier trimming.
  final AgeRange? ageEnvelope;

  /// Outlier-trimmed span; usually the same as [ageStartMa]/[ageEndMa]
  /// unless [ageSource] is [AgeSource.manual].
  final AgeRange? ageCore;

  /// When true, seed rebuild and upload leave this document alone.
  final bool reviewed;
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
    final envelope = json['ageEnvelope'] as Map<String, dynamic>?;
    final core = json['ageCore'] as Map<String, dynamic>?;
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
      ageSource: AgeSource.fromWire(json['ageSource'] as String?),
      ageEnvelope: envelope == null ? null : AgeRange.fromJson(envelope),
      ageCore: core == null ? null : AgeRange.fromJson(core),
      reviewed: json['reviewed'] as bool? ?? false,
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
        'ageSource': ageSource?.wireValue,
        'ageEnvelope': ageEnvelope?.toJson(),
        'ageCore': ageCore?.toJson(),
        'reviewed': reviewed,
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
