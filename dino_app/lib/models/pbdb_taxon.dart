class PbdbTaxon {
  const PbdbTaxon({
    required this.name,
    required this.rank,
    this.attribution,
    this.firstAppearanceMa,
    this.lastAppearanceMa,
    this.firstInterval,
    this.lastInterval,
    this.occurrenceCount,
  });

  final String name;
  final String rank;
  final String? attribution;
  final double? firstAppearanceMa;
  final double? lastAppearanceMa;
  final String? firstInterval;
  final String? lastInterval;
  final int? occurrenceCount;

  /// Compact-vocab PBDB rank codes → display names.
  static const Map<int, String> rankCodes = {
    2: 'subspecies',
    3: 'species',
    4: 'subgenus',
    5: 'genus',
    6: 'subtribe',
    7: 'tribe',
    8: 'subfamily',
    9: 'family',
    10: 'superfamily',
    11: 'infraorder',
    12: 'suborder',
    13: 'order',
    14: 'superorder',
    15: 'infraclass',
    16: 'subclass',
    17: 'class',
    18: 'superclass',
    19: 'subphylum',
    20: 'phylum',
    21: 'superphylum',
    22: 'subkingdom',
    23: 'kingdom',
    25: 'unranked clade',
    26: 'informal',
  };

  String get ageRangeLabel {
    if (firstInterval != null && lastInterval != null) {
      return '$firstInterval – $lastInterval';
    }
    if (firstAppearanceMa != null && lastAppearanceMa != null) {
      final young = lastAppearanceMa!.round();
      final old = firstAppearanceMa!.round();
      return '$young–$old Ma';
    }
    return 'Age unknown';
  }

  static String parseRank(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is num) {
      final code = value.toInt();
      return rankCodes[code] ?? 'rank $code';
    }
    return 'unknown';
  }

  static int? parseOccurrenceCount(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory PbdbTaxon.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? value) =>
        value == null ? null : double.tryParse(value.toString());

    return PbdbTaxon(
      name: json['nam'] as String,
      rank: parseRank(json['rnk']),
      attribution: json['att'] as String?,
      firstAppearanceMa: asDouble(json['fea']),
      lastAppearanceMa: asDouble(json['lea']),
      firstInterval: json['tei'] as String?,
      lastInterval: json['tli'] as String?,
      occurrenceCount: parseOccurrenceCount(json['noc']),
    );
  }
}
