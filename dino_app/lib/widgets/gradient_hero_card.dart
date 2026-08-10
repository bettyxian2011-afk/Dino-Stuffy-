import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/strata_theme.dart';

class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.onScanNow,
  });

  final VoidCallback onScanNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StrataRadii.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2A04A),
            Color(0xFFE07A2F),
            Color(0xFFC45E22),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: StrataColors.orange.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(StrataRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  'AI IDENTIFY',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Found a fossil?',
            style: GoogleFonts.libreBaskerville(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Point your camera — get a ranked, confidence-scored '
            'species match in seconds.',
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(StrataRadii.pill),
            child: InkWell(
              onTap: onScanNow,
              borderRadius: BorderRadius.circular(StrataRadii.pill),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_camera,
                      color: StrataColors.brown,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Scan now',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF5C3A22),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
