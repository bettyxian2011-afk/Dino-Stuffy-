import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/fossil_knowledge_repository.dart';
import '../../data/repositories/period_repository.dart';
import '../../data/strata_services.dart';
import '../../models/fossil_taxon.dart';
import '../../models/geologic_eon.dart';
import '../../models/geologic_period.dart';
import '../../models/mass_extinction_event.dart';
import '../../theme/strata_theme.dart';
import 'deep_time_clock.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({
    super.key,
    this.periodRepository,
    this.knowledgeRepository,
  });

  final PeriodRepository? periodRepository;
  final FossilKnowledgeRepository? knowledgeRepository;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late Future<_TimelineData> _future;
  double? _selectedMa;
  String? _activeExtinctionId;

  PeriodRepository get _periods =>
      widget.periodRepository ?? StrataServices.periodRepository;
  FossilKnowledgeRepository get _knowledge =>
      widget.knowledgeRepository ?? StrataServices.fossilKnowledgeRepository;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TimelineData> _load() async {
    final periods = await _periods.getPeriods();
    final thumbnails = <String, List<FossilTaxon>>{};
    for (final period in periods) {
      thumbnails[period.id] = (await _knowledge.iconicForPeriod(period.id))
          .take(3)
          .toList(growable: false);
    }
    return _TimelineData(periods, thumbnails);
  }

  void _retry() => setState(() => _future = _load());

  GeologicPeriod? _periodAt(double age, List<GeologicPeriod> periods) {
    for (final period in periods) {
      if (age <= period.startMa && age >= period.endMa) return period;
    }
    return null;
  }

  GeologicEon _eonAt(double age) => GeologicEon.all.firstWhere(
    (eon) => age <= eon.startMa && age >= eon.endMa,
    orElse: () => GeologicEon.phanerozoic,
  );

  void _selectEon(GeologicEon eon) {
    setState(() {
      _selectedMa = (eon.startMa + eon.endMa) / 2;
      _activeExtinctionId = null;
    });
  }

  void _selectAge(double age) {
    final oldest = GeologicEon.hadean.startMa;
    final youngest = GeologicEon.phanerozoic.endMa;
    final boundedAge = age.clamp(youngest, oldest).toDouble();
    setState(() {
      _selectedMa = boundedAge;
      _activeExtinctionId = null;
    });
  }

  void _selectPeriod(GeologicPeriod period) {
    setState(() {
      _selectedMa = (period.startMa + period.endMa) / 2;
      _activeExtinctionId = null;
    });
  }

  void _selectExtinction(MassExtinctionEvent event) {
    setState(() {
      _selectedMa = event.markerMa;
      _activeExtinctionId = event.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StrataColors.cream,
      appBar: AppBar(title: const Text('Deep Time')),
      body: FutureBuilder<_TimelineData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Could not load periods. Tap to retry.'),
              ),
            );
          }
          final data = snapshot.data!;
          final periods = [...data.periods]
            ..sort((a, b) => b.startMa.compareTo(a.startMa));
          if (periods.isEmpty) {
            return const Center(child: Text('No periods are available.'));
          }
          final defaultPeriod = periods.firstWhere(
            (period) => period.id == 'cretaceous',
            orElse: () => periods.last,
          );
          final selectedMa =
              _selectedMa ?? (defaultPeriod.startMa + defaultPeriod.endMa) / 2;
          final selectedPeriod = _periodAt(selectedMa, periods);
          final selectedEon = _eonAt(selectedMa);
          final activeExtinction = MassExtinctionEvent.bigFive
              .where((event) => event.id == _activeExtinctionId)
              .firstOrNull;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    'Earth history at a glance · 4,567 million years',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DeepTimeClock(
                    periods: periods,
                    eons: GeologicEon.all,
                    selectedLabel: selectedPeriod?.name ?? selectedEon.name,
                    selectedMa: selectedMa,
                    extinctions: MassExtinctionEvent.bigFive,
                    activeExtinctionId: _activeExtinctionId,
                    onAgeChanged: _selectAge,
                    onExtinctionSelected: _selectExtinction,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Text(
                    'Earth forms at 12 o’clock; time moves clockwise toward '
                    'now. Broad arcs show the Hadean, Archean, Proterozoic, '
                    'and Phanerozoic. The established periods compress near '
                    'today. Drag the hand or tap a numbered extinction marker.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: StrataColors.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (
                        var index = 0;
                        index < MassExtinctionEvent.bigFive.length;
                        index++
                      )
                        _ExtinctionChip(
                          event: MassExtinctionEvent.bigFive[index],
                          number: index + 1,
                          selected:
                              MassExtinctionEvent.bigFive[index].id ==
                              _activeExtinctionId,
                          onTap: () => _selectExtinction(
                            MassExtinctionEvent.bigFive[index],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (activeExtinction != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _ExtinctionDetail(event: activeExtinction),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Text(
                    'Phanerozoic · 539 Myr (11.8%) · periods grouped by era',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      for (final era in GeologicEra.values)
                        _EraPeriodsGroup(
                          era: era,
                          periods: periods
                              .where((period) => period.era == era)
                              .toList(growable: false),
                          selectedPeriodId: selectedPeriod?.id,
                          onSelect: _selectPeriod,
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Text(
                    'Precambrian eons',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final eon in GeologicEon.precambrian)
                        _EonChip(
                          eon: eon,
                          selected:
                              eon == selectedEon && selectedPeriod == null,
                          onTap: () => _selectEon(eon),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _SelectedTimeCard(
                    eon: selectedEon,
                    period: selectedPeriod,
                    taxa: selectedPeriod == null
                        ? const []
                        : data.thumbnails[selectedPeriod.id] ?? const [],
                    onOpen: selectedPeriod == null
                        ? null
                        : () => context.push('/timeline/${selectedPeriod.id}'),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 2, 20, 24),
                  child: Text(
                    'Eon spans and period colors follow the ICS chart at '
                    'stratigraphy.org/chart. The Hadean begins at Earth’s '
                    'estimated formation age; all ages are approximate. '
                    'Species-loss percentages are estimates and vary by study; '
                    'the fossil record is incomplete. Causes are scientific '
                    'explanations with differing levels of certainty. '
                    'Source: Barnosky et al., Nature (2011), '
                    'doi:10.1038/nature09678.',
                    style: TextStyle(
                      color: StrataColors.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineData {
  const _TimelineData(this.periods, this.thumbnails);
  final List<GeologicPeriod> periods;
  final Map<String, List<FossilTaxon>> thumbnails;
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final GeologicPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _periodColor(period);
    return Semantics(
      button: true,
      selected: selected,
      label: '${period.name}, ${_periodAge(period)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .24) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? color
                  : StrataColors.muted.withValues(alpha: .2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                period.name,
                style: TextStyle(
                  color: StrataColors.ink,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtinctionChip extends StatelessWidget {
  const _ExtinctionChip({
    required this.event,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final MassExtinctionEvent event;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: CircleAvatar(
        radius: 10,
        backgroundColor: selected ? StrataColors.ink : StrataColors.gold,
        child: Text(
          '$number',
          style: TextStyle(
            color: selected ? Colors.white : StrataColors.ink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      label: Text(event.name),
      backgroundColor: selected
          ? StrataColors.gold.withValues(alpha: .35)
          : Colors.white,
      side: BorderSide(
        color: selected
            ? StrataColors.brown
            : StrataColors.muted.withValues(alpha: .2),
      ),
      labelStyle: const TextStyle(
        color: StrataColors.ink,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EraPeriodsGroup extends StatelessWidget {
  const _EraPeriodsGroup({
    required this.era,
    required this.periods,
    required this.selectedPeriodId,
    required this.onSelect,
  });

  final GeologicEra era;
  final List<GeologicPeriod> periods;
  final String? selectedPeriodId;
  final ValueChanged<GeologicPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) return const SizedBox.shrink();
    final selected = periods.any((period) => period.id == selectedPeriodId);
    final range =
        '${_formatMa(periods.first.startMa)}–${_formatMa(periods.last.endMa)} Ma';
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        key: ValueKey('${era.name}-$selected'),
        initiallyExpanded: selected,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        title: Row(
          children: [
            Expanded(
              child: Text(
                era.label,
                style: const TextStyle(
                  color: StrataColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              range,
              style: const TextStyle(
                color: StrataColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final period in periods)
                _PeriodChip(
                  period: period,
                  selected: period.id == selectedPeriodId,
                  onTap: () => onSelect(period),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EonChip extends StatelessWidget {
  const _EonChip({
    required this.eon,
    required this.selected,
    required this.onTap,
  });

  final GeologicEon eon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(eon.colorValue);
    return ActionChip(
      onPressed: onTap,
      avatar: CircleAvatar(radius: 7, backgroundColor: color),
      label: Text(
        '${eon.name} · ${_formatDuration(eon)} Myr · '
        '${_eonShare(eon).toStringAsFixed(1)}%',
      ),
      backgroundColor: selected ? color.withValues(alpha: .2) : Colors.white,
      side: BorderSide(color: color.withValues(alpha: selected ? 1.0 : .5)),
      labelStyle: const TextStyle(
        color: StrataColors.ink,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SelectedTimeCard extends StatelessWidget {
  const _SelectedTimeCard({
    required this.eon,
    required this.period,
    required this.taxa,
    required this.onOpen,
  });

  final GeologicEon eon;
  final GeologicPeriod? period;
  final List<FossilTaxon> taxa;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final color = period == null
        ? Color(eon.colorValue)
        : _periodColor(period!);
    final title = period?.name ?? eon.name;
    final age = period == null
        ? '${_formatMa(eon.startMa)}–${_formatMa(eon.endMa)} Ma'
        : _periodAge(period!);
    final blurb = period?.blurb ?? eon.blurb;
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (period != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${period!.era.label.toUpperCase()} ERA · PHANEROZOIC EON',
                  style: const TextStyle(
                    color: StrataColors.muted,
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.libreBaskerville(
                      color: StrataColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  age,
                  style: const TextStyle(
                    color: StrataColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 4,
              width: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            if (blurb.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                blurb,
                style: const TextStyle(
                  color: StrataColors.ink,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ],
            if (taxa.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final taxon in taxa)
                    _MiniTaxonPill(taxon: taxon, color: color),
                ],
              ),
            ],
            if (onOpen != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('Explore $title'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniTaxonPill extends StatelessWidget {
  const _MiniTaxonPill({required this.taxon, required this.color});
  final FossilTaxon taxon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 9, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Image.asset(
              taxon.imageAsset,
              width: 27,
              height: 27,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: Colors.white,
                child: const SizedBox(
                  width: 27,
                  height: 27,
                  child: Icon(Icons.pets, size: 15, color: StrataColors.brown),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            taxon.displayName,
            style: const TextStyle(
              color: StrataColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtinctionDetail extends StatelessWidget {
  const _ExtinctionDetail({required this.event});
  final MassExtinctionEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: StrataColors.gold.withValues(alpha: .18),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: StrataColors.brown,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.name,
                    style: const TextStyle(
                      color: StrataColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '~${event.speciesLossPercent}% species lost',
                  style: const TextStyle(
                    color: StrataColors.brown,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                '${event.ageLabel}. ${event.cause}',
                style: const TextStyle(
                  color: StrataColors.ink,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _periodAge(GeologicPeriod period) =>
    '${_formatMa(period.startMa)}–${_formatMa(period.endMa)} Ma';

String _formatDuration(GeologicEon eon) => _formatMa(eon.startMa - eon.endMa);

double _eonShare(GeologicEon eon) =>
    (eon.startMa - eon.endMa) / GeologicEon.hadean.startMa * 100;

String _formatMa(double age) => age == age.roundToDouble()
    ? age.toStringAsFixed(0)
    : age.toStringAsFixed(1);

Color _periodColor(GeologicPeriod period) {
  final value = period.color;
  if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return StrataColors.orange;
  }
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}
