import 'dart:convert';
import 'dart:io';

import 'package:dino_app/data/repositories/taxon_repository.dart';
import 'package:dino_app/models/pbdb_taxon.dart';
import 'package:dino_app/screens/id_result/species_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PbdbTaxon.fromJson', () {
    test('parses Dactylioceras fixture including numeric rank', () {
      final file = File('test/fixtures/pbdb_dactylioceras.json');
      final body = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final records = body['records'] as List<dynamic>;
      final taxon = PbdbTaxon.fromJson(records.first as Map<String, dynamic>);

      expect(taxon.name, 'Dactylioceras');
      expect(taxon.rank, 'genus');
      expect(taxon.attribution, '(Hyatt 1867)');
      expect(taxon.occurrenceCount, 496);
      expect(taxon.firstInterval, 'Hettangian');
      expect(taxon.lastInterval, 'Bajocian');
      expect(taxon.ageRangeLabel, 'Hettangian – Bajocian');
    });

    test('accepts string rank and string occurrence count', () {
      final taxon = PbdbTaxon.fromJson({
        'nam': 'Elrathia',
        'rnk': 'genus',
        'noc': '12',
      });
      expect(taxon.rank, 'genus');
      expect(taxon.occurrenceCount, 12);
    });
  });

  group('SpeciesProfileScreen', () {
    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('shows PBDB fields from fake repository', (tester) async {
      final repo = _FakeTaxonRepository(
        taxon: const PbdbTaxon(
          name: 'Dactylioceras',
          rank: 'genus',
          attribution: '(Hyatt 1867)',
          firstInterval: 'Hettangian',
          lastInterval: 'Bajocian',
          occurrenceCount: 496,
        ),
      );

      await tester.pumpWidget(
        wrap(
          SpeciesProfileScreen(
            genus: 'Dactylioceras',
            commonGroup: 'Ammonite',
            family: 'Dactylioceratidae',
            taxonRepository: repo,
          ),
        ),
      );

      expect(find.text('Loading PBDB record…'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Dactylioceras'), findsWidgets);
      expect(
        find.text('Genus · Ammonite · Family Dactylioceratidae'),
        findsOneWidget,
      );
      expect(find.text('Hettangian – Bajocian'), findsOneWidget);
      expect(find.text('496 fossil occurrences'), findsOneWidget);
      expect(find.textContaining('PBDB record'), findsOneWidget);
    });

    testWidgets('shows error state and retries', (tester) async {
      final repo = _FakeTaxonRepository(
        taxon: const PbdbTaxon(
          name: 'Dactylioceras',
          rank: 'genus',
          occurrenceCount: 10,
          firstInterval: 'Hettangian',
          lastInterval: 'Bajocian',
        ),
        failuresBeforeSuccess: 1,
      );

      await tester.pumpWidget(
        wrap(
          SpeciesProfileScreen(
            genus: 'Dactylioceras',
            taxonRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load species profile.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Dactylioceras'), findsWidgets);
      expect(find.text('10 fossil occurrences'), findsOneWidget);
      expect(repo.findCalls, 2);
    });

    testWidgets('shows empty state when taxon is missing', (tester) async {
      final repo = _FakeTaxonRepository(taxon: null);

      await tester.pumpWidget(
        wrap(
          SpeciesProfileScreen(
            genus: 'Unknownus',
            commonGroup: 'Mystery',
            taxonRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unknownus'), findsWidgets);
      expect(
        find.textContaining('No Paleobiology Database record'),
        findsOneWidget,
      );
      expect(find.text('Retry PBDB lookup'), findsOneWidget);
    });
  });
}

class _FakeTaxonRepository implements TaxonRepository {
  _FakeTaxonRepository({
    required this.taxon,
    this.failuresBeforeSuccess = 0,
  });

  final PbdbTaxon? taxon;
  final int failuresBeforeSuccess;
  int findCalls = 0;

  @override
  Future<PbdbTaxon?> findTaxon(String name) async {
    findCalls += 1;
    if (findCalls <= failuresBeforeSuccess) {
      throw Exception('PBDB unavailable');
    }
    return taxon;
  }

  @override
  Future<List<PbdbTaxon>> getTimelineChain(String name) async => const [];
}
