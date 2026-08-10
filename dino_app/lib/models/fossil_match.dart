class FossilMatch {
  const FossilMatch({
    required this.id,
    required this.speciesName,
    required this.era,
    required this.ageMa,
    required this.confidence,
    required this.imageAsset,
  });

  final String id;
  final String speciesName;
  final String era;
  final int ageMa;
  final int confidence;
  final String imageAsset;

  String get eraLabel => '$era · $ageMa Ma';
  String get matchLabel => '$confidence% MATCH';
}
