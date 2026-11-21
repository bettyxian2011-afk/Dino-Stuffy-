/// One of the Big Five Phanerozoic mass extinctions, shown on the Deep Time
/// clock. Percentages are broad species-loss estimates, not precise counts.
class MassExtinctionEvent {
  const MassExtinctionEvent({
    required this.id,
    required this.name,
    required this.ageLabel,
    required this.markerMa,
    required this.speciesLossPercent,
    required this.cause,
  });

  final String id;
  final String name;
  final String ageLabel;

  /// Single representative age used to place an event marker on the clock.
  final double markerMa;
  final int speciesLossPercent;
  final String cause;

  static const bigFive = <MassExtinctionEvent>[
    MassExtinctionEvent(
      id: 'end-ordovician',
      name: 'End-Ordovician',
      ageLabel: 'c. 444 million years ago',
      markerMa: 444,
      speciesLossPercent: 86,
      cause:
          'A major ice age lowered sea levels; later melting and sea-level '
          'change stressed marine habitats.',
    ),
    MassExtinctionEvent(
      id: 'late-devonian',
      name: 'Late Devonian',
      ageLabel: 'c. 372–359 million years ago',
      markerMa: 372,
      speciesLossPercent: 75,
      cause:
          'A series of extinction pulses coincided with climate swings and '
          'widespread oxygen-poor oceans.',
    ),
    MassExtinctionEvent(
      id: 'end-permian',
      name: 'End-Permian',
      ageLabel: 'c. 252 million years ago',
      markerMa: 252,
      speciesLossPercent: 96,
      cause:
          'Siberian Traps volcanism drove rapid warming, ocean acidification, '
          'and oxygen loss.',
    ),
    MassExtinctionEvent(
      id: 'end-triassic',
      name: 'End-Triassic',
      ageLabel: 'c. 201 million years ago',
      markerMa: 201.4,
      speciesLossPercent: 80,
      cause:
          'Massive eruptions in the Central Atlantic Magmatic Province added '
          'carbon dioxide, warming climate and disrupting ocean chemistry.',
    ),
    MassExtinctionEvent(
      id: 'end-cretaceous',
      name: 'End-Cretaceous (K–Pg)',
      ageLabel: 'c. 66 million years ago',
      markerMa: 66,
      speciesLossPercent: 76,
      cause:
          'The Chicxulub asteroid impact caused abrupt global disruption; '
          'Deccan volcanism may also have added environmental stress.',
    ),
  ];
}
