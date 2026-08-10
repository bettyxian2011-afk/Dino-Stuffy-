import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/id_result.dart';

abstract class IdentifyRepository {
  Future<IdResult> getMockResult(String imageId);
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
}
