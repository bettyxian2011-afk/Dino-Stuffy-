import 'dart:typed_data';

import 'package:dino_app/data/repositories/identify_repository.dart';
import 'package:dino_app/models/captured_specimen.dart';
import 'package:dino_app/models/id_result.dart';
import 'package:dino_app/screens/id_result/id_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('shows genus from a successful identify call', (tester) async {
    final sampleResult = IdResult(
      id: 'test-1',
      specimenImage: 'assets/images/fossil_ammonite.png',
      confidenceLabel: 'HIGH CONFIDENCE',
      matchLabel: 'Best match · likely genus',
      tip: 'Add a close-up of the shell ridges.',
      taxonomy: const ['Mollusca', 'Cephalopoda', 'Ammonoidea'],
      candidates: const [
        IdCandidate(
          genus: 'Dactylioceras',
          commonGroup: 'Ammonite',
          family: 'Dactylioceratidae',
          confidence: 92,
          thumbnail: 'assets/images/fossil_ammonite.png',
          isBestMatch: true,
        ),
      ],
      facts: const [
        TaxonFact(icon: 'schedule', value: '180Ma', label: 'Early Jurassic'),
      ],
    );
    final repo = _FakeIdentifyRepository(result: sampleResult);
    await tester.pumpWidget(
      wrap(
        IdResultScreen(
          captured: CapturedSpecimen(bytes: Uint8List.fromList([1, 2, 3])),
          repository: repo,
        ),
      ),
    );

    expect(find.text('Identifying specimen…'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Dactylioceras'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(repo.identifyCalls, 1);
  });

  testWidgets('shows error and recovers after retry', (tester) async {
    final sampleResult = IdResult(
      id: 'test-1',
      specimenImage: 'assets/images/fossil_ammonite.png',
      confidenceLabel: 'HIGH CONFIDENCE',
      matchLabel: 'Best match',
      tip: 'Tip',
      taxonomy: const [],
      candidates: const [
        IdCandidate(
          genus: 'Dactylioceras',
          commonGroup: 'Ammonite',
          family: 'Dactylioceratidae',
          confidence: 92,
          thumbnail: 'assets/images/fossil_ammonite.png',
          isBestMatch: true,
        ),
      ],
      facts: const [],
    );
    final repo = _FakeIdentifyRepository(
      result: sampleResult,
      failuresBeforeSuccess: 1,
    );

    await tester.pumpWidget(
      wrap(
        IdResultScreen(
          captured: CapturedSpecimen(bytes: Uint8List.fromList([9, 9, 9])),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not identify this specimen.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Dactylioceras'), findsOneWidget);
    expect(repo.identifyCalls, 2);
  });

  testWidgets('rock assessment shows lithology and hides profile CTA', (
    tester,
  ) async {
    final rock = IdResult(
      id: 'rock-conglomerate',
      specimenImage: 'assets/images/fossil_trilobite.png',
      confidenceLabel: 'HIGH CONFIDENCE',
      matchLabel: 'May not be a fossil — check details',
      tip: 'Rounded pebbles; no biogenic structure.',
      taxonomy: const [],
      candidates: const [],
      facts: const [
        TaxonFact(
          icon: 'public',
          value: 'Conglomerate',
          label: 'Likely material',
        ),
      ],
      assessment: IdentifyAssessment.mayNotBeFossil,
      rockType: 'conglomerate',
      primaryConfidence: 88,
    );
    final repo = _FakeIdentifyRepository(result: rock);

    await tester.pumpWidget(
      wrap(
        IdResultScreen(
          captured: CapturedSpecimen(bytes: Uint8List.fromList([2, 2, 2])),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('May not be a fossil'), findsOneWidget);
    expect(find.text('Conglomerate'), findsWidgets);
    expect(find.text('View full profile'), findsNothing);
    expect(find.textContaining('Try another'), findsOneWidget);
    expect(
      find.textContaining('Lithology / material estimate'),
      findsOneWidget,
    );
    // High rock confidence still shows refine panel — rocks look alike.
    expect(find.text('Rock IDs need a second look'), findsOneWidget);
    expect(find.text('Re-identify with my notes'), findsOneWidget);
  });

  testWidgets('uncertain shows photo warning and highest provisional genus', (
    tester,
  ) async {
    final uncertain = IdResult(
      id: 'uncertain-dact',
      specimenImage: 'assets/images/fossil_ammonite.png',
      confidenceLabel: 'LOW CONFIDENCE',
      matchLabel: 'Uncertain — provisional best guess',
      tip: 'Blurry; need scale and sharper focus.',
      reason: 'Blurry; need scale and sharper focus.',
      taxonomy: const [],
      candidates: const [
        IdCandidate(
          genus: 'Dactylioceras',
          commonGroup: 'Ammonite',
          family: 'Dactylioceratidae',
          confidence: 38,
          modelConfidence: 38,
          thumbnail: 'assets/images/fossil_ammonite.png',
          isBestMatch: true,
        ),
        IdCandidate(
          genus: 'Harpoceras',
          commonGroup: 'Ammonite',
          family: 'Hildoceratidae',
          confidence: 22,
          thumbnail: 'assets/images/fossil_ammonite.png',
          isBestMatch: false,
        ),
      ],
      facts: const [],
      assessment: IdentifyAssessment.uncertain,
    );
    final repo = _FakeIdentifyRepository(result: uncertain);

    expect(uncertain.isUncertain, isTrue);
    expect(uncertain.candidates, hasLength(2));
    expect(uncertain.alternatives, hasLength(1));
    expect(uncertain.alternatives.first.genus, 'Harpoceras');

    await tester.pumpWidget(
      wrap(
        IdResultScreen(
          captured: CapturedSpecimen(bytes: Uint8List.fromList([3, 3, 3])),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clearer photo needed'), findsOneWidget);
    expect(find.textContaining('What can go wrong'), findsOneWidget);
    expect(find.text('Dactylioceras'), findsOneWidget);
    expect(find.text('38%'), findsOneWidget);
    expect(find.text('Other provisional possibilities'), findsOneWidget);
    expect(find.text('Harpoceras'), findsOneWidget);
    expect(find.text('View provisional profile'), findsOneWidget);
  });

  testWidgets('low confidence shows refine panel and re-identifies with notes', (
    tester,
  ) async {
    final low = IdResult(
      id: 'low-1',
      specimenImage: 'assets/images/fossil_ammonite.png',
      confidenceLabel: 'LOW CONFIDENCE',
      matchLabel: 'Potential match — needs more information',
      tip: 'Provisional',
      taxonomy: const [],
      candidates: const [
        IdCandidate(
          genus: 'Carcharodon',
          commonGroup: 'Shark',
          family: 'Lamnidae',
          confidence: 35,
          modelConfidence: 35,
          thumbnail: 'assets/images/fossil_ammonite.png',
          isBestMatch: true,
        ),
      ],
      facts: const [],
      assessment: IdentifyAssessment.fossil,
      primaryConfidence: 35,
    );
    final repo = _FakeIdentifyRepository(result: low);

    await tester.pumpWidget(
      wrap(
        IdResultScreen(
          captured: CapturedSpecimen(bytes: Uint8List.fromList([4, 4, 4])),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Potential match'), findsWidgets);
    expect(find.textContaining('Grain'), findsWidgets);
    expect(find.text('Re-identify with my notes'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'The rock looks coarse-grained with rounded pebbles.',
    );
    await tester.ensureVisible(find.text('Re-identify with my notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-identify with my notes'));
    await tester.pumpAndSettle();

    expect(repo.identifyCalls, 2);
    expect(
      repo.lastNotes,
      'The rock looks coarse-grained with rounded pebbles.',
    );
  });
}

class _FakeIdentifyRepository implements IdentifyRepository {
  _FakeIdentifyRepository({
    required this.result,
    this.failuresBeforeSuccess = 0,
  });

  final IdResult result;
  final int failuresBeforeSuccess;
  int identifyCalls = 0;
  int mockCalls = 0;
  String? lastNotes;

  @override
  Future<IdResult> getMockResult(String imageId) async {
    mockCalls += 1;
    if (mockCalls <= failuresBeforeSuccess) {
      throw Exception('Network unavailable');
    }
    return result;
  }

  @override
  Future<IdResult> identify(Uint8List bytes, {String? userNotes}) async {
    identifyCalls += 1;
    lastNotes = userNotes;
    if (identifyCalls <= failuresBeforeSuccess) {
      throw Exception('Network unavailable');
    }
    return result;
  }
}
