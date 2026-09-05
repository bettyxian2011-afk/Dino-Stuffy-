import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/pbdb_taxon.dart';

abstract class TaxonRepository {
  Future<PbdbTaxon?> findTaxon(String name);
  Future<List<PbdbTaxon>> getTimelineChain(String name);
}

class PbdbTaxonRepository implements TaxonRepository {
  PbdbTaxonRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://paleobiodb.org/data1.2';

  @override
  Future<PbdbTaxon?> findTaxon(String name) async {
    final uri = Uri.parse(
      '$_base/taxa/single.json?name=${Uri.encodeComponent(name)}&show=app,attr',
    );
    final response = await _client.get(uri);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw TaxonFetchException(response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final records = body['records'] as List<dynamic>;
    if (records.isEmpty) return null;
    return PbdbTaxon.fromJson(records.first as Map<String, dynamic>);
  }

  @override
  Future<List<PbdbTaxon>> getTimelineChain(String name) async {
    final uri = Uri.parse(
      '$_base/taxa/list.json'
      '?name=${Uri.encodeComponent(name)}'
      '&rel=all_parents&show=app',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw TaxonFetchException(response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['records'] as List<dynamic>)
        .map((e) => PbdbTaxon.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class TaxonFetchException implements Exception {
  TaxonFetchException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'PBDB request failed ($statusCode)';
}
