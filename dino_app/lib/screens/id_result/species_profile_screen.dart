import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/strata_theme.dart';

/// Stub species profile until deeper taxon content is built.
class SpeciesProfileScreen extends StatelessWidget {
  const SpeciesProfileScreen({
    super.key,
    required this.genus,
    this.commonGroup,
    this.family,
  });

  final String genus;
  final String? commonGroup;
  final String? family;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StrataColors.cream,
      appBar: AppBar(
        title: Text(genus),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
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
                'Full species profile content — formation notes, '
                'museum exhibits, and related taxa — will land in a '
                'later iteration. For now this stub confirms navigation '
                'from ID Result.',
                style: GoogleFonts.dmSans(
                  color: StrataColors.ink,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
