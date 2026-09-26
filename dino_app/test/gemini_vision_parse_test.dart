import 'package:dino_app/data/services/gemini_vision_service.dart';
import 'package:dino_app/models/id_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeminiVisionService.parseResult', () {
    test('parses fossil candidates (legacy shape still works)', () {
      const raw =
          '{"candidates":[{"genus":"Dactylioceras","confidence":92},'
          '{"genus":"Harpoceras","confidence":61}]}';
      final result = GeminiVisionService.parseResult(raw);
      expect(result.assessment, IdentifyAssessment.fossil);
      expect(result.candidates, hasLength(2));
      expect(result.candidates.first.genus, 'Dactylioceras');
    });

    test('parses may_not_be_fossil with fixed rockType', () {
      const raw =
          '{"assessment":"may_not_be_fossil","rockType":"conglomerate",'
          '"confidence":78,"reason":"Rounded pebbles; no biogenic structure.",'
          '"candidates":[{"genus":"Carcharodon","confidence":40}]}';
      final result = GeminiVisionService.parseResult(raw);
      expect(result.assessment, IdentifyAssessment.mayNotBeFossil);
      expect(result.rockType, 'conglomerate');
      expect(result.candidates, isEmpty); // rock path drops genera
      expect(result.reason, contains('Rounded pebbles'));
    });

    test('parses uncertain with provisional candidates', () {
      const raw =
          '{"assessment":"uncertain","confidence":40,'
          '"reason":"Blurry; need scale.",'
          '"candidates":[{"genus":"Dactylioceras","confidence":38},'
          '{"genus":"Harpoceras","confidence":22}]}';
      final result = GeminiVisionService.parseResult(raw);
      expect(result.assessment, IdentifyAssessment.uncertain);
      expect(result.candidates, hasLength(2));
      expect(result.candidates.first.genus, 'Dactylioceras');
      expect(result.candidates.first.confidence, 38);
    });

    test('normalizes unknown rock labels to other_rock', () {
      const raw =
          '{"assessment":"may_not_be_fossil","rockType":"weird amphibolite"}';
      final result = GeminiVisionService.parseResult(raw);
      expect(result.rockType, 'other_rock');
    });

    test('strips markdown fences', () {
      const raw = '''
```json
{"assessment":"fossil","candidates":[{"genus":"Velociraptor","confidence":88}]}
```
''';
      final result = GeminiVisionService.parseResult(raw);
      expect(result.candidates.single.genus, 'Velociraptor');
    });

    test('parseCandidates remains compatible', () {
      const raw =
          '{"candidates":[{"genus":"Dactylioceras","confidence":92},'
          '{"genus":"Harpo';
      final result = GeminiVisionService.parseCandidates(raw);
      expect(result, isNotEmpty);
      expect(result.first.genus, 'Dactylioceras');
    });
  });
}
