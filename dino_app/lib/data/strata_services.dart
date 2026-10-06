import 'package:flutter/foundation.dart';

import '../config/strata_config.dart';
import 'catalog/id_catalog.dart';
import 'repositories/gemini_identify_repository.dart';
import 'repositories/identify_repository.dart';
import 'repositories/taxon_repository.dart';
import 'services/firebase_bootstrap.dart';
import 'services/gemini_vision_service.dart';

/// Shared repositories initialized once at app startup.
class StrataServices {
  StrataServices._();

  static IdentifyRepository? _identifyRepository;
  static TaxonRepository? _taxonRepository;
  static IdCatalog? _catalog;
  static bool _firebaseReady = false;

  /// True when the live Gemini identify adapter is active.
  static bool get isUsingLiveIdentify =>
      _identifyRepository is GeminiIdentifyRepository;

  /// True after a successful Firebase app construction.
  static bool get isFirebaseReady => _firebaseReady;

  /// Starts local repositories and, when FlutterFire config exists, Firebase.
  static Future<void> init({
    Future<bool> Function()? initializeFirebase,
  }) async {
    _firebaseReady =
        await (initializeFirebase ?? FirebaseBootstrap.initialize)();
    _catalog ??= await IdCatalog.load();
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
    _taxonRepository = null;
    _catalog = null;
    _firebaseReady = false;
  }
}
