import 'package:dino_app/data/services/gemini_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeminiVisionService.parseCandidates', () {
    test('parses clean JSON', () {
      const raw =
          '{"candidates":[{"genus":"Dactylioceras","confidence":92},'
          '{"genus":"Harpoceras","confidence":61}]}';
      final result = GeminiVisionService.parseCandidates(raw);
      expect(result, hasLength(2));
      expect(result.first.genus, 'Dactylioceras');
      expect(result.first.confidence, 92);
    });

    test('strips markdown fences', () {
      const raw = '''
```json
{"candidates":[{"genus":"Velociraptor","confidence":88}]}
```
''';
      final result = GeminiVisionService.parseCandidates(raw);
      expect(result.single.genus, 'Velociraptor');
    });

    test('repairs truncated JSON after a complete candidate', () {
      // Simulates mid-string cut after first object started second genus.
      const raw =
          '{"candidates":[{"genus":"Dactylioceras","confidence":92},'
          '{"genus":"Harpo';
      final result = GeminiVisionService.parseCandidates(raw);
      expect(result, isNotEmpty);
      expect(result.first.genus, 'Dactylioceras');
    });
  });
}
