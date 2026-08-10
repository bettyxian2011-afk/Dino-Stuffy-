class GlossaryTerm {
  const GlossaryTerm({
    required this.term,
    required this.tag,
    required this.definition,
  });

  final String term;
  final String tag;
  final String definition;
}

class TranslateRequest {
  const TranslateRequest({
    required this.sourceText,
    required this.sourceLang,
    required this.targetLang,
  });

  final String sourceText;
  final String sourceLang;
  final String targetLang;
}

class TranslateResult {
  const TranslateResult({
    required this.translatedText,
    required this.highlights,
    required this.glossary,
  });

  final String translatedText;
  final List<String> highlights;
  final List<GlossaryTerm> glossary;
}

class TranslatePair {
  const TranslatePair({
    required this.id,
    required this.sourceLang,
    required this.targetLang,
    required this.sourceText,
    required this.result,
  });

  final String id;
  final String sourceLang;
  final String targetLang;
  final String sourceText;
  final TranslateResult result;
}
