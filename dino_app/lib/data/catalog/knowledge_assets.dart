import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/fossil_taxon.dart';
import '../../models/geologic_period.dart';

/// Bundled copies of the Firestore `periods` and `taxa` collections, built by
/// `seed/build.mjs`. Used when Firestore is unavailable.
class KnowledgeAssets {
  KnowledgeAssets._();

  static const periodsPath = 'assets/data/periods.json';
  static const taxaPath = 'assets/data/taxa.json';

  /// Periods sorted oldest first.
  static Future<List<GeologicPeriod>> loadPeriods({AssetBundle? bundle}) async {
    final json = await _loadMap(bundle ?? rootBundle, periodsPath);
    return json.entries
        .map((e) => GeologicPeriod.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Taxa keyed by id (lowercase genus).
  static Future<Map<String, FossilTaxon>> loadTaxa({AssetBundle? bundle}) async {
    final json = await _loadMap(bundle ?? rootBundle, taxaPath);
    return json.map(
      (id, value) =>
          MapEntry(id, FossilTaxon.fromJson(id, value as Map<String, dynamic>)),
    );
  }

  static Future<Map<String, dynamic>> _loadMap(
    AssetBundle bundle,
    String path,
  ) async =>
      jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>;
}
