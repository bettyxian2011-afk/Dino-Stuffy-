import 'dart:typed_data';

import 'package:dino_app/data/repositories/identify_repository.dart';
import 'package:dino_app/models/captured_specimen.dart';
import 'package:dino_app/models/id_result.dart';
import 'package:dino_app/screens/id_result/id_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('shows genus from a successful identify call', (tester) async {
    final repo = _FakeIdentifyRepository(result: sampleResult);
    await tester.pumpWidget(
      wrap(
        IdResultScreen(
          captured: CapturedSpecimen(
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
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
    final repo = _FakeIdentifyRepository(
      result: sampleResult,
      failuresBeforeSuccess: 1,
    );

    await tester.pumpWidget(
      wrap(
        IdResultScreen(
          captured: CapturedSpecimen(
            bytes: Uint8List.fromList([9, 9, 9]),
          ),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not identify this specimen.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Dactylioceras'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Dactylioceras'), findsOneWidget);
    expect(repo.identifyCalls, 2);
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

  @override
  Future<IdResult> getMockResult(String imageId) async {
    mockCalls += 1;
    if (mockCalls <= failuresBeforeSuccess) {
      throw Exception('Network unavailable');
    }
    return result;
  }

  @override
  Future<IdResult> identify(Uint8List bytes) async {
    identifyCalls += 1;
    if (identifyCalls <= failuresBeforeSuccess) {
      throw Exception('Network unavailable');
    }
    return result;
  }
}
