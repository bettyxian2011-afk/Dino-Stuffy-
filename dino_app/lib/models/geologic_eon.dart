/// Broad eon spans used by the Deep Time clock before and through the
/// Phanerozoic periods already represented in the shared catalog.
class GeologicEon {
  const GeologicEon({
    required this.name,
    required this.startMa,
    required this.endMa,
    required this.colorValue,
    required this.blurb,
  });

  final String name;
  final double startMa;
  final double endMa;
  final int colorValue;
  final String blurb;

  static const hadean = GeologicEon(
    name: 'Hadean',
    startMa: 4567,
    endMa: 4031,
    colorValue: 0xFF7A5A45,
    blurb:
        'Earth formed and began to cool. The first crust and oceans took '
        'shape, though rocks from this earliest eon are rare.',
  );

  static const archean = GeologicEon(
    name: 'Archean (Archaean)',
    startMa: 4031,
    endMa: 2500,
    colorValue: 0xFF168C86,
    blurb:
        'The oldest preserved rocks formed, and early microbial life '
        'changed Earth’s oceans and atmosphere.',
  );

  static const proterozoic = GeologicEon(
    name: 'Proterozoic',
    startMa: 2500,
    endMa: 538.8,
    colorValue: 0xFF5267A5,
    blurb:
        'Oxygen accumulated in the atmosphere, complex cells evolved, and '
        'multicellular life appeared before the Cambrian.',
  );

  static const phanerozoic = GeologicEon(
    name: 'Phanerozoic',
    startMa: 538.8,
    endMa: 0,
    colorValue: 0xFF9A773D,
    blurb:
        'The eon of abundant visible life, subdivided here into the '
        'Paleozoic, Mesozoic, and Cenozoic eras.',
  );

  static const precambrian = [hadean, archean, proterozoic];
  static const all = [...precambrian, phanerozoic];
}
