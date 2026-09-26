import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/strata_services.dart';
import '../../data/repositories/identify_repository.dart';
import '../../data/services/identification_heuristics.dart';
import '../../data/services/identify_refine_copy.dart';
import '../../data/services/rock_lithology.dart';
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
  late Future<IdResult> _future;
  String? _userNotes;

  @override
  void initState() {
    super.initState();
    _future = _loadResult();
  }

  Future<IdResult> _loadResult({String? userNotes}) {
    final notes = userNotes ?? _userNotes;
    final captured = widget.captured;
    if (captured != null) {
      return widget.repository.identify(captured.bytes, userNotes: notes);
    }
    return widget.repository.getMockResult(widget.specimenId);
  }

  void _retry() {
    setState(() {
      _future = _loadResult();
    });
  }

  void _reIdentifyWithNotes(String notes) {
    final trimmed = notes.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _userNotes = trimmed;
      _future = _loadResult(userNotes: trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: StrataColors.cream,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: StrataColors.teal),
                    const SizedBox(height: 20),
                    Text(
                      'Identifying specimen…',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.libreBaskerville(
                        color: StrataColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Matching your photo against curated genera'
                      '${widget.captured != null ? ' and live vision' : ''}.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: StrataColors.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
              title: const Text('Identification'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: StrataColors.brown,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Could not identify this specimen.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.libreBaskerville(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: StrataColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    snapshot.hasError
                        ? '${snapshot.error}'
                        : 'No match data was returned. Check your connection and try again.',
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
                    onPressed: _retry,
                  ),
                ],
              ),
            ),
          );
        }
        return _IdResultBody(
          result: snapshot.data!,
          previewBytes: widget.captured?.bytes,
          initialNotes: _userNotes,
          onReIdentify: widget.captured != null ? _reIdentifyWithNotes : null,
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
  Future<IdResult> identify(Uint8List bytes, {String? userNotes}) {
    return StrataServices.identifyRepository.identify(
      bytes,
      userNotes: userNotes,
    );
  }
}

class _IdResultBody extends StatefulWidget {
  const _IdResultBody({
    required this.result,
    this.previewBytes,
    this.initialNotes,
    this.onReIdentify,
  });

  final IdResult result;
  final Uint8List? previewBytes;
  final String? initialNotes;
  final void Function(String notes)? onReIdentify;

  @override
  State<_IdResultBody> createState() => _IdResultBodyState();
}

class _IdResultBodyState extends State<_IdResultBody> {
  bool _bookmarked = false;

  IdResult get result => widget.result;

  @override
  Widget build(BuildContext context) {
    // Rock-only path (no genera).
    if (result.isRockAssessment) {
      return _NonFossilResultBody(
        result: result,
        previewBytes: widget.previewBytes,
        initialNotes: widget.initialNotes,
        onReIdentify: widget.onReIdentify,
      );
    }
    // Uncertain with no provisional genera — photo tip only.
    if (result.isUncertain && result.candidates.isEmpty) {
      return _NonFossilResultBody(
        result: result,
        previewBytes: widget.previewBytes,
        initialNotes: widget.initialNotes,
        onReIdentify: widget.onReIdentify,
      );
    }

    final best = result.bestMatch;
    final alternatives = result.alternatives;
    final showProfileCta = result.isFossilMatch || result.isUncertain;

    return Scaffold(
      backgroundColor: StrataColors.cream,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
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
                                  onPressed: () {
                                    if (context.mounted &&
                                        Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }
                                  },
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (result.isUncertain) ...[
                          Transform.translate(
                            offset: const Offset(0, -36),
                            child: _PhotoQualityCallout(
                              reason: result.reason ?? result.tip,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Transform.translate(
                          offset: Offset(0, result.isUncertain ? 0 : -36),
                          child: _BestMatchCard(
                            result: result,
                            best: best,
                          ),
                        ),
                        if (alternatives.isNotEmpty) ...[
                          Text(
                            result.isUncertain
                                ? 'Other provisional possibilities'
                                : 'If not — most likely alternatives',
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
                        ],
                        if (result.timelineLabel != null) ...[
                          _TimelineCard(label: result.timelineLabel!),
                          const SizedBox(height: 16),
                        ],
                        if (!result.isUncertain) ...[
                          _TipCallout(tip: result.tip),
                          const SizedBox(height: 16),
                        ],
                        if (result.taxonomy.isNotEmpty) ...[
                          _TaxonomyRow(taxonomy: result.taxonomy),
                          const SizedBox(height: 16),
                        ],
                        if (result.facts.isNotEmpty) ...[
                          _FactsRow(facts: result.facts),
                          const SizedBox(height: 20),
                        ],
                        if (result.needsMoreInfo &&
                            widget.onReIdentify != null) ...[
                          _RefineWithNotesPanel(
                            isRock: result.isRockAssessment,
                            initialNotes: widget.initialNotes,
                            onSubmit: widget.onReIdentify!,
                          ),
                          const SizedBox(height: 20),
                        ],
                        Row(
                          children: [
                            if (showProfileCta)
                              Expanded(
                                child: GradientCtaButton(
                                  label: result.isUncertain
                                      ? 'View provisional profile'
                                      : 'View full profile',
                                  showArrow: false,
                                  onPressed: () => context.push(
                                    '/species/${Uri.encodeComponent(best.genus)}'
                                    '?group=${Uri.encodeComponent(best.commonGroup)}'
                                    '&family=${Uri.encodeComponent(best.family)}',
                                  ),
                                ),
                              ),
                            if (showProfileCta) const SizedBox(width: 12),
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 1,
                              shadowColor: Colors.black26,
                              child: InkWell(
                                onTap: () => setState(
                                  () => _bookmarked = !_bookmarked,
                                ),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoQualityCallout extends StatelessWidget {
  const _PhotoQualityCallout({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(StrataRadii.card),
        border: Border.all(color: const Color(0xFFE8C98A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined,
                  color: StrataColors.orange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Clearer photo needed',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF5C3A22),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: GoogleFonts.dmSans(
              color: const Color(0xFF5C3A22),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'What can go wrong: blur, glare, or rock texture can look like a '
            'fossil and produce a wrong genus. The match below is the highest '
            'provisional score — treat it as a guess until you retake.',
            style: GoogleFonts.dmSans(
              color: StrataColors.brown,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NonFossilResultBody extends StatelessWidget {
  const _NonFossilResultBody({
    required this.result,
    this.previewBytes,
    this.initialNotes,
    this.onReIdentify,
  });

  final IdResult result;
  final Uint8List? previewBytes;
  final String? initialNotes;
  final void Function(String notes)? onReIdentify;

  @override
  Widget build(BuildContext context) {
    final isRock = result.isRockAssessment;
    final title = isRock
        ? RockLithology.displayName(result.rockType)
        : 'Uncertain';
    final headline = isRock ? 'May not be a fossil' : result.matchLabel;

    return Scaffold(
      backgroundColor: StrataColors.cream,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SpecimenHeaderImage(
                  previewBytes: previewBytes,
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
                          onPressed: () {
                            if (context.mounted && Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
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
                    ConfidencePill(
                      label: result.confidenceLabel,
                      color: isRock ? StrataColors.brown : StrataColors.orange,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      headline,
                      style: GoogleFonts.dmSans(
                        color: StrataColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.libreBaskerville(
                        color: StrataColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isRock) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Lithology / material estimate — not a species ID',
                        style: GoogleFonts.dmSans(
                          color: StrataColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TipCallout(tip: result.tip),
                if (result.facts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _FactsRow(facts: result.facts),
                ],
                if (result.needsMoreInfo && onReIdentify != null) ...[
                  const SizedBox(height: 20),
                  _RefineWithNotesPanel(
                    isRock: result.isRockAssessment,
                    initialNotes: initialNotes,
                    onSubmit: onReIdentify!,
                  ),
                ],
                const SizedBox(height: 24),
                GradientCtaButton(
                  label: 'Try another photo',
                  showArrow: false,
                  onPressed: () {
                    if (context.mounted && Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefineWithNotesPanel extends StatefulWidget {
  const _RefineWithNotesPanel({
    required this.onSubmit,
    this.initialNotes,
    this.isRock = false,
  });

  final String? initialNotes;
  final void Function(String notes) onSubmit;
  final bool isRock;

  @override
  State<_RefineWithNotesPanel> createState() => _RefineWithNotesPanelState();
}

class _RefineWithNotesPanelState extends State<_RefineWithNotesPanel> {
  late final TextEditingController _controller;
  RefineExample? _expanded;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertExample(RefineExample example) {
    final current = _controller.text.trim();
    final next = current.isEmpty
        ? example.sentence
        : '$current ${example.sentence}';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() => _expanded = example);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StrataRadii.card),
        border: Border.all(color: const Color(0xFFE8C98A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  color: StrataColors.orange, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  IdentifyRefineCopy.titleFor(isRock: widget.isRock),
                  style: GoogleFonts.dmSans(
                    color: StrataColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            IdentifyRefineCopy.subtitleFor(isRock: widget.isRock),
            style: GoogleFonts.dmSans(
              color: StrataColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tap an example to add it (terms explained for beginners):',
            style: GoogleFonts.dmSans(
              color: StrataColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          for (final example in IdentifyRefineCopy.examples) ...[
            InkWell(
              onTap: () => _insertExample(example),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8DFD4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      example.sentence,
                      style: GoogleFonts.dmSans(
                        color: StrataColors.ink,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${example.term}: ${example.definition}',
                      style: GoogleFonts.dmSans(
                        color: StrataColors.brown,
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: IdentifyRefineCopy.fieldHint,
              hintStyle: GoogleFonts.dmSans(
                color: StrataColors.muted,
                fontSize: 13,
              ),
              filled: true,
              fillColor: StrataColors.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0D6C8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0D6C8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: StrataColors.teal, width: 1.5),
              ),
            ),
            style: GoogleFonts.dmSans(
              color: StrataColors.ink,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (_expanded != null) ...[
            const SizedBox(height: 8),
            Text(
              'Using “${_expanded!.term}” — ${_expanded!.definition}',
              style: GoogleFonts.dmSans(
                color: StrataColors.teal,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          GradientCtaButton(
            label: 'Re-identify with my notes',
            showArrow: false,
            onPressed: () => widget.onSubmit(_controller.text),
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
              best.modelConfidence! < IdentificationHeuristics.boostFloor
                  ? 'Raw AI score ${best.modelConfidence}% · no catalog/PBDB boost below ${IdentificationHeuristics.boostFloor}%'
                  : 'Raw AI score ${best.modelConfidence}% · soft boost only when ≥${IdentificationHeuristics.boostFloor}% and corroborated',
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
