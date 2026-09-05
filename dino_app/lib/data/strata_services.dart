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
  static IdCatalog? _catalog;

  static Future<void> init() async {
    _catalog ??= await IdCatalog.load();
    _identifyRepository ??= _buildIdentifyRepository();
  }

  static IdentifyRepository get identifyRepository {
    if (_identifyRepository == null) {
      throw StateError('Call StrataServices.init() before using repositories.');
    }
    return _identifyRepository!;
  }

  static IdentifyRepository _buildIdentifyRepository() {
    final catalog = _catalog!;
    if (StrataConfig.hasGeminiApiKey) {
      return GeminiIdentifyRepository(
        vision: GeminiVisionService(apiKey: StrataConfig.geminiApiKey),
        taxonRepository: PbdbTaxonRepository(),
        catalog: catalog,
      );
    }
    return MockIdentifyRepository();
  }
}
