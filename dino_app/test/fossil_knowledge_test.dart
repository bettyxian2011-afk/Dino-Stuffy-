import 'dart:typed_data';

import 'package:dino_app/data/catalog/id_catalog.dart';
import 'package:dino_app/data/repositories/fossil_knowledge_repository.dart';
import 'package:dino_app/data/repositories/gemini_identify_repository.dart';
import 'package:dino_app/data/repositories/taxon_repository.dart';
import 'package:dino_app/data/services/gemini_vision_service.dart';
import 'package:dino_app/data/services/identification_heuristics.dart';
import 'package:dino_app/data/services/image_compressor.dart';
import 'package:dino_app/data/strata_services.dart';
import 'package:dino_app/models/fossil_taxon.dart';
import 'package:dino_app/models/id_result.dart';
import 'package:dino_app/models/pbdb_taxon.dart';
import 'package:flutter_test/flutter_test.dart';

FossilTaxon _taxon({
  required String id,
  String? scientificName,
  String commonGroup = 'Ammonite',
  String family = 'Dactylioceratidae',
  List<String> taxonomy = const ['Mollusca', 'Cephalopoda'],
  List<TaxonFact> facts = const [
    TaxonFact(icon: 'schedule', value: '183Ma', label: 'Cloud age'),
  ],
  String tip = '',
  String imageAsset = 'assets/images/cloud.png',
  bool useInIdentify = true,
  bool kidSafe = false,
  bool iconic = false,
  TaxonRealm realm = TaxonRealm.ocean,
  List<String> periodIds = const ['jurassic'],
}) {
  return FossilTaxon(
    id: id,
    scientificName: scientificName ?? id[0].toUpperCase() + id.substring(1),
    commonGroup: commonGroup,
    family: family,
    taxonomy: taxonomy,
    realm: realm,
    periodIds: periodIds,
    facts: facts,
    imageAsset: imageAsset,
    tip: tip,
    useInIdentify: useInIdentify,
    kidSafe: kidSafe,
    iconic: iconic,
  );
}

class _MemoryKnowledge implements FossilKnowledgeRepository {
  _MemoryKnowledge(this.taxa);

  final List<FossilTaxon> taxa;

  @override
  Future<FossilTaxon?> getTaxon(String id) async {
    final lower = id.toLowerCase();
    for (final taxon in taxa) {
      if (taxon.id == lower) return taxon;
    }
    return null;
  }

  @override
  Stream<FossilTaxon?> watchTaxon(String id) async* {
    yield await getTaxon(id);
  }

  @override
  Future<List<FossilTaxon>> taxaForIdentify() async =>
      taxa.where((t) => t.useInIdentify).toList();

  @override
  Future<List<FossilTaxon>> iconicForPeriod(String periodId) async =>
      taxa.where((t) => t.iconic && t.periodIds.contains(periodId)).toList();

  @override
  Future<List<FossilTaxon>> kidPool(TaxonRealm realm, String periodId) async =>
      taxa
          .where(
            (t) =>
                t.kidSafe && t.realm == realm && t.periodIds.contains(periodId),
          )
          .toList();
}

class _FailingKnowledge implements FossilKnowledgeRepository {
  @override
  Future<FossilTaxon?> getTaxon(String id) =>
      Future.error(StateError('offline'));

  @override
  Stream<FossilTaxon?> watchTaxon(String id) =>
      Stream.error(StateError('offline'));

  @override
  Future<List<FossilTaxon>> taxaForIdentify() =>
      Future.error(StateError('offline'));

  @override
  Future<List<FossilTaxon>> iconicForPeriod(String periodId) =>
      Future.error(StateError('offline'));

  @override
  Future<List<FossilTaxon>> kidPool(TaxonRealm realm, String periodId) =>
      Future.error(StateError('offline'));
}

class _EmptyTaxonRepository implements TaxonRepository {
  @override
  Future<PbdbTaxon?> findTaxon(String name) async => null;

  @override
  Future<List<PbdbTaxon>> getTimelineChain(String name) async => const [];
}

class _FixedTaxonRepository implements TaxonRepository {
  _FixedTaxonRepository(this.taxon);

  final PbdbTaxon taxon;

  @override
  Future<PbdbTaxon?> findTaxon(String name) async => taxon;

  @override
  Future<List<PbdbTaxon>> getTimelineChain(String name) async => const [];
}

const _pbdbDactylioceras = PbdbTaxon(
  name: 'Dactylioceras',
  rank: 'genus',
  attribution: '(Hyatt 1867)',
  firstInterval: 'Hettangian',
  lastInterval: 'Bajocian',
  occurrenceCount: 496,
);

int _expectedConfidence({required bool inCatalog}) {
  return IdentificationHeuristics.adjustedConfidence(
    modelConfidence: 88,
    inLocalCatalog: inCatalog,
    pbdbGenusRank: true,
    pbdbOccurrences: 496,
  );
}

class _PassthroughCompressor extends ImageCompressor {
  const _PassthroughCompressor();

  @override
  Uint8List forVision(Uint8List bytes) => bytes;
}

class _StubVision extends GeminiVisionService {
  _StubVision(this.result) : super(apiKey: 'test-not-for-network');

  final GeminiVisionResult result;

  @override
  Future<GeminiVisionResult> identifyPhoto({
    required Uint8List jpegBytes,
    required List<String> catalogGenera,
    String? userNotes,
  }) async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(StrataServices.resetForTest);

  group('AssetFossilKnowledgeRepository', () {
    test('filters identify, iconic, and kid pools from bundled taxa', () async {
      final repo = AssetFossilKnowledgeRepository(
        taxa: {
          'alpha': _taxon(
            id: 'alpha',
            useInIdentify: true,
            iconic: true,
            periodIds: const ['cretaceous'],
            realm: TaxonRealm.land,
            kidSafe: true,
          ),
          'beta': _taxon(
            id: 'beta',
            useInIdentify: false,
            iconic: true,
            periodIds: const ['jurassic'],
            realm: TaxonRealm.ocean,
          ),
        },
      );

      final identify = await repo.taxaForIdentify();
      expect(identify.map((t) => t.id), ['alpha']);

      final iconic = await repo.iconicForPeriod('cretaceous');
      expect(iconic.map((t) => t.id), ['alpha']);
      expect(await repo.iconicForPeriod('jurassic'), hasLength(1));

      final kids = await repo.kidPool(TaxonRealm.land, 'cretaceous');
      expect(kids.map((t) => t.id), ['alpha']);
      expect(await repo.kidPool(TaxonRealm.ocean, 'cretaceous'), isEmpty);

      expect((await repo.getTaxon('Alpha'))!.id, 'alpha');
    });
  });

  group('FallbackFossilKnowledgeRepository', () {
    test('uses local taxa when remote fails', () async {
      final local = _MemoryKnowledge([
        _taxon(id: 'alpha', useInIdentify: true),
      ]);
      final repo = FallbackFossilKnowledgeRepository(
        local: local,
        remote: _FailingKnowledge(),
      );
      final identify = await repo.taxaForIdentify();
      expect(identify, hasLength(1));
      expect(identify.first.id, 'alpha');
    });

    test('uses local taxa when remote is empty', () async {
      final local = _MemoryKnowledge([_taxon(id: 'localone')]);
      final repo = FallbackFossilKnowledgeRepository(
        local: local,
        remote: _MemoryKnowledge(const []),
      );
      expect((await repo.taxaForIdentify()).single.id, 'localone');
    });
  });

  group('IdCatalog.mergedWith', () {
    late IdCatalog local;

    setUpAll(() async {
      local = await IdCatalog.load();
    });

    test('cloud facts, taxonomy, family, and commonGroup override', () {
      final localEntry = local.entryFor('Dactylioceras')!;
      final merged = local.mergedWith([
        _taxon(
          id: 'dactylioceras',
          scientificName: 'Dactylioceras',
          commonGroup: 'Cloud ammonite',
          family: 'CloudFamily',
          taxonomy: const ['Cloudia', 'Testacea'],
          facts: const [
            TaxonFact(icon: 'schedule', value: '183Ma', label: 'Cloud age'),
          ],
          tip: '',
          imageAsset: 'assets/images/should-not-replace.png',
        ),
      ]);

      final entry = merged.entryFor('Dactylioceras')!;
      expect(entry.commonGroup, 'Cloud ammonite');
      expect(entry.family, 'CloudFamily');
      expect(entry.taxonomy, ['Cloudia', 'Testacea']);
      expect(entry.facts.single.value, '183Ma');
      expect(entry.thumbnail, localEntry.thumbnail);
      expect(entry.tip, localEntry.tip);
      expect(entry.factsFromCloud, isTrue);
      expect(merged.entryFor('Harpoceras')!.family, 'Hildoceratidae');
      expect(merged.entryFor('Harpoceras')!.factsFromCloud, isFalse);
    });

    test('skips taxa not used in Identify', () {
      final merged = local.mergedWith([
        _taxon(
          id: 'dactylioceras',
          scientificName: 'Dactylioceras',
          family: 'ShouldNotApply',
          useInIdentify: false,
        ),
      ]);
      expect(merged.entryFor('Dactylioceras')!.family, 'Dactylioceratidae');
    });
  });

  group('StrataServices Identify catalog', () {
    test('keeps local JSON facts when Firebase is not configured', () async {
      await StrataServices.init(initializeFirebase: () async => false);
      expect(StrataServices.isFirebaseReady, isFalse);
      final entry = StrataServices.identifyCatalog.entryFor('Dactylioceras')!;
      expect(entry.facts.first.value, '180Ma');
      expect(entry.family, 'Dactylioceratidae');
    });

    test('keeps local JSON when the cloud read throws', () async {
      await StrataServices.init(
        initializeFirebase: () async => false,
        identifyCloudTaxa: () async => throw StateError('offline'),
      );
      final entry = StrataServices.identifyCatalog.entryFor('Dactylioceras')!;
      expect(entry.facts.first.value, '180Ma');
    });

    test('keeps local JSON when the cloud read is empty', () async {
      await StrataServices.init(
        initializeFirebase: () async => false,
        identifyCloudTaxa: () async => const [],
      );
      final entry = StrataServices.identifyCatalog.entryFor('Dactylioceras')!;
      expect(entry.facts.first.value, '180Ma');
    });

    test('overlays cloud taxon fields when a cloud list is supplied', () async {
      await StrataServices.init(
        initializeFirebase: () async => false,
        identifyCloudTaxa: () async => [
          _taxon(
            id: 'dactylioceras',
            scientificName: 'Dactylioceras',
            commonGroup: 'Cloud ammonite',
            family: 'CloudFamily',
            taxonomy: const ['Cloudia'],
            facts: const [
              TaxonFact(icon: 'schedule', value: '183Ma', label: 'Cloud age'),
            ],
          ),
        ],
      );
      final entry = StrataServices.identifyCatalog.entryFor('Dactylioceras')!;
      expect(entry.facts.single.value, '183Ma');
      expect(entry.family, 'CloudFamily');
      expect(entry.commonGroup, 'Cloud ammonite');
      expect(entry.taxonomy, ['Cloudia']);
    });
  });

  group('GeminiIdentifyRepository catalog merge', () {
    test('result facts and labels come from the cloud taxon', () async {
      final local = await IdCatalog.load();
      final catalog = local.mergedWith([
        _taxon(
          id: 'dactylioceras',
          scientificName: 'Dactylioceras',
          commonGroup: 'Cloud ammonite',
          family: 'CloudFamily',
          taxonomy: const ['Cloudia', 'Testacea'],
          facts: const [
            TaxonFact(icon: 'schedule', value: '183Ma', label: 'Cloud age'),
            TaxonFact(icon: 'public', value: 'Tethys', label: 'Cloud range'),
          ],
        ),
      ]);

      final repo = GeminiIdentifyRepository(
        vision: _StubVision(
          const GeminiVisionResult(
            assessment: IdentifyAssessment.fossil,
            candidates: [
              GeminiVisionCandidate(genus: 'Dactylioceras', confidence: 88),
            ],
          ),
        ),
        taxonRepository: _EmptyTaxonRepository(),
        catalog: catalog,
        compressor: const _PassthroughCompressor(),
      );

      final result = await repo.identify(Uint8List.fromList([1, 2, 3]));
      expect(result.assessment, IdentifyAssessment.fossil);
      expect(result.taxonomy, ['Cloudia', 'Testacea']);
      expect(result.bestMatch.commonGroup, 'Cloud ammonite');
      expect(result.bestMatch.family, 'CloudFamily');
      expect(result.facts.any((f) => f.value == '183Ma'), isTrue);
      expect(result.candidates, isNotEmpty);
    });

    test('cloud facts replace PBDB chips without changing the score', () async {
      final local = await IdCatalog.load();
      final catalog = local.mergedWith([
        _taxon(
          id: 'dactylioceras',
          scientificName: 'Dactylioceras',
          commonGroup: 'Cloud ammonite',
          family: 'CloudFamily',
          facts: const [
            TaxonFact(icon: 'schedule', value: '190–174Ma', label: 'Cloud age'),
          ],
        ),
      ]);

      final repo = GeminiIdentifyRepository(
        vision: _StubVision(
          const GeminiVisionResult(
            assessment: IdentifyAssessment.fossil,
            candidates: [
              GeminiVisionCandidate(genus: 'Dactylioceras', confidence: 88),
            ],
          ),
        ),
        taxonRepository: _FixedTaxonRepository(_pbdbDactylioceras),
        catalog: catalog,
        compressor: const _PassthroughCompressor(),
      );

      final result = await repo.identify(Uint8List.fromList([1, 2, 3]));
      expect(result.pbdbVerified, isTrue);
      expect(result.bestMatch.family, 'CloudFamily');
      expect(result.bestMatch.commonGroup, 'Cloud ammonite');
      expect(result.facts.map((f) => f.value), contains('190–174Ma'));
      expect(result.facts.map((f) => f.label), isNot(contains('PBDB range')));
      expect(result.primaryConfidence, _expectedConfidence(inCatalog: true));
    });

    test(
      'local catalog still shows PBDB facts when Firestore did not overlay',
      () async {
        final catalog = await IdCatalog.load();
        final repo = GeminiIdentifyRepository(
          vision: _StubVision(
            const GeminiVisionResult(
              assessment: IdentifyAssessment.fossil,
              candidates: [
                GeminiVisionCandidate(genus: 'Dactylioceras', confidence: 88),
              ],
            ),
          ),
          taxonRepository: _FixedTaxonRepository(_pbdbDactylioceras),
          catalog: catalog,
          compressor: const _PassthroughCompressor(),
        );

        final result = await repo.identify(Uint8List.fromList([1, 2, 3]));
        expect(result.facts.map((f) => f.label), contains('PBDB range'));
        expect(result.facts.map((f) => f.value), isNot(contains('180Ma')));
        expect(result.primaryConfidence, _expectedConfidence(inCatalog: true));
        expect(result.bestMatch.family, 'Dactylioceratidae');
      },
    );
  });
}
