/// Example prompts that teach lay terms while helping refine a low-confidence ID.
class RefineExample {
  const RefineExample({
    required this.sentence,
    required this.term,
    required this.definition,
  });

  /// Text the user can tap to insert into the notes field.
  final String sentence;
  final String term;
  final String definition;
}

/// Shared copy for the “potential match — need more info” refine panel.
abstract final class IdentifyRefineCopy {
  static const title = 'Potential match — more detail helps';
  static const titleRock = 'Rock IDs need a second look';

  static const subtitleLowConfidence =
      'Confidence is under 60%, so treat this as a guess. Add what you notice '
      'below and we’ll re-run identification with your notes.';

  static const subtitleRock =
      'Many rocks look alike, so a high percentage can still be wrong. '
      'Describe grain, matrix, and shape below — then re-run with your notes.';

  static const fieldHint =
      'e.g. “Grains look coarse, pebbles are rounded, about the size of a coin…”';

  static String titleFor({required bool isRock}) =>
      isRock ? titleRock : title;

  static String subtitleFor({required bool isRock}) =>
      isRock ? subtitleRock : subtitleLowConfidence;

  static const examples = <RefineExample>[
    RefineExample(
      sentence:
          'The rock looks coarse-grained — I can see individual sand-sized bits.',
      term: 'Grain',
      definition:
          'Grain size is how big the pieces in a rock are. Coarse = you can see '
          'separate grains; fine = smooth, like chalk or mudstone.',
    ),
    RefineExample(
      sentence:
          'Rounded pebbles are stuck in a finer gray matrix between them.',
      term: 'Matrix',
      definition:
          'Matrix is the finer “glue” or sediment between larger pebbles or fossils.',
    ),
    RefineExample(
      sentence:
          'There are curved ridges on a shell-like shape, maybe suture lines.',
      term: 'Suture / ridges',
      definition:
          'On ammonites, sutures are wavy lines where shell walls met. Ridges '
          'are raised lines on the surface — useful for ID.',
    ),
    RefineExample(
      sentence: 'I placed a coin next to it for scale; the object is about 4 cm.',
      term: 'Scale',
      definition:
          'A coin, ruler, or finger in the photo shows real size — that helps '
          'separate look-alike fossils and rocks.',
    ),
    RefineExample(
      sentence:
          'The pebbles are rounded (not sharp), so it may be conglomerate, not a tooth.',
      term: 'Rounded vs angular',
      definition:
          'Rounded pebbles were worn by water; sharp angular bits suggest '
          'broken rock (breccia) or a fresh fracture — not the same as a fossil edge.',
    ),
  ];
}
