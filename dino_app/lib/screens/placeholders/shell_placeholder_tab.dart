import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/strata_theme.dart';

/// Tab body used for Map / Time / Museums until those features are built.
class ShellPlaceholderTab extends StatelessWidget {
  const ShellPlaceholderTab({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.libreBaskerville(
                color: StrataColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                color: StrataColors.muted,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const Spacer(),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: StrataColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 40, color: StrataColors.orange),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Coming soon',
                style: GoogleFonts.dmSans(
                  color: StrataColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
