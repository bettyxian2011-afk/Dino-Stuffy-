import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/taxon_repository.dart';
import '../../data/services/taxon_fact_mapper.dart';
import '../../data/strata_services.dart';
import '../../models/pbdb_taxon.dart';
import '../../theme/strata_theme.dart';
import '../../widgets/gradient_cta_button.dart';

/// Species profile backed by Paleobiology Database taxon records.
class SpeciesProfileScreen extends StatefulWidget {
  const SpeciesProfileScreen({
    super.key,
    required this.genus,
    this.commonGroup,
    this.family,
    TaxonRepository? taxonRepository,
  }) : taxonRepository = taxonRepository ?? const _DefaultTaxonRepo();

  final String genus;
  final String? commonGroup;
  final String? family;
  final TaxonRepository taxonRepository;

  @override
  State<SpeciesProfileScreen> createState() => _SpeciesProfileScreenState();
}

class _ProfileLoad {
  const _ProfileLoad({
    required this.taxon,
    required this.taxonomy,
  });

  final PbdbTaxon taxon;
  final List<String> taxonomy;
}

class _SpeciesProfileScreenState extends State<SpeciesProfileScreen> {
  late Future<_ProfileLoad?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileLoad?> _load() async {
    final taxon = await widget.taxonRepository.findTaxon(widget.genus);
    if (taxon == null) return null;

    var taxonomy = <String>[];
    try {
      final chain =
          await widget.taxonRepository.getTimelineChain(widget.genus);
      taxonomy = TaxonFactMapper.taxonomyLabelsFromChain(chain);
    } catch (_) {
      taxonomy = const [];
    }
    return _ProfileLoad(taxon: taxon, taxonomy: taxonomy);
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StrataColors.cream,
      appBar: AppBar(
        title: Text(widget.genus),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<_ProfileLoad?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ProfileLoading();
          }
          if (snapshot.hasError) {
            return _ProfileError(
              message: '${snapshot.error}',
              onRetry: _retry,
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return _ProfileEmpty(
              genus: widget.genus,
              commonGroup: widget.commonGroup,
              family: widget.family,
              onRetry: _retry,
            );
          }
          return _ProfileBody(
            taxon: data.taxon,
            taxonomy: data.taxonomy,
            commonGroup: widget.commonGroup,
            family: widget.family,
          );
        },
      ),
    );
  }
}

class _DefaultTaxonRepo implements TaxonRepository {
  const _DefaultTaxonRepo();

  @override
  Future<PbdbTaxon?> findTaxon(String name) {
    return StrataServices.taxonRepository.findTaxon(name);
  }

  @override
  Future<List<PbdbTaxon>> getTimelineChain(String name) {
    return StrataServices.taxonRepository.getTimelineChain(name);
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: StrataColors.teal),
            const SizedBox(height: 20),
            Text(
              'Loading PBDB record…',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreBaskerville(
                color: StrataColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching name, rank, age range, and taxonomy.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: StrataColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: StrataColors.brown,
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load species profile.',
            textAlign: TextAlign.center,
            style: GoogleFonts.libreBaskerville(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: StrataColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: StrataColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          GradientCtaButton(
            label: 'Retry',
            showArrow: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ProfileEmpty extends StatelessWidget {
  const _ProfileEmpty({
    required this.genus,
    required this.onRetry,
    this.commonGroup,
    this.family,
  });

  final String genus;
  final String? commonGroup;
  final String? family;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            genus,
            style: GoogleFonts.libreBaskerville(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: StrataColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (commonGroup != null || family != null)
            Text(
              [
                ?commonGroup,
                if (family != null) 'Family $family',
              ].join(' · '),
              style: GoogleFonts.dmSans(
                color: StrataColors.muted,
                fontSize: 15,
              ),
            ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StrataRadii.card),
            ),
            child: Text(
              'No Paleobiology Database record was found for this name. '
              'You can still use the identification result, or retry the lookup.',
              style: GoogleFonts.dmSans(
                color: StrataColors.ink,
                height: 1.45,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          GradientCtaButton(
            label: 'Retry PBDB lookup',
            showArrow: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.taxon,
    required this.taxonomy,
    this.commonGroup,
    this.family,
  });

  final PbdbTaxon taxon;
  final List<String> taxonomy;
  final String? commonGroup;
  final String? family;

  String get _subtitle {
    final parts = <String>[
      _titleCase(taxon.rank),
      if (commonGroup != null && commonGroup!.isNotEmpty) commonGroup!,
      if (family != null && family!.isNotEmpty) 'Family $family',
    ];
    return parts.join(' · ');
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final occurrences = taxon.occurrenceCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(
          taxon.name,
          style: GoogleFonts.libreBaskerville(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: StrataColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _subtitle,
          style: GoogleFonts.dmSans(
            color: StrataColors.muted,
            fontSize: 15,
          ),
        ),
        if (taxon.attribution != null) ...[
          const SizedBox(height: 6),
          Text(
            taxon.attribution!,
            style: GoogleFonts.dmSans(
              color: StrataColors.muted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (taxonomy.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Taxonomy',
            style: GoogleFonts.dmSans(
              color: StrataColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              for (var i = 0; i < taxonomy.length; i++) ...[
                if (i > 0)
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: StrataColors.muted.withValues(alpha: 0.7),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(StrataRadii.pill),
                    border: Border.all(color: const Color(0xFFE0D6C8)),
                  ),
                  child: Text(
                    taxonomy[i],
                    style: GoogleFonts.dmSans(
                      color: StrataColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 24),
        _FactCard(
          icon: Icons.category_outlined,
          label: 'Taxonomic rank',
          value: _titleCase(taxon.rank),
        ),
        const SizedBox(height: 12),
        _FactCard(
          icon: Icons.timeline,
          label: 'Age range',
          value: taxon.ageRangeLabel,
        ),
        const SizedBox(height: 12),
        _FactCard(
          icon: Icons.public,
          label: 'PBDB occurrences',
          value: occurrences == null
              ? 'Unknown'
              : '$occurrences fossil ${occurrences == 1 ? 'occurrence' : 'occurrences'}',
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4F1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: StrataColors.teal.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            'PBDB record for this name — a double-check and fact source, '
            'not proof that the photo is this taxon.',
            style: GoogleFonts.dmSans(
              color: StrataColors.teal,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StrataRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: StrataColors.orange, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: StrataColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    color: StrataColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
