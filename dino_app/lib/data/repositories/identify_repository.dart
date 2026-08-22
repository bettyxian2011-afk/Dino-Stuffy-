import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/id_result.dart';

abstract class IdentifyRepository {
  Future<IdResult> getMockResult(String imageId);

  /// Mock identification from image bytes (returns canned results for now).
  Future<IdResult> identify(Uint8List bytes);
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
  Future<IdResult> identify(Uint8List bytes) async {
    // Simulate inference latency; real API replaces this in Iteration 7.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final data = await _load();
    final keys = data.keys.toList()..sort();
    if (keys.isEmpty) {
      throw StateError('No mock identification results configured.');
    }
    final index = bytes.fold<int>(0, (sum, byte) => sum + byte) % keys.length;
    return getMockResult(keys[index]);
  }
}
