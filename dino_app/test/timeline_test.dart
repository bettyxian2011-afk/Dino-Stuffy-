import 'package:dino_app/data/repositories/fossil_knowledge_repository.dart';
import 'package:dino_app/data/repositories/period_repository.dart';
import 'package:dino_app/data/catalog/knowledge_assets.dart';
import 'package:dino_app/models/fossil_taxon.dart';
import 'package:dino_app/models/geologic_period.dart';
import 'package:dino_app/models/id_result.dart';
import 'package:dino_app/screens/timeline/period_detail_screen.dart';
import 'package:dino_app/screens/timeline/timeline_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Periods implements PeriodRepository {
  @override
  Future<List<GeologicPeriod>> getPeriods() async => const [
    GeologicPeriod(
      id: 'cretaceous',
      name: 'Cretaceous',
      era: GeologicEra.mesozoic,
      startMa: 145,
      endMa: 66,
      blurb: 'Dinosaurs flourished before an asteroid impact ended the age.',
      order: 10,
      color: '#7FC64E',
    ),
  ];
}

class _Knowledge implements FossilKnowledgeRepository {
  static const animal = FossilTaxon(
    id: 'triceratops',
    scientificName: 'Triceratops',
    commonName: null,
    commonGroup: 'Dinosaur',
    family: 'Ceratopsidae',
    taxonomy: ['Animalia', 'Dinosauria'],
    realm: TaxonRealm.land,
    periodIds: ['cretaceous'],
    facts: [TaxonFact(icon: 'schedule', value: '68–66 Ma', label: 'Age')],
    imageAsset: 'assets/images/fossil_trilobite.png',
    iconic: true,
  );

  @override
  Future<FossilTaxon?> getTaxon(String id) async =>
      id == animal.id ? animal : null;
  @override
  Stream<FossilTaxon?> watchTaxon(String id) async* {
    yield await getTaxon(id);
  }

  @override
  Future<List<FossilTaxon>> taxaForIdentify() async => const [];
  @override
  Future<List<FossilTaxon>> iconicForPeriod(String periodId) async =>
      periodId == 'cretaceous' ? const [animal] : const [];
  @override
  Future<List<FossilTaxon>> kidPool(TaxonRealm realm, String periodId) async =>
      const [];
}

void main() {
  testWidgets(
    'period list opens its detail with age, story, and iconic fossils',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/timeline',
        routes: [
          GoRoute(
            path: '/timeline',
            builder: (_, _) => TimelineScreen(
              periodRepository: _Periods(),
              knowledgeRepository: _Knowledge(),
            ),
            routes: [
              GoRoute(
                path: ':periodId',
                builder: (_, state) => PeriodDetailScreen(
                  periodId: state.pathParameters['periodId']!,
                  periodRepository: _Periods(),
                  knowledgeRepository: _Knowledge(),
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Deep Time'), findsOneWidget);
      expect(find.text('Mesozoic'), findsOneWidget);
      expect(find.text('Cretaceous'), findsOneWidget);
      await tester.tap(find.text('Cretaceous'));
      await tester.pumpAndSettle();

      expect(find.text('145–66 million years ago'), findsOneWidget);
      expect(find.textContaining('Dinosaurs flourished'), findsOneWidget);
      expect(find.text('Iconic fossils'), findsOneWidget);
      expect(find.text('Triceratops'), findsNWidgets(2));
      expect(find.text('Ceratopsidae'), findsOneWidget);
    },
  );

  testWidgets('Cretaceous detail includes the five seeded land genera', (
    tester,
  ) async {
    final periods = await tester.runAsync(() => KnowledgeAssets.loadPeriods());
    final taxa = await tester.runAsync(() => KnowledgeAssets.loadTaxa());
    final router = GoRouter(
      initialLocation: '/timeline/cretaceous',
      routes: [
        GoRoute(
          path: '/timeline/:periodId',
          builder: (_, state) => PeriodDetailScreen(
            periodId: state.pathParameters['periodId']!,
            periodRepository: AssetPeriodRepository(periods: periods!),
            knowledgeRepository: AssetFossilKnowledgeRepository(taxa: taxa!),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Ankylosaurus'), findsNWidgets(2));
    expect(find.text('Pachycephalosaurus'), findsNWidgets(2));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    for (final genus in ['Triceratops', 'Tyrannosaurus', 'Velociraptor']) {
      expect(find.text(genus), findsNWidgets(2), reason: genus);
    }
    expect(find.text('Megalodon'), findsNothing);
  });
}
