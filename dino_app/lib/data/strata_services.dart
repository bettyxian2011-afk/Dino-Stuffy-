import 'package:flutter/foundation.dart';

import '../config/strata_config.dart';
import '../models/fossil_taxon.dart';
import 'catalog/id_catalog.dart';
import 'repositories/account_repository.dart';
import 'repositories/fossil_knowledge_repository.dart';
import 'repositories/firestore_fossil_knowledge_repository.dart';
import 'repositories/period_repository.dart';
import 'repositories/firestore_period_repository.dart';
import 'repositories/ics_period_repository.dart';
import 'repositories/gemini_identify_repository.dart';
import 'repositories/identify_repository.dart';
import 'repositories/taxon_repository.dart';
import 'services/firebase_bootstrap.dart';
import 'services/gemini_vision_service.dart';

/// Shared repositories initialized once at app startup.
class StrataServices {
  StrataServices._();

  static IdentifyRepository? _identifyRepository;
  static AccountRepository? _accountRepository;
  static TaxonRepository? _taxonRepository;
  static FossilKnowledgeRepository? _knowledgeRepository;
  static PeriodRepository? _periodRepository;
  static IdCatalog? _catalog;
  static bool _firebaseReady = false;

  /// True when the live Gemini identify adapter is active.
  static bool get isUsingLiveIdentify =>
      _identifyRepository is GeminiIdentifyRepository;

  /// True after a successful Firebase app construction.
  static bool get isFirebaseReady => _firebaseReady;

  static AccountRepository get accountRepository =>
      _accountRepository ?? const GuestAccountRepository();

  /// Starts local repositories and, when FlutterFire config exists, Firebase.
  static Future<void> init({
    Future<bool> Function()? initializeFirebase,
    FossilKnowledgeRepository? knowledgeRepository,
    PeriodRepository? periodRepository,
    Future<List<FossilTaxon>> Function()? identifyCloudTaxa,
    AccountRepository? accountRepository,
  }) async {
    _firebaseReady =
        await (initializeFirebase ?? FirebaseBootstrap.initialize)();
    _accountRepository ??=
        accountRepository ??
        (_firebaseReady && FirebaseBootstrap.isAppReady
            ? FirebaseAccountRepository()
            : const GuestAccountRepository());
    final localKnowledge = AssetFossilKnowledgeRepository();
    FirestoreFossilKnowledgeRepository? firestoreKnowledge;
    if (_firebaseReady && FirebaseBootstrap.isAppReady) {
      try {
        firestoreKnowledge = FirestoreFossilKnowledgeRepository();
      } catch (e) {
        debugPrint('StrataServices: Firestore knowledge skipped ($e)');
      }
    }
    _knowledgeRepository ??=
        knowledgeRepository ??
        FallbackFossilKnowledgeRepository(
          local: localKnowledge,
          remote: firestoreKnowledge,
        );
    final curatedPeriods = FallbackPeriodRepository(
      local: AssetPeriodRepository(),
      remote: _firebaseReady && FirebaseBootstrap.isAppReady
          ? FirestorePeriodRepository()
          : null,
    );
    _periodRepository ??=
        periodRepository ??
        IcsOverlayPeriodRepository(
          base: curatedPeriods,
          ics: IcsPeriodRepository(),
        );
    _catalog ??= await _loadIdentifyCatalog(
      identifyCloudTaxa: identifyCloudTaxa,
      firestoreKnowledge: firestoreKnowledge,
    );
    _taxonRepository ??= PbdbTaxonRepository();
    _identifyRepository ??= buildIdentifyRepository(
      catalog: _catalog!,
      hasGeminiApiKey: StrataConfig.hasGeminiApiKey,
      geminiApiKey: StrataConfig.geminiApiKey,
      taxonRepository: _taxonRepository,
    );
    debugPrint(
      isUsingLiveIdentify
          ? 'StrataServices: GeminiIdentifyRepository (live vision)'
          : 'StrataServices: MockIdentifyRepository (no GEMINI_API_KEY)',
    );
    debugPrint(
      isFirebaseReady
          ? 'StrataServices: Firebase ready'
          : 'StrataServices: Firebase not configured (local JSON path)',
    );
  }

  static IdentifyRepository get identifyRepository {
    if (_identifyRepository == null) {
      throw StateError('Call StrataServices.init() before using repositories.');
    }
    return _identifyRepository!;
  }

  static TaxonRepository get taxonRepository {
    if (_taxonRepository == null) {
      throw StateError('Call StrataServices.init() before using repositories.');
    }
    return _taxonRepository!;
  }

  static FossilKnowledgeRepository get fossilKnowledgeRepository {
    if (_knowledgeRepository == null) {
      throw StateError('Call StrataServices.init() before using repositories.');
    }
    return _knowledgeRepository!;
  }

  static PeriodRepository get periodRepository =>
      _periodRepository ?? AssetPeriodRepository();

  /// Identify catalog after optional Firestore merge.
  @visibleForTesting
  static IdCatalog get identifyCatalog {
    if (_catalog == null) {
      throw StateError('Call StrataServices.init() before using repositories.');
    }
    return _catalog!;
  }

  static Future<IdCatalog> _loadIdentifyCatalog({
    Future<List<FossilTaxon>> Function()? identifyCloudTaxa,
    FirestoreFossilKnowledgeRepository? firestoreKnowledge,
  }) async {
    final local = await IdCatalog.load();
    final loadCloud = identifyCloudTaxa ?? firestoreKnowledge?.taxaForIdentify;
    if (loadCloud == null) return local;
    try {
      final cloud = await loadCloud();
      if (cloud.isEmpty) return local;
      debugPrint(
        'StrataServices: Identify catalog merged ${cloud.length} cloud taxa',
      );
      return local.mergedWith(cloud);
    } catch (e) {
      debugPrint('StrataServices: Identify catalog using local JSON ($e)');
      return local;
    }
  }

  /// Builds the identify adapter. Exposed for unit tests.
  @visibleForTesting
  static IdentifyRepository buildIdentifyRepository({
    required IdCatalog catalog,
    required bool hasGeminiApiKey,
    String geminiApiKey = '',
    TaxonRepository? taxonRepository,
  }) {
    if (hasGeminiApiKey && geminiApiKey.isNotEmpty) {
      return GeminiIdentifyRepository(
        vision: GeminiVisionService(apiKey: geminiApiKey),
        taxonRepository: taxonRepository ?? PbdbTaxonRepository(),
        catalog: catalog,
      );
    }
    return MockIdentifyRepository();
  }

  /// Clears cached services so tests can re-init cleanly.
  @visibleForTesting
  static void resetForTest() {
    _identifyRepository = null;
    _accountRepository = null;
    _taxonRepository = null;
    _knowledgeRepository = null;
    _periodRepository = null;
    _catalog = null;
    _firebaseReady = false;
  }
}
