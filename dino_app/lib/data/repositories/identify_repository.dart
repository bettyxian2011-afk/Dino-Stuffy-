import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/id_result.dart';

abstract class IdentifyRepository {
  Future<IdResult> getMockResult(String imageId);

  /// Identify from image bytes.
  ///
  /// [userNotes] are optional field observations from the user (e.g. grain
  /// size, scale, texture) used to refine a low-confidence result.
  Future<IdResult> identify(Uint8List bytes, {String? userNotes});
}

class MockIdentifyRepository implements IdentifyRepository {
  MockIdentifyRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    final raw = await _bundle.loadString('assets/data/id_results.json');
    _cache = jsonDecode(raw) as Map<String, dynamic>;
    return _cache!;
  }

  @override
  Future<IdResult> getMockResult(String imageId) async {
    final data = await _load();
    final entry = data[imageId] as Map<String, dynamic>?;
    if (entry == null) {
      final fallback = data.values.first as Map<String, dynamic>;
      return IdResult.fromJson(fallback);
    }
    return IdResult.fromJson(entry);
  }

  @override
  Future<IdResult> identify(Uint8List bytes, {String? userNotes}) async {
    // Simulate inference latency; real API replaces this in Iteration 7.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final data = await _load();
    final keys = data.keys.toList()..sort();
    if (keys.isEmpty) {
      throw StateError('No mock identification results configured.');
    }
    final index = bytes.fold<int>(0, (sum, byte) => sum + byte) % keys.length;
    final result = await getMockResult(keys[index]);
    final notes = userNotes?.trim();
    if (notes == null || notes.isEmpty) return result;
    return IdResult(
      id: result.id,
      specimenImage: result.specimenImage,
      confidenceLabel: result.confidenceLabel,
      matchLabel: result.matchLabel,
      tip: '${result.tip}\n\nYour notes were included: $notes',
      taxonomy: result.taxonomy,
      candidates: result.candidates,
      facts: result.facts,
      timelineLabel: result.timelineLabel,
      pbdbVerified: result.pbdbVerified,
      source: result.source,
      assessment: result.assessment,
      rockType: result.rockType,
      reason: result.reason,
      primaryConfidence: result.primaryConfidence,
    );
  }
}
