import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/id_result.dart';

/// Curated genera and UI metadata loaded from [assets/data/id_results.json].
class IdCatalogEntry {
  const IdCatalogEntry({
    required this.genus,
    required this.commonGroup,
    required this.family,
    required this.thumbnail,
    required this.tip,
    required this.taxonomy,
    required this.facts,
    required this.specimenImage,
  });

  final String genus;
  final String commonGroup;
  final String family;
  final String thumbnail;
  final String tip;
  final List<String> taxonomy;
  final List<TaxonFact> facts;
  final String specimenImage;
}

class IdCatalog {
  IdCatalog(this._byGenus);

  final Map<String, IdCatalogEntry> _byGenus;

  List<String> get genusNames =>
      _byGenus.keys.toList()..sort((a, b) => a.compareTo(b));

  IdCatalogEntry? entryFor(String genus) => _byGenus[genus];

  static Future<IdCatalog> load({AssetBundle? bundle}) async {
    final data = bundle ?? rootBundle;
    final raw = await data.loadString('assets/data/id_results.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final byGenus = <String, IdCatalogEntry>{};

    for (final entry in json.values) {
      final map = entry as Map<String, dynamic>;
      final specimenImage = map['specimenImage'] as String;
      final tip = map['tip'] as String;
      final taxonomy =
          (map['taxonomy'] as List<dynamic>).cast<String>();
      final facts = (map['facts'] as List<dynamic>)
          .map((e) => TaxonFact.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final candidate in map['candidates'] as List<dynamic>) {
        final c = candidate as Map<String, dynamic>;
        final genus = c['genus'] as String;
        byGenus.putIfAbsent(
          genus,
          () => IdCatalogEntry(
            genus: genus,
            commonGroup: c['commonGroup'] as String,
            family: c['family'] as String,
            thumbnail: c['thumbnail'] as String,
            tip: tip,
            taxonomy: taxonomy,
            facts: facts,
            specimenImage: specimenImage,
          ),
        );
      }
    }

    return IdCatalog(byGenus);
  }
}
