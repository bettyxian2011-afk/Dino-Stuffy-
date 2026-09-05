import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/strata_services.dart';
import '../../data/repositories/identify_repository.dart';
import '../../models/captured_specimen.dart';
import '../../models/id_result.dart';
import '../../theme/strata_theme.dart';
import '../../widgets/confidence_pill.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/gradient_cta_button.dart';

class IdResultScreen extends StatefulWidget {
  const IdResultScreen({
    super.key,
    this.specimenId = 'dact-1',
    this.captured,
    IdentifyRepository? repository,
  }) : repository = repository ?? const _DefaultRepo();

  final String specimenId;
  final CapturedSpecimen? captured;
  final IdentifyRepository repository;

  @override
  State<IdResultScreen> createState() => _IdResultScreenState();
}

class _IdResultScreenState extends State<IdResultScreen> {
  late final Future<IdResult> _future = _loadResult();

  Future<IdResult> _loadResult() {
    final captured = widget.captured;
    if (captured != null) {
      return widget.repository.identify(captured.bytes);
    }
    return widget.repository.getMockResult(widget.specimenId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: StrataColors.cream,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: StrataColors.cream,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Could not identify this specimen.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: StrataColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return _IdResultBody(
          result: snapshot.data!,
          previewBytes: widget.captured?.bytes,
        );
      },
    );
  }
}

/// Resolves the shared identify repository initialized in [StrataServices].
class _DefaultRepo implements IdentifyRepository {
  const _DefaultRepo();

  @override
  Future<IdResult> getMockResult(String imageId) {
    return StrataServices.identifyRepository.getMockResult(imageId);
  }

  @override
  Future<IdResult> identify(Uint8List bytes) {
    return StrataServices.identifyRepository.identify(bytes);
  }
}

class _IdResultBody extends StatefulWidget {
  const _IdResultBody({
    required this.result,
    this.previewBytes,
  });

  final IdResult result;
  final Uint8List? previewBytes;

  @override
  State<_IdResultBody> createState() => _IdResultBodyState();
}

class _IdResultBodyState extends State<_IdResultBody> {
  bool _bookmarked = false;

  IdResult get result => widget.result;

  @override
  Widget build(BuildContext context) {
    final best = result.bestMatch;
    final alternatives = result.alternatives;

    return Scaffold(
      backgroundColor: StrataColors.cream,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 280,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _SpecimenHeaderImage(
                          previewBytes: widget.previewBytes,
                          assetPath: result.specimenImage,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x33000000),
                                Color(0x00000000),
                                Color(0xFFF7F4EF),
                              ],
                              stops: [0, 0.45, 1],
                            ),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                GlassIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  onPressed: () => context.pop(),
                                ),
                                const Spacer(),
                                GlassIconButton(
                                  icon: Icons.ios_share_rounded,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Transform.translate(
                        offset: const Offset(0, -36),
                        child: _BestMatchCard(
                          result: result,
                          best: best,
                        ),
                      ),
                      Text(
                        'If not — most likely alternatives',
                        style: GoogleFonts.dmSans(
                          color: StrataColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final alt in alternatives) ...[
                        _AlternativeCard(candidate: alt),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                      if (result.timelineLabel != null) ...[
                        _TimelineCard(label: result.timelineLabel!),
                        const SizedBox(height: 16),
                      ],
                      _TipCallout(tip: result.tip),
                      const SizedBox(height: 16),
                      _TaxonomyRow(taxonomy: result.taxonomy),
                      const SizedBox(height: 16),
                      _FactsRow(facts: result.facts),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GradientCtaButton(
                              label: 'View full profile',
                              showArrow: false,
                              onPressed: () => context.push(
                                '/species/${Uri.encodeComponent(best.genus)}'
                                '?group=${Uri.encodeComponent(best.commonGroup)}'
                                '&family=${Uri.encodeComponent(best.family)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 1,
                            shadowColor: Colors.black26,
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _bookmarked = !_bookmarked),
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(
                                  _bookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: StrataColors.brown,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]),
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

class _SpecimenHeaderImage extends StatelessWidget {
  const _SpecimenHeaderImage({
    required this.previewBytes,
    required this.assetPath,
  });

  final Uint8List? previewBytes;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    if (previewBytes != null) {
      return Image.memory(
        previewBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Container(color: const Color(0xFFD9CBB8)),
      );
    }
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(color: const Color(0xFFD9CBB8)),
    );
  }
}

class _BestMatchCard extends StatelessWidget {
  const _BestMatchCard({
    required this.result,
    required this.best,
  });

  final IdResult result;
  final IdCandidate best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StrataRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ConfidencePill(
                label: result.confidenceLabel,
                color: StrataColors.confidence,
              ),
              if (result.pbdbVerified) ...[
                const SizedBox(width: 8),
                _PbdbBadge(),
              ],
              const Spacer(),
              Text(
                '${result.candidates.length} candidates',
                style: GoogleFonts.dmSans(
                  color: StrataColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.matchLabel,
            style: GoogleFonts.dmSans(
              color: StrataColors.muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            best.genus,
            style: GoogleFonts.libreBaskerville(
              color: StrataColors.ink,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            best.classificationLabel,
            style: GoogleFonts.dmSans(
              color: StrataColors.muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Adjusted confidence',
                style: GoogleFonts.dmSans(
                  color: StrataColors.muted,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '${best.confidence}%',
                style: GoogleFonts.dmSans(
                  color: StrataColors.confidence,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (best.modelConfidence != null) ...[
            const SizedBox(height: 4),
            Text(
              'Raw AI score ${best.modelConfidence}% · boosted when PBDB/catalog agree',
              style: GoogleFonts.dmSans(
                color: StrataColors.muted,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(StrataRadii.pill),
            child: LinearProgressIndicator(
              value: best.confidence / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8DFD4),
              color: StrataColors.confidence,
            ),
          ),
        ],
      ),
    );
  }
}

class _PbdbBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4F1),
        borderRadius: BorderRadius.circular(StrataRadii.pill),
        border: Border.all(color: StrataColors.teal.withValues(alpha: 0.35)),
      ),
      child: Text(
        'PBDB',
        style: GoogleFonts.dmSans(
          color: StrataColors.teal,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D6C8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timeline, color: StrataColors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deep Time range',
                  style: GoogleFonts.dmSans(
                    color: StrataColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.libreBaskerville(
                    color: StrataColors.ink,
                    fontSize: 18,
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

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({required this.candidate});

  final IdCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              candidate.thumbnail,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 48,
                height: 48,
                color: const Color(0xFFE8DFD4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.genus,
                  style: GoogleFonts.libreBaskerville(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: StrataColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(StrataRadii.pill),
                        child: LinearProgressIndicator(
                          value: candidate.confidence / 100,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE8DFD4),
                          color: StrataColors.brown,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${candidate.confidence}%',
                      style: GoogleFonts.dmSans(
                        color: StrataColors.brown,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCallout extends StatelessWidget {
  const _TipCallout({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8C98A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: StrataColors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF5C3A22),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxonomyRow extends StatelessWidget {
  const _TaxonomyRow({required this.taxonomy});

  final List<String> taxonomy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }
}

class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.facts});

  final List<TaxonFact> facts;

  IconData _iconFor(String key) {
    return switch (key) {
      'schedule' => Icons.schedule,
      'straighten' => Icons.straighten,
      'public' => Icons.public,
      _ => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _iconFor(facts[i].icon),
                    color: StrataColors.orange,
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    facts[i].value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: StrataColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    facts[i].label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: StrataColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
