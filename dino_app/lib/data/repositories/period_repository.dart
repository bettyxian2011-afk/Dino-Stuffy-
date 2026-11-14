import '../../models/geologic_period.dart';
import '../catalog/knowledge_assets.dart';

/// Read-only geological periods, with the bundled catalog as offline fallback.
abstract class PeriodRepository {
  Future<List<GeologicPeriod>> getPeriods();
}

class AssetPeriodRepository implements PeriodRepository {
  factory AssetPeriodRepository({List<GeologicPeriod>? periods}) =>
      AssetPeriodRepository._(periods);

  AssetPeriodRepository._(this._periods);

  final List<GeologicPeriod>? _periods;

  @override
  Future<List<GeologicPeriod>> getPeriods() async =>
      _periods ?? KnowledgeAssets.loadPeriods();
}

class FallbackPeriodRepository implements PeriodRepository {
  FallbackPeriodRepository({required this.local, this.remote});

  final PeriodRepository local;
  final PeriodRepository? remote;

  @override
  Future<List<GeologicPeriod>> getPeriods() async {
    try {
      final periods = await remote?.getPeriods();
      if (periods != null && periods.isNotEmpty) return periods;
    } catch (_) {
      // Keep Deep Time available if Firestore is offline or not configured.
    }
    return local.getPeriods();
  }
}
