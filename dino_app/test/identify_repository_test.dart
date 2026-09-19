import 'dart:typed_data';

import 'package:dino_app/data/catalog/id_catalog.dart';
import 'package:dino_app/data/repositories/gemini_identify_repository.dart';
import 'package:dino_app/data/repositories/identify_repository.dart';
import 'package:dino_app/data/strata_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockIdentifyRepository', () {
    test('identify returns a valid IdResult from catalog', () async {
      final repo = MockIdentifyRepository();
      final result = await repo.identify(Uint8List.fromList([1, 2, 3, 4]));

      expect(result.candidates, isNotEmpty);
      expect(result.bestMatch.genus, isNotEmpty);
      expect(result.bestMatch.confidence, inInclusiveRange(0, 100));
      expect(result.specimenImage, isNotEmpty);
    });

    test('identify is deterministic for the same bytes', () async {
      final repo = MockIdentifyRepository();
      final bytes = Uint8List.fromList([9, 8, 7]);
      final a = await repo.identify(bytes);
      final b = await repo.identify(bytes);
      expect(a.id, b.id);
      expect(a.bestMatch.genus, b.bestMatch.genus);
    });
  });

  group('StrataServices.buildIdentifyRepository', () {
    late IdCatalog catalog;

    setUpAll(() async {
      catalog = await IdCatalog.load();
    });

    test('uses MockIdentifyRepository when Gemini key is missing', () {
      final repo = StrataServices.buildIdentifyRepository(
        catalog: catalog,
        hasGeminiApiKey: false,
        geminiApiKey: '',
      );
      expect(repo, isA<MockIdentifyRepository>());
    });

    test('uses GeminiIdentifyRepository when Gemini key is present', () {
      final repo = StrataServices.buildIdentifyRepository(
        catalog: catalog,
        hasGeminiApiKey: true,
        geminiApiKey: 'test-key-not-for-network',
      );
      expect(repo, isA<GeminiIdentifyRepository>());
    });
  });
}
