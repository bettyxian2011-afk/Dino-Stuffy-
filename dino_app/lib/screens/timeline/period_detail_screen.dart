import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/fossil_knowledge_repository.dart';
import '../../data/repositories/period_repository.dart';
import '../../data/strata_services.dart';
import '../../models/fossil_taxon.dart';
import '../../models/geologic_period.dart';
import '../../theme/strata_theme.dart';

class PeriodDetailScreen extends StatefulWidget {
  const PeriodDetailScreen({
    super.key,
    required this.periodId,
    this.periodRepository,
    this.knowledgeRepository,
  });

  final String periodId;
  final PeriodRepository? periodRepository;
  final FossilKnowledgeRepository? knowledgeRepository;

  @override
  State<PeriodDetailScreen> createState() => _PeriodDetailScreenState();
}

class _PeriodDetailScreenState extends State<PeriodDetailScreen> {
  late Future<_PeriodDetailData?> _future;

  PeriodRepository get _periods =>
      widget.periodRepository ?? StrataServices.periodRepository;
  FossilKnowledgeRepository get _knowledge =>
      widget.knowledgeRepository ?? StrataServices.fossilKnowledgeRepository;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PeriodDetailData?> _load() async {
    final periods = await _periods.getPeriods();
    GeologicPeriod? period;
    for (final candidate in periods) {
      if (candidate.id == widget.periodId) {
        period = candidate;
        break;
      }
    }
    if (period == null) return null;
    final taxa = List<FossilTaxon>.of(
      await _knowledge.iconicForPeriod(period.id),
    );
    taxa.sort((a, b) {
      final realmOrder = _realmOrder(a.realm).compareTo(_realmOrder(b.realm));
      return realmOrder != 0
          ? realmOrder
          : a.displayName.compareTo(b.displayName);
    });
    return _PeriodDetailData(period, taxa.take(5).toList(growable: false));
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StrataColors.cream,
      appBar: AppBar(
        title: const Text('Deep Time'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<_PeriodDetailData?>(
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
                label: const Text('Could not load this period. Tap to retry.'),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('This period is not available.'));
          }
          return _PeriodBody(data: data);
        },
      ),
    );
  }
}

int _realmOrder(TaxonRealm realm) => switch (realm) {
  TaxonRealm.land => 0,
  TaxonRealm.sky => 1,
  TaxonRealm.ocean => 2,
};

class _PeriodDetailData {
  const _PeriodDetailData(this.period, this.taxa);
  final GeologicPeriod period;
  final List<FossilTaxon> taxa;
}

class _PeriodBody extends StatelessWidget {
  const _PeriodBody({required this.data});
  final _PeriodDetailData data;

  @override
  Widget build(BuildContext context) {
    final period = data.period;
    final color = _periodColor(period);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: .26), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.era.label.toUpperCase(),
                  style: const TextStyle(
                    color: StrataColors.brown,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  period.name,
                  style: GoogleFonts.libreBaskerville(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: StrataColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_ageNumber(period.startMa)}–${_ageNumber(period.endMa)} million years ago',
                  style: const TextStyle(
                    fontSize: 15,
                    color: StrataColors.muted,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  period.blurb,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: StrataColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Iconic fossils',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Meet the animals and other life that help define this chapter.',
                  style: TextStyle(color: StrataColors.muted),
                ),
              ],
            ),
          ),
        ),
        if (data.taxa.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No iconic fossils are in the catalog for this period yet.',
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverList.separated(
              itemCount: data.taxa.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _TaxonCard(taxon: data.taxa[index]),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Text(
              'Period boundaries and colors: International Commission on '
              'Stratigraphy chart · stratigraphy.org/chart · CC BY 4.0.',
              style: const TextStyle(
                color: StrataColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaxonCard extends StatelessWidget {
  const _TaxonCard({required this.taxon});
  final FossilTaxon taxon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => context.push(
          '/species/${Uri.encodeComponent(taxon.scientificName)}'
          '?group=${Uri.encodeComponent(taxon.commonGroup)}'
          '&family=${Uri.encodeComponent(taxon.family)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  taxon.imageAsset,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 76,
                    height: 76,
                    color: StrataColors.cream,
                    child: const Icon(
                      Icons.pets,
                      color: StrataColors.brown,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taxon.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: StrataColors.ink,
                      ),
                    ),
                    Text(
                      taxon.scientificName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: StrataColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _LabelPill(label: taxon.realm.name),
                        _LabelPill(label: taxon.family),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: StrataColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelPill extends StatelessWidget {
  const _LabelPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: StrataColors.cream,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        color: StrataColors.brown,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

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
