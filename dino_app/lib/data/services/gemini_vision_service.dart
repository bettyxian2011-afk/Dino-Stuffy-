import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:googleai_dart/googleai_dart.dart';

import '../../config/strata_config.dart';
import '../../models/id_result.dart';
import 'rock_lithology.dart';

class GeminiVisionCandidate {
  const GeminiVisionCandidate({
    required this.genus,
    required this.confidence,
  });

  final String genus;
  final int confidence;
}

/// Full vision response: fossil candidates and/or non-fossil rock assessment.
class GeminiVisionResult {
  const GeminiVisionResult({
    required this.assessment,
    this.candidates = const [],
    this.rockType,
    this.reason,
    this.confidence,
  });

  final IdentifyAssessment assessment;
  final List<GeminiVisionCandidate> candidates;
  final String? rockType;
  final String? reason;
  final int? confidence;
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
      'assessment': {
        'type': 'string',
        'enum': ['fossil', 'may_not_be_fossil', 'uncertain'],
      },
      'rockType': {
        'type': 'string',
        'enum': RockLithology.labels,
      },
      'reason': {'type': 'string'},
      'confidence': {'type': 'integer'},
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
    'required': ['assessment'],
  };

  Future<GeminiVisionResult> identifyPhoto({
    required Uint8List jpegBytes,
    required List<String> catalogGenera,
    String? userNotes,
  }) async {
    if (catalogGenera.isEmpty) {
      throw StateError('Catalog genera list must not be empty.');
    }

    final genusList = catalogGenera.join(', ');
    final rockList = RockLithology.labels.join(', ');
    final notes = userNotes?.trim();
    final notesBlock = (notes == null || notes.isEmpty)
        ? ''
        : '''

User field notes (treat as helpful context from the photographer — not proven facts):
"""
$notes
"""
Weigh these notes together with the image. If notes conflict with the photo, prefer clear visual evidence but lower confidence.
''';

    final prompt = '''
Assess this photo for fossil identification.
$notesBlock
Set assessment to one of:
- "fossil" — clear or plausible biogenic fossil; then fill candidates
- "may_not_be_fossil" — abiotic rock / sediment / conglomerate / non-fossil object; do NOT invent fossil genera
- "uncertain" — cannot tell confidently; still suggest up to 3 provisional genera if any are plausible, but keep confidences modest

For "may_not_be_fossil": set rockType to EXACTLY one of: $rockList
(use other_rock if none fit). Add a brief reason. Leave candidates empty.

For "fossil": pick up to 3 fossil genera. Prefer names from this app catalog when
plausible: $genusList.
If none fit, you may suggest other published fossil genera.
Sort candidates by confidence descending. Confidence must be an integer 0-100.
Keep genus names short ASCII Latin (genus only).

For "uncertain": fill reason with what is wrong with the photo (blur, lighting,
no scale, ambiguous texture). Also fill candidates with up to 3 provisional
genera sorted by confidence — these are guesses, not authoritative IDs.

Respond with JSON only (no markdown). Examples:
{"assessment":"fossil","candidates":[{"genus":"Dactylioceras","confidence":92}]}
{"assessment":"may_not_be_fossil","rockType":"conglomerate","confidence":78,"reason":"Rounded pebbles in matrix; no biogenic structure."}
{"assessment":"uncertain","confidence":40,"reason":"Blurry; need scale and sharper focus.","candidates":[{"genus":"Dactylioceras","confidence":38}]}
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
      return parseResult(text);
    } on ApiException catch (error) {
      throw GeminiVisionException(
        'Gemini API error ${error.statusCode}: ${error.message}',
      );
    } on GoogleAIException catch (error) {
      throw GeminiVisionException(error.toString());
    }
  }

  /// Backward-compatible: fossil candidates only.
  @Deprecated('Use identifyPhoto / parseResult')
  Future<List<GeminiVisionCandidate>> identifyGenera({
    required Uint8List jpegBytes,
    required List<String> catalogGenera,
  }) async {
    final result = await identifyPhoto(
      jpegBytes: jpegBytes,
      catalogGenera: catalogGenera,
    );
    return result.candidates;
  }

  /// Exposed for unit tests.
  @visibleForTesting
  static GeminiVisionResult parseResult(String raw) {
    final jsonText = _extractJson(raw);
    try {
      return _decodeResult(jsonText);
    } on FormatException catch (error) {
      final repaired = _repairTruncatedJson(jsonText);
      if (repaired != null) {
        try {
          return _decodeResult(repaired);
        } on FormatException {
          // Fall through.
        }
      }
      throw GeminiVisionException(
        'Bad JSON from Gemini (${error.message}). '
        'Raw: ${_preview(jsonText)}',
      );
    }
  }

  /// Exposed for unit tests (legacy fossil-only payloads).
  @visibleForTesting
  static List<GeminiVisionCandidate> parseCandidates(String raw) {
    return parseResult(raw).candidates;
  }

  static GeminiVisionResult _decodeResult(String jsonText) {
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final assessment = IdentifyAssessment.fromWire(
      decoded['assessment'] as String?,
    );

    // Legacy payloads without assessment but with candidates → fossil.
    final list = decoded['candidates'] as List<dynamic>? ?? [];
    final candidates = list
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

    final inferred = decoded['assessment'] == null && candidates.isNotEmpty
        ? IdentifyAssessment.fossil
        : assessment;

    final confidenceRaw = decoded['confidence'];
    final confidence = confidenceRaw is num
        ? confidenceRaw.round().clamp(0, 100)
        : int.tryParse('$confidenceRaw')?.clamp(0, 100);

    final rockTypeRaw = (decoded['rockType'] as String?)?.trim();
    final reason = (decoded['reason'] as String?)?.trim();

    // Keep candidates for fossil + uncertain; drop for rock-only assessments.
    final keepCandidates = inferred == IdentifyAssessment.fossil ||
        inferred == IdentifyAssessment.uncertain;

    return GeminiVisionResult(
      assessment: inferred,
      candidates: keepCandidates ? candidates : const [],
      rockType: inferred == IdentifyAssessment.mayNotBeFossil
          ? RockLithology.normalize(rockTypeRaw)
          : null,
      reason: reason?.isEmpty == true ? null : reason,
      confidence: confidence,
    );
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
    if (start >= 0) {
      return trimmed.substring(start);
    }
    throw GeminiVisionException('Could not find JSON object in: ${_preview(raw)}');
  }

  /// Best-effort close of truncated `{"candidates":[...` payloads.
  static String? _repairTruncatedJson(String raw) {
    if (!raw.contains('"candidates"') && !raw.contains('"assessment"')) {
      return null;
    }

    var s = raw.trim();
    final lastCompleteObject = s.lastIndexOf('}');
    if (lastCompleteObject > 0) {
      s = s.substring(0, lastCompleteObject + 1);
    } else {
      final lastQuote = s.lastIndexOf('"');
      if (lastQuote > 0) {
        s = '${s.substring(0, lastQuote)}"';
      }
    }

    var openBrace = '{'.allMatches(s).length - '}'.allMatches(s).length;
    var openBracket = '['.allMatches(s).length - ']'.allMatches(s).length;
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
