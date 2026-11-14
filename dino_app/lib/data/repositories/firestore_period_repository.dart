import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/geologic_period.dart';
import 'period_repository.dart';

class FirestorePeriodRepository implements PeriodRepository {
  FirestorePeriodRepository({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 8),
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final Duration timeout;

  @override
  Future<List<GeologicPeriod>> getPeriods() async {
    final snapshot = await _db.collection('periods').get().timeout(timeout);
    final periods = <GeologicPeriod>[];
    for (final doc in snapshot.docs) {
      try {
        periods.add(GeologicPeriod.fromJson(doc.id, doc.data()));
      } catch (error) {
        debugPrint('FirestorePeriodRepository: skip ${doc.id} ($error)');
      }
    }
    periods.sort((a, b) => a.order.compareTo(b.order));
    return periods;
  }
}

class FallbackFirestorePeriodRepository extends FallbackPeriodRepository {
  FallbackFirestorePeriodRepository({
    required super.local,
    FirebaseFirestore? firestore,
  }) : super(remote: FirestorePeriodRepository(firestore: firestore));
}
