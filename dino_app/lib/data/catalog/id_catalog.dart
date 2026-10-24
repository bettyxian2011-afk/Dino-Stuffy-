import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/fossil_taxon.dart';
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
    this.factsFromCloud = false,
  });

  final String genus;
  final String commonGroup;
  final String family;
  final String thumbnail;
  final String tip;
  final List<String> taxonomy;
  final List<TaxonFact> facts;
  final String specimenImage;

  /// True when [facts] were copied from a Firestore taxon in this session.
  /// Local JSON facts stay false so offline Identify keeps its PBDB fact order.
  final bool factsFromCloud;

  IdCatalogEntry copyWith({
    String? commonGroup,
    String? family,
    String? thumbnail,
    String? tip,
    List<String>? taxonomy,
    List<TaxonFact>? facts,
    String? specimenImage,
    bool? factsFromCloud,
  }) {
    return IdCatalogEntry(
      genus: genus,
      commonGroup: commonGroup ?? this.commonGroup,
      family: family ?? this.family,
      thumbnail: thumbnail ?? this.thumbnail,
      tip: tip ?? this.tip,
      taxonomy: taxonomy ?? this.taxonomy,
      facts: facts ?? this.facts,
      specimenImage: specimenImage ?? this.specimenImage,
      factsFromCloud: factsFromCloud ?? this.factsFromCloud,
    );
  }
}

class IdCatalog {
  IdCatalog(this._byGenus);

  final Map<String, IdCatalogEntry> _byGenus;

  List<String> get genusNames =>
      _byGenus.keys.toList()..sort((a, b) => a.compareTo(b));

  IdCatalogEntry? entryFor(String genus) {
    final key = _keyForGenus(genus);
    return key == null ? null : _byGenus[key];
  }

  /// Overlays Identify taxa from Firestore. Cloud [facts], [taxonomy],
  /// [family], and [commonGroup] win when present; local JSON fills thumbnails
  /// and tips when the cloud copy omits them.
  IdCatalog mergedWith(Iterable<FossilTaxon> cloudTaxa) {
    final byGenus = Map<String, IdCatalogEntry>.from(_byGenus);
    for (final taxon in cloudTaxa) {
      if (!taxon.useInIdentify) continue;
      final existingKey = _keyForGenus(taxon.scientificName);
      if (existingKey == null) {
        byGenus[taxon.scientificName] = _entryFromTaxon(taxon);
        continue;
      }
      final existing = byGenus[existingKey];
      if (existing == null) {
        byGenus[taxon.scientificName] = _entryFromTaxon(taxon);
        continue;
      }
      final cloudFacts = taxon.facts.isNotEmpty;
      byGenus[existingKey] = existing.copyWith(
        commonGroup: taxon.commonGroup.isNotEmpty
            ? taxon.commonGroup
            : existing.commonGroup,
        family: taxon.family.isNotEmpty ? taxon.family : existing.family,
        taxonomy: taxon.taxonomy.isNotEmpty
            ? taxon.taxonomy
            : existing.taxonomy,
        facts: cloudFacts ? taxon.facts : existing.facts,
        factsFromCloud: cloudFacts,
        tip: taxon.tip.isNotEmpty ? taxon.tip : existing.tip,
      );
    }
    return IdCatalog(byGenus);
  }

  String? _keyForGenus(String genus) {
    if (_byGenus.containsKey(genus)) return genus;
    final lower = genus.toLowerCase();
    for (final key in _byGenus.keys) {
      if (key.toLowerCase() == lower) return key;
    }
    return null;
  }

  static IdCatalogEntry _entryFromTaxon(FossilTaxon taxon) {
    return IdCatalogEntry(
      genus: taxon.scientificName,
      commonGroup: taxon.commonGroup,
      family: taxon.family,
      thumbnail: taxon.imageAsset,
      tip: taxon.tip,
      taxonomy: taxon.taxonomy,
      facts: taxon.facts,
      specimenImage: taxon.imageAsset,
      factsFromCloud: taxon.facts.isNotEmpty,
    );
  }

  static Future<IdCatalog> load({AssetBundle? bundle}) async {
    final data = bundle ?? rootBundle;
    final raw = await data.loadString('assets/data/id_results.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final byGenus = <String, IdCatalogEntry>{};

    for (final entry in json.values) {
      final map = entry as Map<String, dynamic>;
      final specimenImage = map['specimenImage'] as String;
      final tip = map['tip'] as String;
      final taxonomy = (map['taxonomy'] as List<dynamic>).cast<String>();
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
