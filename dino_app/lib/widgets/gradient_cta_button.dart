import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/strata_theme.dart';

class GradientCtaButton extends StatelessWidget {
  const GradientCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(StrataRadii.button),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StrataRadii.button),
            gradient: const LinearGradient(
              colors: [StrataColors.orange, StrataColors.gold],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: StrataColors.orange.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
