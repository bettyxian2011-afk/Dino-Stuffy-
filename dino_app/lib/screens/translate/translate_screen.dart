import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/translate_repository.dart';
import '../../models/translate.dart';
import '../../theme/strata_theme.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({
    super.key,
    this.repository = const MockTranslateRepository(),
  });

  final TranslateRepository repository;

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  late String _sourceLang;
  late String _targetLang;
  late final TextEditingController _sourceController;
  TranslateResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    final first = widget.repository.getSamplePairs().first;
    _sourceLang = first.sourceLang;
    _targetLang = first.targetLang;
    _sourceController = TextEditingController(text: first.sourceText);
  }

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  void _swapLanguages() {
    setState(() {
      final previousSource = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = previousSource;
      if (_result != null) {
        final previousText = _sourceController.text;
        _sourceController.text = _result!.translatedText;
        _result = TranslateResult(
          translatedText: previousText,
          highlights: const [],
          glossary: _result!.glossary,
        );
      }
      _error = null;
    });
  }

  void _runTranslate() {
    final request = TranslateRequest(
      sourceText: _sourceController.text,
      sourceLang: _sourceLang,
      targetLang: _targetLang,
    );
    final result = widget.repository.translate(request);
    setState(() {
      if (result == null) {
        _result = null;
        _error =
            'No paleo-tuned match for this sample yet. Try a canned abstract.';
      } else {
        _result = result;
        _error = null;
      }
    });
  }

  Future<void> _copyTranslation() async {
    final text = _result?.translatedText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Translation copied',
          style: GoogleFonts.dmSans(),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _loadSample(TranslatePair pair) {
    setState(() {
      _sourceLang = pair.sourceLang;
      _targetLang = pair.targetLang;
      _sourceController.text = pair.sourceText;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final samples = widget.repository.getSamplePairs();

    return Scaffold(
      backgroundColor: StrataColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (context.canPop())
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: StrataColors.ink,
                  ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: StrataColors.teal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paleo Translate',
                        style: GoogleFonts.libreBaskerville(
                          color: StrataColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tuned on 2.4M paleontology papers — keeps taxa, '
                        'ranks & units intact.',
                        style: GoogleFonts.dmSans(
                          color: StrataColors.muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.history),
                  color: StrataColors.muted,
                  tooltip: 'History',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _LanguageCard(
              sourceLang: _sourceLang,
              targetLang: _targetLang,
              onSwap: _swapLanguages,
            ),
            const SizedBox(height: 14),
            _SourceCard(controller: _sourceController),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _runTranslate,
                style: FilledButton.styleFrom(
                  backgroundColor: StrataColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  'Translate (Paleo mode)',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFB45309),
                  fontSize: 13,
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 18),
              _TranslationCard(
                result: _result!,
                onCopy: _copyTranslation,
                onSpeak: () {},
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: StrataColors.teal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: StrataColors.teal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Technical terms explained',
                    style: GoogleFonts.libreBaskerville(
                      color: StrataColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final term in _result!.glossary) ...[
                _GlossaryCard(term: term),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 20),
            Text(
              'Sample abstracts',
              style: GoogleFonts.dmSans(
                color: StrataColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pair in samples)
                  ActionChip(
                    label: Text('${pair.sourceLang} → ${pair.targetLang}'),
                    onPressed: () => _loadSample(pair),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE0D6C8)),
                    labelStyle: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: StrataColors.ink,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.sourceLang,
    required this.targetLang,
    required this.onSwap,
  });

  final String sourceLang;
  final String targetLang;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StrataRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DETECTED',
                  style: GoogleFonts.dmSans(
                    color: StrataColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sourceLang,
                  style: GoogleFonts.dmSans(
                    color: StrataColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: StrataColors.teal.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSwap,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: StrataColors.teal,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TO',
                  style: GoogleFonts.dmSans(
                    color: StrataColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  targetLang,
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

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StrataRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Text(
                'SOURCE • ABSTRACT',
                style: GoogleFonts.dmSans(
                  color: StrataColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.mic_none_rounded,
                color: StrataColors.muted.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 5,
            minLines: 3,
            style: GoogleFonts.dmSans(
              color: StrataColors.ink,
              fontSize: 15,
              height: 1.45,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslationCard extends StatelessWidget {
  const _TranslationCard({
    required this.result,
    required this.onCopy,
    required this.onSpeak,
  });

  final TranslateResult result;
  final VoidCallback onCopy;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StrataRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Icon(
                Icons.check_circle,
                color: StrataColors.teal,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'TRANSLATION',
                style: GoogleFonts.dmSans(
                  color: StrataColors.teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 20),
                color: StrataColors.muted,
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onSpeak,
                icon: const Icon(Icons.volume_up_outlined, size: 20),
                color: StrataColors.muted,
                tooltip: 'Speak',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _HighlightedTranslation(
            text: result.translatedText,
            highlights: result.highlights,
          ),
        ],
      ),
    );
  }
}

class _HighlightedTranslation extends StatelessWidget {
  const _HighlightedTranslation({
    required this.text,
    required this.highlights,
  });

  final String text;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.dmSans(
      color: StrataColors.ink,
      fontSize: 15,
      height: 1.5,
    );
    final highlightStyle = baseStyle.copyWith(
      backgroundColor: StrataColors.teal.withValues(alpha: 0.16),
      color: const Color(0xFF0F6B5C),
      fontWeight: FontWeight.w600,
    );

    final spans = <InlineSpan>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      var earliest = remaining.length;
      String? hit;

      for (final h in highlights) {
        final idx = remaining.toLowerCase().indexOf(h.toLowerCase());
        if (idx >= 0 && idx < earliest) {
          earliest = idx;
          hit = remaining.substring(idx, idx + h.length);
        }
      }

      if (hit == null) {
        spans.addAll(_withItalicTaxa(remaining, baseStyle));
        break;
      }

      if (earliest > 0) {
        spans.addAll(
          _withItalicTaxa(remaining.substring(0, earliest), baseStyle),
        );
      }
      spans.add(TextSpan(text: hit, style: highlightStyle));
      remaining = remaining.substring(earliest + hit.length);
    }

    return Text.rich(TextSpan(children: spans));
  }

  List<InlineSpan> _withItalicTaxa(String chunk, TextStyle style) {
    const taxon = 'Velociraptor';
    final spans = <InlineSpan>[];
    var rest = chunk;
    while (rest.isNotEmpty) {
      final idx = rest.indexOf(taxon);
      if (idx < 0) {
        spans.add(TextSpan(text: rest, style: style));
        break;
      }
      if (idx > 0) {
        spans.add(TextSpan(text: rest.substring(0, idx), style: style));
      }
      spans.add(
        TextSpan(
          text: taxon,
          style: style.copyWith(fontStyle: FontStyle.italic),
        ),
      );
      rest = rest.substring(idx + taxon.length);
    }
    return spans;
  }
}

class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard({required this.term});

  final GlossaryTerm term;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  term.term,
                  style: GoogleFonts.dmSans(
                    color: StrataColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBE3),
                  borderRadius: BorderRadius.circular(StrataRadii.pill),
                ),
                child: Text(
                  term.tag,
                  style: GoogleFonts.dmSans(
                    color: StrataColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            term.definition,
            style: GoogleFonts.dmSans(
              color: StrataColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
