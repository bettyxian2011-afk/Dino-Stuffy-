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

  factory PbdbTaxon.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? value) =>
        value == null ? null : double.tryParse(value.toString());

    return PbdbTaxon(
      name: json['nam'] as String,
      rank: json['rnk'] as String,
      attribution: json['att'] as String?,
      firstAppearanceMa: asDouble(json['fea']),
      lastAppearanceMa: asDouble(json['lea']),
      firstInterval: json['tei'] as String?,
      lastInterval: json['tli'] as String?,
      occurrenceCount: json['noc'] as int?,
    );
  }
}
