import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/fossil_knowledge_repository.dart';
import '../../data/repositories/period_repository.dart';
import '../../data/strata_services.dart';
import '../../models/fossil_taxon.dart';
import '../../models/geologic_period.dart';
import '../../theme/strata_theme.dart';

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
  GeologicEra _selectedEra = GeologicEra.mesozoic;

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
      thumbnails[period.id] = (await _knowledge.iconicForPeriod(
        period.id,
      )).take(3).toList(growable: false);
    }
    return _TimelineData(periods, thumbnails);
  }

  void _retry() => setState(() => _future = _load());

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
          final eraPeriods = data.periods
              .where((period) => period.era == _selectedEra)
              .toList(growable: false);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Text(
                    'Explore the chapters of life on Earth',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: GeologicEra.values.map((era) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(era.label),
                          selected: _selectedEra == era,
                          onSelected: (_) => setState(() => _selectedEra = era),
                          selectedColor: StrataColors.orange.withValues(
                            alpha: .2,
                          ),
                          labelStyle: TextStyle(
                            color: _selectedEra == era
                                ? StrataColors.brown
                                : StrataColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: eraPeriods.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final period = eraPeriods[index];
                    return _PeriodTile(
                      period: period,
                      taxa: data.thumbnails[period.id] ?? const [],
                      onTap: () => context.push('/timeline/${period.id}'),
                    );
                  },
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

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.period,
    required this.taxa,
    required this.onTap,
  });

  final GeologicPeriod period;
  final List<FossilTaxon> taxa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _periodColor(period);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 74,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.layers_outlined, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.name,
                      style: GoogleFonts.libreBaskerville(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ageLabel(period.startMa, period.endMa),
                      style: const TextStyle(
                        color: StrataColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    if (taxa.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: taxa
                            .map((taxon) => _MiniTaxon(taxon: taxon))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: StrataColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTaxon extends StatelessWidget {
  const _MiniTaxon({required this.taxon});
  final FossilTaxon taxon;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      taxon.imageAsset,
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: 36,
        height: 36,
        color: StrataColors.cream,
        child: const Icon(Icons.pets, size: 19, color: StrataColors.brown),
      ),
    ),
  );
}

String _ageLabel(double start, double end) =>
    '${_ageNumber(start)}–${_ageNumber(end)} million years ago';

String _ageNumber(double age) => age == age.roundToDouble()
    ? age.toStringAsFixed(0)
    : age.toStringAsFixed(1);

Color _periodColor(GeologicPeriod period) {
  final value = period.color;
  if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return StrataColors.orange;
  }
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}
