import 'package:flutter/foundation.dart';

import '../config/strata_config.dart';
import 'catalog/id_catalog.dart';
import 'repositories/gemini_identify_repository.dart';
import 'repositories/identify_repository.dart';
import 'repositories/taxon_repository.dart';
import 'services/gemini_vision_service.dart';

/// Shared repositories initialized once at app startup.
class StrataServices {
  StrataServices._();

  static IdentifyRepository? _identifyRepository;
  static TaxonRepository? _taxonRepository;
  static IdCatalog? _catalog;

  /// True when the live Gemini identify adapter is active.
  static bool get isUsingLiveIdentify =>
      _identifyRepository is GeminiIdentifyRepository;

  static Future<void> init() async {
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
  }
}
