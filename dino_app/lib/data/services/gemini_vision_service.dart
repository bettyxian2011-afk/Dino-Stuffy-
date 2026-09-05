import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../config/strata_config.dart';

class GeminiVisionCandidate {
  const GeminiVisionCandidate({
    required this.genus,
    required this.confidence,
  });

  final String genus;
  final int confidence;
}

class GeminiVisionService {
  GeminiVisionService({
    required String apiKey,
    String? modelName,
    GenerativeModel? model,
  }) : _model = model ??
            GenerativeModel(
              model: modelName ?? StrataConfig.geminiModel,
              apiKey: apiKey,
              generationConfig: GenerationConfig(
                temperature: 0.15,
                maxOutputTokens: 180,
                responseMimeType: 'application/json',
              ),
            );

  final GenerativeModel _model;

  Future<List<GeminiVisionCandidate>> identifyGenera({
    required Uint8List jpegBytes,
    required List<String> catalogGenera,
  }) async {
    if (catalogGenera.isEmpty) {
      throw StateError('Catalog genera list must not be empty.');
    }

    final genusList = catalogGenera.join(', ');
    final prompt = '''
Pick up to 3 fossil genera for this photo.
Prefer names from this app catalog when plausible: $genusList.
If none fit, you may suggest other published fossil genera.

Return JSON only:
{"candidates":[{"genus":"Name","confidence":0-100}]}
Sort by confidence descending. Use integer confidence only.
''';

    final response = await _model.generateContent([
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', jpegBytes),
      ]),
    ]);

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw GeminiVisionException('Empty response from Gemini.');
    }

    return _parseCandidates(text);
  }

  List<GeminiVisionCandidate> _parseCandidates(String raw) {
    final jsonText = _extractJson(raw);
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final list = decoded['candidates'] as List<dynamic>? ?? [];

    return list
        .map((item) {
          final map = item as Map<String, dynamic>;
          return GeminiVisionCandidate(
            genus: (map['genus'] as String).trim(),
            confidence: (map['confidence'] as num).round().clamp(0, 100),
          );
        })
        .where((c) => c.genus.isNotEmpty)
        .toList();
  }

  String _extractJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{')) return trimmed;

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    throw GeminiVisionException('Could not parse Gemini JSON: $raw');
  }
}

class GeminiVisionException implements Exception {
  GeminiVisionException(this.message);
  final String message;

  @override
  String toString() => message;
}
