import 'package:dino_app/data/repositories/ics_period_repository.dart';
import 'package:dino_app/data/repositories/period_repository.dart';
import 'package:dino_app/models/geologic_period.dart';
import 'package:flutter_test/flutter_test.dart';

const _periods = <(String, String, double, double)>[
  ('Cambrian', 'Paleozoic', 538.8, 486.85),
  ('Ordovician', 'Paleozoic', 486.85, 443.1),
  ('Silurian', 'Paleozoic', 443.1, 419.62),
  ('Devonian', 'Paleozoic', 419.62, 358.86),
  ('Carboniferous', 'Paleozoic', 358.86, 298.9),
  ('Permian', 'Paleozoic', 298.9, 251.902),
  ('Triassic', 'Mesozoic', 251.902, 201.4),
  ('Jurassic', 'Mesozoic', 201.4, 143.1),
  ('Cretaceous', 'Mesozoic', 143.1, 66),
  ('Paleogene', 'Cenozoic', 66, 23.03),
  ('Neogene', 'Cenozoic', 23.03, 2.58),
  ('Quaternary', 'Cenozoic', 2.58, 0),
];

String get _chartTurtle =>
    '''
PREFIX cs: <https://data.stratigraphy.org/def/chart>
PREFIX gtsd: <https://data.stratigraphy.org/data/gts/>
PREFIX gts: <http://resource.geosciml.org/ontology/timescale/gts#>
PREFIX rank: <http://resource.geosciml.org/ontology/timescale/rank/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX time: <http://www.w3.org/2006/time#>
PREFIX schema: <https://schema.org/>
PREFIX owl: <http://www.w3.org/2002/07/owl#>

cs: owl:versionInfo "2026-06" .
${_periods.map((period) => '''
gtsd:${period.$1}
    a skos:Concept ;
    gts:rank rank:Period ;
    skos:broader gtsd:${period.$2} ;
    time:hasBeginning [ gtsd:inMYA ${period.$3} ; ] ;
    time:hasEnd [ gtsd:inMYA ${period.$4} ; ] ;
    schema:color "#123456" ;
.
''').join('\n')}
''';

class _BasePeriods implements PeriodRepository {
  _BasePeriods(this.periods);
  final List<GeologicPeriod> periods;

  @override
  Future<List<GeologicPeriod>> getPeriods() async => periods;
}

class _IcsPeriods implements PeriodRepository {
  @override
  Future<List<GeologicPeriod>> getPeriods() async =>
      IcsPeriodRepository.parseChart(_chartTurtle);
}

class _UnavailableIcsPeriods implements PeriodRepository {
  @override
  Future<List<GeologicPeriod>> getPeriods() =>
      Future.error(StateError('offline'));
}

void main() {
  test('parses current ICS Turtle period data and version', () {
    final periods = IcsPeriodRepository.parseChart(_chartTurtle);

    expect(periods, hasLength(12));
    expect(periods.map((period) => period.id).first, 'cambrian');
    expect(periods.map((period) => period.id).last, 'quaternary');

    final cretaceous = periods.singleWhere(
      (period) => period.id == 'cretaceous',
    );
    expect(cretaceous.era, GeologicEra.mesozoic);
    expect(cretaceous.startMa, 143.1);
    expect(cretaceous.endMa, 66);
    expect(cretaceous.color, '#123456');
    expect(cretaceous.sourceVersion, '2026-06');
    expect(cretaceous.sourceUrl, IcsPeriodRepository.chartUrl);
  });

  test(
    'ICS boundaries and colors override curated values, preserving app copy',
    () async {
      final baseCretaceous = GeologicPeriod(
        id: 'cretaceous',
        name: 'Cretaceous',
        era: GeologicEra.mesozoic,
        startMa: 145,
        endMa: 66,
        blurb: 'Curated period description.',
        order: 9,
        color: '#FFFFFF',
        pbdbIntervalId: 'int:14',
      );
      final repository = IcsOverlayPeriodRepository(
        base: _BasePeriods([baseCretaceous]),
        ics: _IcsPeriods(),
      );

      final result = await repository.getPeriods();
      final cretaceous = result.single;
      expect(cretaceous.startMa, 143.1);
      expect(cretaceous.endMa, 66);
      expect(cretaceous.color, '#123456');
      expect(cretaceous.blurb, 'Curated period description.');
      expect(cretaceous.pbdbIntervalId, 'int:14');
      expect(cretaceous.sourceVersion, '2026-06');
    },
  );

  test(
    'keeps curated timeline data when the ICS endpoint is unavailable',
    () async {
      final basePeriod = GeologicPeriod(
        id: 'cretaceous',
        name: 'Cretaceous',
        era: GeologicEra.mesozoic,
        startMa: 145,
        endMa: 66,
        blurb: 'Offline description.',
        order: 9,
      );
      final repository = IcsOverlayPeriodRepository(
        base: _BasePeriods([basePeriod]),
        ics: _UnavailableIcsPeriods(),
      );

      expect(await repository.getPeriods(), [basePeriod]);
    },
  );
}
