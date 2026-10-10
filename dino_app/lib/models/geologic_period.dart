enum GeologicEra {
  paleozoic('Paleozoic'),
  mesozoic('Mesozoic'),
  cenozoic('Cenozoic');

  const GeologicEra(this.label);

  final String label;

  static GeologicEra fromWire(String raw) =>
      values.firstWhere((e) => e.label == raw);
}

/// One `periods/{id}` document. Ages follow the ICS chart as published by
/// PBDB. The id is the lowercase period name.
class GeologicPeriod {
  const GeologicPeriod({
    required this.id,
    required this.name,
    required this.era,
    required this.startMa,
    required this.endMa,
    required this.blurb,
    required this.order,
    this.color,
    this.pbdbIntervalId,
  });

  final String id;
  final String name;
  final GeologicEra era;

  /// Older boundary in millions of years.
  final double startMa;

  /// Younger boundary in millions of years.
  final double endMa;
  final String blurb;

  /// 1 for the oldest period (Cambrian).
  final int order;

  /// ICS chart color as `#RRGGBB`.
  final String? color;
  final String? pbdbIntervalId;

  factory GeologicPeriod.fromJson(String id, Map<String, dynamic> json) {
    return GeologicPeriod(
      id: id,
      name: json['name'] as String,
      era: GeologicEra.fromWire(json['era'] as String),
      startMa: (json['startMa'] as num).toDouble(),
      endMa: (json['endMa'] as num).toDouble(),
      blurb: json['blurb'] as String,
      order: (json['order'] as num).toInt(),
      color: json['color'] as String?,
      pbdbIntervalId: json['pbdbIntervalId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'era': era.label,
        'startMa': startMa,
        'endMa': endMa,
        'blurb': blurb,
        'order': order,
        'color': color,
        'pbdbIntervalId': pbdbIntervalId,
      };
}
