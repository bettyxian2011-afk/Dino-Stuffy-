import '../../models/translate.dart';

abstract class TranslateRepository {
  List<TranslatePair> getSamplePairs();

  TranslateResult? translate(TranslateRequest request);
}

class MockTranslateRepository implements TranslateRepository {
  const MockTranslateRepository();

  static const _pairs = <TranslatePair>[
    TranslatePair(
      id: 'de-en-velo',
      sourceLang: 'German',
      targetLang: 'English',
      sourceText:
          '„Die verknöcherten Sehnen entlang der Schwanzwirbel von '
          'Velociraptor deuten auf einen steifen Schwanz zur Balance hin.“',
      result: TranslateResult(
        translatedText:
            'The ossified tendons along the caudal vertebrae of '
            'Velociraptor indicate a stiffened tail used for balance.',
        highlights: ['ossified tendons', 'caudal vertebrae'],
        glossary: [
          GlossaryTerm(
            term: 'Ossified tendons',
            tag: 'Anatomy',
            definition:
                'Tendons converted to bone, forming a lattice that '
                'rigidified the tail in many theropods.',
          ),
          GlossaryTerm(
            term: 'Caudal vertebrae',
            tag: 'Anatomy',
            definition:
                'The tail bones, posterior to the sacrum — distinct from '
                'cervical (neck) vertebrae.',
          ),
        ],
      ),
    ),
    TranslatePair(
      id: 'la-en-name',
      sourceLang: 'Latin',
      targetLang: 'English',
      sourceText: 'Tyrannosaurus rex — “tyrant lizard king”',
      result: TranslateResult(
        translatedText:
            'Tyrannosaurus rex literally means “tyrant lizard king”: '
            'tyrannos (tyrant) + sauros (lizard) + rex (king).',
        highlights: ['tyrant lizard king', 'tyrannos', 'sauros', 'rex'],
        glossary: [
          GlossaryTerm(
            term: 'tyrannos',
            tag: 'Etymology',
            definition: 'Greek for “tyrant” or “absolute ruler.”',
          ),
          GlossaryTerm(
            term: 'sauros',
            tag: 'Etymology',
            definition: 'Greek for “lizard”; common root in dinosaur names.',
          ),
        ],
      ),
    ),
    TranslatePair(
      id: 'fr-en-strata',
      sourceLang: 'French',
      targetLang: 'English',
      sourceText:
          'Les couches sédimentaires du Maastrichtien préservent des '
          'fossiles proches de la limite K–Pg.',
      result: TranslateResult(
        translatedText:
            'The sedimentary strata of the Maastrichtian preserve fossils '
            'near the K–Pg boundary.',
        highlights: ['sedimentary strata', 'Maastrichtian', 'K–Pg boundary'],
        glossary: [
          GlossaryTerm(
            term: 'Maastrichtian',
            tag: 'Chronostratigraphy',
            definition:
                'The final age of the Late Cretaceous, ending at the '
                'Cretaceous–Paleogene (K–Pg) extinction.',
          ),
          GlossaryTerm(
            term: 'K–Pg boundary',
            tag: 'Event',
            definition:
                'The geological marker of the end-Cretaceous mass '
                'extinction (~66 Ma).',
          ),
        ],
      ),
    ),
  ];

  @override
  List<TranslatePair> getSamplePairs() => _pairs;

  @override
  TranslateResult? translate(TranslateRequest request) {
    final normalized = request.sourceText.trim().toLowerCase();
    for (final pair in _pairs) {
      final forward = pair.sourceLang == request.sourceLang &&
          pair.targetLang == request.targetLang &&
          pair.sourceText.toLowerCase().contains(
                normalized.length > 24
                    ? normalized.substring(0, 24)
                    : normalized,
              );
      if (forward) return pair.result;

      // Reverse lookup when languages are swapped: return source as "result"
      // is not ideal — instead match reverse direction by finding pair and
      // synthesizing a simple reverse display.
      final reverse = pair.sourceLang == request.targetLang &&
          pair.targetLang == request.sourceLang &&
          pair.result.translatedText.toLowerCase().contains(
                normalized.length > 24
                    ? normalized.substring(0, 24)
                    : normalized,
              );
      if (reverse) {
        return TranslateResult(
          translatedText: pair.sourceText,
          highlights: const [],
          glossary: pair.result.glossary,
        );
      }
    }

    // Default: if source matches any pair's source regardless of lang labels
    for (final pair in _pairs) {
      if (pair.sourceText.toLowerCase() == normalized ||
          pair.sourceText.toLowerCase().contains(
                normalized.length > 40
                    ? normalized.substring(0, 40)
                    : normalized,
              )) {
        if (request.sourceLang == pair.targetLang &&
            request.targetLang == pair.sourceLang) {
          return TranslateResult(
            translatedText: pair.sourceText,
            highlights: const [],
            glossary: pair.result.glossary,
          );
        }
        return pair.result;
      }
    }

    return null;
  }
}
