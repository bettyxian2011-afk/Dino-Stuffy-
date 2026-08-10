class GeologicalSite {
  const GeologicalSite({
    required this.id,
    required this.headline,
    required this.formation,
    required this.stage,
    required this.ageMa,
    required this.siteCount,
    required this.radiusMiles,
    required this.imageAsset,
  });

  final String id;
  final String headline;
  final String formation;
  final String stage;
  final int ageMa;
  final int siteCount;
  final int radiusMiles;
  final String imageAsset;

  String get detailLabel => '$formation · $stage · $ageMa Ma';
}
