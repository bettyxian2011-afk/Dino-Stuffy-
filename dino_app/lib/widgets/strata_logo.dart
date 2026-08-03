import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/strata_theme.dart';

/// Orange strata mark + wordmark.
class StrataLogo extends StatelessWidget {
  const StrataLogo({
    super.key,
    this.compact = false,
    this.color = Colors.white,
  });

  final bool compact;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 28.0 : 32.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            color: StrataColors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (_) => Container(
                height: 2.5,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Strata',
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: compact ? 20 : 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
