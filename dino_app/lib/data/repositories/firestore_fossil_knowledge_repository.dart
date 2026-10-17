import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/fossil_taxon.dart';
import 'fossil_knowledge_repository.dart';

/// Read-only Cloud Firestore `taxa` collection.
class FirestoreFossilKnowledgeRepository implements FossilKnowledgeRepository {
  FirestoreFossilKnowledgeRepository({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 8),
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final Duration timeout;

  CollectionReference<Map<String, dynamic>> get _taxa => _db.collection('taxa');

  FossilTaxon? _parse(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      return FossilTaxon.fromJson(id, data);
    } catch (e) {
      debugPrint('FirestoreFossilKnowledgeRepository: skip $id ($e)');
      return null;
    }
  }

  List<FossilTaxon> _parseDocs(QuerySnapshot<Map<String, dynamic>> snap) {
    return [for (final doc in snap.docs) ?_parse(doc.id, doc.data())];
  }

  @override
  Future<FossilTaxon?> getTaxon(String id) async {
    final doc = await _taxa.doc(id.toLowerCase()).get().timeout(timeout);
    return _parse(doc.id, doc.data());
  }

  @override
  Stream<FossilTaxon?> watchTaxon(String id) {
    return _taxa
        .doc(id.toLowerCase())
        .snapshots()
        .map((doc) => _parse(doc.id, doc.data()));
  }

  @override
  Future<List<FossilTaxon>> taxaForIdentify() async {
    final snap = await _taxa
        .where('useInIdentify', isEqualTo: true)
        .get()
        .timeout(timeout);
    return _parseDocs(snap);
  }

  @override
  Future<List<FossilTaxon>> iconicForPeriod(String periodId) async {
    final snap = await _taxa
        .where('iconic', isEqualTo: true)
        .get()
        .timeout(timeout);
    return _parseDocs(
      snap,
    ).where((t) => t.periodIds.contains(periodId)).toList();
  }

  @override
  Future<List<FossilTaxon>> kidPool(TaxonRealm realm, String periodId) async {
    final snap = await _taxa
        .where('kidSafe', isEqualTo: true)
        .get()
        .timeout(timeout);
    return _parseDocs(
      snap,
    ).where((t) => t.realm == realm && t.periodIds.contains(periodId)).toList();
  }
}
