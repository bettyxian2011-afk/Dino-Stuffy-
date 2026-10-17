import '../../models/fossil_taxon.dart';
import '../catalog/knowledge_assets.dart';

/// Shared fossil knowledge (`taxa`) for Identify, Deep Time, and Kids Mode.
///
/// Implementations are **read-only**. Catalog writes happen outside the app.
abstract class FossilKnowledgeRepository {
  Future<FossilTaxon?> getTaxon(String id);

  Stream<FossilTaxon?> watchTaxon(String id);

  /// Docs with `useInIdentify == true`.
  Future<List<FossilTaxon>> taxaForIdentify();

  /// Iconic taxa whose `periodIds` contain [periodId].
  Future<List<FossilTaxon>> iconicForPeriod(String periodId);

  /// Kid-safe taxa for a realm + period (Kids Mode consumes this later).
  Future<List<FossilTaxon>> kidPool(TaxonRealm realm, String periodId);
}

/// Bundled `assets/data/taxa.json`. Offline / empty-cloud fallback only.
class AssetFossilKnowledgeRepository implements FossilKnowledgeRepository {
  AssetFossilKnowledgeRepository({Map<String, FossilTaxon>? taxa})
    : _seed = taxa;

  final Map<String, FossilTaxon>? _seed;
  Map<String, FossilTaxon>? _cache;

  Future<Map<String, FossilTaxon>> _all() async {
    return _cache ??= _seed ?? await KnowledgeAssets.loadTaxa();
  }

  List<FossilTaxon> _values(Map<String, FossilTaxon> all) =>
      all.values.toList(growable: false);

  @override
  Future<FossilTaxon?> getTaxon(String id) async {
    return (await _all())[id.toLowerCase()];
  }

  @override
  Stream<FossilTaxon?> watchTaxon(String id) async* {
    yield await getTaxon(id);
  }

  @override
  Future<List<FossilTaxon>> taxaForIdentify() async {
    return _values(await _all()).where((t) => t.useInIdentify).toList();
  }

  @override
  Future<List<FossilTaxon>> iconicForPeriod(String periodId) async {
    return _values(
      await _all(),
    ).where((t) => t.iconic && t.periodIds.contains(periodId)).toList();
  }

  @override
  Future<List<FossilTaxon>> kidPool(TaxonRealm realm, String periodId) async {
    return _values(await _all())
        .where(
          (t) =>
              t.kidSafe && t.realm == realm && t.periodIds.contains(periodId),
        )
        .toList();
  }
}

/// Tries a remote (Firestore) source, then the bundled assets.
class FallbackFossilKnowledgeRepository implements FossilKnowledgeRepository {
  FallbackFossilKnowledgeRepository({required this.local, this.remote});

  final FossilKnowledgeRepository local;
  final FossilKnowledgeRepository? remote;

  Future<T> _preferRemote<T>({
    required Future<T> Function(FossilKnowledgeRepository source) read,
    required bool Function(T value) isEmpty,
  }) async {
    final cloud = remote;
    if (cloud == null) return read(local);
    try {
      final value = await read(cloud);
      if (isEmpty(value)) return read(local);
      return value;
    } catch (_) {
      return read(local);
    }
  }

  @override
  Future<FossilTaxon?> getTaxon(String id) {
    return _preferRemote(
      read: (source) => source.getTaxon(id),
      isEmpty: (value) => value == null,
    );
  }

  @override
  Stream<FossilTaxon?> watchTaxon(String id) async* {
    final cloud = remote;
    if (cloud == null) {
      yield* local.watchTaxon(id);
      return;
    }
    try {
      await for (final value in cloud.watchTaxon(id)) {
        if (value != null) {
          yield value;
        } else {
          yield await local.getTaxon(id);
        }
      }
    } catch (_) {
      yield* local.watchTaxon(id);
    }
  }

  @override
  Future<List<FossilTaxon>> taxaForIdentify() {
    return _preferRemote(
      read: (source) => source.taxaForIdentify(),
      isEmpty: (value) => value.isEmpty,
    );
  }

  @override
  Future<List<FossilTaxon>> iconicForPeriod(String periodId) {
    return _preferRemote(
      read: (source) => source.iconicForPeriod(periodId),
      isEmpty: (value) => value.isEmpty,
    );
  }

  @override
  Future<List<FossilTaxon>> kidPool(TaxonRealm realm, String periodId) {
    return _preferRemote(
      read: (source) => source.kidPool(realm, periodId),
      isEmpty: (value) => value.isEmpty,
    );
  }
}
