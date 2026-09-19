import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:googleai_dart/googleai_dart.dart';

import '../../config/strata_config.dart';

class GeminiVisionCandidate {
  const GeminiVisionCandidate({
    required this.genus,
    required this.confidence,
  });

  final String genus;
  final int confidence;
}

/// Fossil vision via the maintained [googleai_dart] client.
class GeminiVisionService {
  GeminiVisionService({
    required String apiKey,
    String? modelName,
    GoogleAIClient? client,
  })  : _modelName = modelName ?? StrataConfig.geminiModel,
        _client = client ??
            GoogleAIClient(
              config: GoogleAIConfig.googleAI(
                authProvider: ApiKeyProvider(apiKey),
                timeout: const Duration(seconds: 90),
                retryPolicy: RetryPolicy.defaultPolicy,
              ),
            ),
        _ownsClient = client == null;

  final String _modelName;
  final GoogleAIClient _client;
  final bool _ownsClient;

  static const _responseSchema = <String, dynamic>{
    'type': 'object',
    'properties': {
      'candidates': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'genus': {'type': 'string'},
            'confidence': {'type': 'integer'},
          },
          'required': ['genus', 'confidence'],
        },
      },
    },
    'required': ['candidates'],
  };

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

Respond with JSON only (no markdown). Example shape:
{"candidates":[{"genus":"Dactylioceras","confidence":92}]}
Sort by confidence descending. Confidence must be an integer 0-100.
Keep genus names short ASCII Latin binomials (genus only).
''';

    try {
      final response = await _client.models.generateContent(
        model: _modelName,
        request: GenerateContentRequest(
          contents: [
            Content.user([
              Part.text(prompt),
              Part.bytes(jpegBytes, 'image/jpeg'),
            ]),
          ],
          generationConfig: GenerationConfig(
            // Gemini 3.x defaults to medium thinking; that can consume the
            // whole output budget and truncate JSON mid-string.
            thinkingConfig: const ThinkingConfig(
              thinkingLevel: ThinkingLevel.minimal,
            ),
            maxOutputTokens: 2048,
            responseMimeType: 'application/json',
            responseSchema: _responseSchema,
          ),
        ),
      );

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw GeminiVisionException('Empty response from Gemini.');
      }

      debugPrint('GeminiVision raw text (${text.length} chars): $text');
      return parseCandidates(text);
    } on ApiException catch (error) {
      throw GeminiVisionException(
        'Gemini API error ${error.statusCode}: ${error.message}',
      );
    } on GoogleAIException catch (error) {
      throw GeminiVisionException(error.toString());
    }
  }

  /// Exposed for unit tests.
  @visibleForTesting
  static List<GeminiVisionCandidate> parseCandidates(String raw) {
    final jsonText = _extractJson(raw);
    try {
      return _decodeCandidates(jsonText);
    } on FormatException catch (error) {
      final repaired = _repairTruncatedJson(jsonText);
      if (repaired != null) {
        try {
          return _decodeCandidates(repaired);
        } on FormatException {
          // Fall through to friendlier error.
        }
      }
      throw GeminiVisionException(
        'Bad JSON from Gemini (${error.message}). '
        'Raw: ${_preview(jsonText)}',
      );
    }
  }

  static List<GeminiVisionCandidate> _decodeCandidates(String jsonText) {
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final list = decoded['candidates'] as List<dynamic>? ?? [];

    return list
        .map((item) {
          final map = item as Map<String, dynamic>;
          final genus = (map['genus'] as String? ?? '').trim();
          final confidenceRaw = map['confidence'];
          final confidence = confidenceRaw is num
              ? confidenceRaw.round().clamp(0, 100)
              : int.tryParse('$confidenceRaw')?.clamp(0, 100) ?? 0;
          return GeminiVisionCandidate(genus: genus, confidence: confidence);
        })
        .where((c) => c.genus.isNotEmpty)
        .toList();
  }

  static String _extractJson(String raw) {
    var trimmed = raw.trim();
    if (trimmed.startsWith('```')) {
      trimmed = trimmed
          .replaceFirst(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    if (trimmed.startsWith('{')) return trimmed;

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    // Truncated: no closing brace — still return from first `{`.
    if (start >= 0) {
      return trimmed.substring(start);
    }
    throw GeminiVisionException('Could not find JSON object in: ${_preview(raw)}');
  }

  /// Best-effort close of truncated `{"candidates":[...` payloads.
  static String? _repairTruncatedJson(String raw) {
    if (!raw.contains('"candidates"')) return null;

    var s = raw.trim();
    // Drop a trailing incomplete key/value fragment after the last complete object.
    final lastCompleteObject = s.lastIndexOf('}');
    if (lastCompleteObject > 0) {
      s = s.substring(0, lastCompleteObject + 1);
    } else {
      // Cut an unterminated string at the last quote if possible.
      final lastQuote = s.lastIndexOf('"');
      if (lastQuote > 0) {
        s = '${s.substring(0, lastQuote)}"';
      }
    }

    // Balance braces/brackets.
    var openBrace = '{'.allMatches(s).length - '}'.allMatches(s).length;
    var openBracket = '['.allMatches(s).length - ']'.allMatches(s).length;
    // If we ended mid-object after a property, close the object first.
    if (s.endsWith(':') || RegExp(r',[^\}\]]*$').hasMatch(s)) {
      s = s.replaceFirst(RegExp(r',\s*$'), '');
    }
    while (openBrace > 0 || openBracket > 0) {
      if (openBracket > 0) {
        s += ']';
        openBracket--;
      } else if (openBrace > 0) {
        s += '}';
        openBrace--;
      }
    }
    return s;
  }

  static String _preview(String text) {
    final oneLine = text.replaceAll('\n', r'\n');
    if (oneLine.length <= 120) return oneLine;
    return '${oneLine.substring(0, 120)}…';
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class GeminiVisionException implements Exception {
  GeminiVisionException(this.message);
  final String message;

  @override
  String toString() => message;
}
