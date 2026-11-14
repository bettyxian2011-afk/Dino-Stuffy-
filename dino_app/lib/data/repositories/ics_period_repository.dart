import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:locorda_rdf_core/core.dart';

import '../../models/geologic_period.dart';
import 'period_repository.dart';

/// Reads period boundaries and colors from the ICS chart's Turtle source.
///
/// The ICS chart page identifies `chart.ttl` as its machine-readable dataset.
class IcsPeriodRepository implements PeriodRepository {
  IcsPeriodRepository({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  static const dataUrl =
      'https://raw.githubusercontent.com/i-c-stratigraphy/chart/main/chart.ttl';

  static const _gts = 'http://resource.geosciml.org/ontology/timescale/gts#';
  static const _rank = 'http://resource.geosciml.org/ontology/timescale/rank/';
  static const _skos = 'http://www.w3.org/2004/02/skos/core#';
  static const _time = 'http://www.w3.org/2006/time#';
  static const _schema = 'https://schema.org/';
  static const _chartData = 'https://data.stratigraphy.org/data/gts/';

  final http.Client _client;
  final Duration timeout;
  Future<List<GeologicPeriod>>? _cachedPeriods;

  @override
  Future<List<GeologicPeriod>> getPeriods() {
    final cached = _cachedPeriods;
    if (cached != null) return cached;
    final future = _loadPeriods();
    _cachedPeriods = future;
    return future.catchError((Object error, StackTrace stackTrace) {
      if (identical(_cachedPeriods, future)) _cachedPeriods = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<List<GeologicPeriod>> _loadPeriods() async {
    final response = await _client
        .get(Uri.parse(dataUrl), headers: const {'Accept': 'text/turtle'})
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw HttpException(
        'ICS chart request failed (${response.statusCode})',
        uri: Uri.parse(dataUrl),
      );
    }
    return parseChart(response.body);
  }

  /// Parses the period level of the ICS chart.
  static List<GeologicPeriod> parseChart(String turtleText) {
    final graph = turtle.decode(turtleText);
    final periodSubjects = graph
        .findTriples(
          predicate: const IriTerm('${_gts}rank'),
          object: const IriTerm('${_rank}Period'),
        )
        .map((triple) => triple.subject)
        .whereType<IriTerm>()
        .toSet();

    final periods = <GeologicPeriod>[];
    for (final subject in periodSubjects) {
      final name = _localName(subject.value);
      final eraName = _firstIriLocalName(
        graph,
        subject,
        const IriTerm('${_skos}broader'),
      );
      final era = GeologicEra.values.where((value) => value.label == eraName);
      if (era.isEmpty) continue;

      final startMa = _boundary(graph, subject, '${_time}hasBeginning');
      final endMa = _boundary(graph, subject, '${_time}hasEnd');
      if (startMa == null || endMa == null) continue;

      final id = name.toLowerCase();
      periods.add(
        GeologicPeriod(
          id: id,
          name: name,
          era: era.first,
          startMa: startMa,
          endMa: endMa,
          blurb: '',
          order: 0,
          color: _literal(graph, subject, const IriTerm('${_schema}color')),
        ),
      );
    }

    periods.sort((a, b) => b.startMa.compareTo(a.startMa));
    for (var index = 0; index < periods.length; index++) {
      final period = periods[index];
      periods[index] = GeologicPeriod(
        id: period.id,
        name: period.name,
        era: period.era,
        startMa: period.startMa,
        endMa: period.endMa,
        blurb: period.blurb,
        order: index + 1,
        color: period.color,
      );
    }

    if (periods.length != 12) {
      throw FormatException(
        'Expected 12 Phanerozoic periods from ICS, found ${periods.length}',
      );
    }
    return periods;
  }

  static String _localName(String iri) => iri.split('/').last;

  static String? _firstIriLocalName(
    RdfGraph graph,
    RdfSubject subject,
    IriTerm predicate,
  ) => graph
      .findTriples(subject: subject, predicate: predicate)
      .map((triple) => triple.object)
      .whereType<IriTerm>()
      .map((iri) => _localName(iri.value))
      .firstOrNull;

  static String? _literal(
    RdfGraph graph,
    RdfSubject subject,
    IriTerm predicate,
  ) => graph
      .findTriples(subject: subject, predicate: predicate)
      .map((triple) => triple.object)
      .whereType<LiteralTerm>()
      .map((literal) => literal.value)
      .firstOrNull;

  static double? _boundary(
    RdfGraph graph,
    RdfSubject subject,
    String predicate,
  ) {
    final node = graph
        .findTriples(subject: subject, predicate: IriTerm(predicate))
        .map((triple) => triple.object)
        .whereType<RdfSubject>()
        .firstOrNull;
    if (node == null) return null;
    final numeric = _literal(graph, node, const IriTerm('${_chartData}inMYA'));
    return numeric == null ? null : double.tryParse(numeric);
  }
}

/// Overlays ICS period boundaries and colors on curated Firestore/asset data.
/// Firestore and bundled data continue to provide app copy and PBDB mappings.
class IcsOverlayPeriodRepository implements PeriodRepository {
  IcsOverlayPeriodRepository({required this.base, required this.ics});

  final PeriodRepository base;
  final PeriodRepository ics;

  @override
  Future<List<GeologicPeriod>> getPeriods() async {
    final icsFuture = ics.getPeriods().then<List<GeologicPeriod>?>((value) {
      return value;
    }, onError: (Object _, StackTrace _) => null);
    final curated = await base.getPeriods();
    final official = await icsFuture;
    if (official == null || official.isEmpty) return curated;

    final byId = {for (final period in official) period.id: period};
    final merged = curated
        .map((period) {
          final canonical = byId[period.id];
          if (canonical == null) return period;
          return GeologicPeriod(
            id: period.id,
            name: canonical.name,
            era: canonical.era,
            startMa: canonical.startMa,
            endMa: canonical.endMa,
            blurb: period.blurb,
            order: canonical.order,
            color: canonical.color ?? period.color,
            pbdbIntervalId: period.pbdbIntervalId,
          );
        })
        .toList(growable: false);
    merged.sort((a, b) => a.order.compareTo(b.order));
    return merged;
  }
}
