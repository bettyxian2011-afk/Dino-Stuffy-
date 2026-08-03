import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/strata_theme.dart';

class ConfidencePill extends StatelessWidget {
  const ConfidencePill({
    super.key,
    required this.label,
    this.color = StrataColors.confidence,
    this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(StrataRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
