import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/geological_site.dart';
import '../theme/strata_theme.dart';

class NearYouCard extends StatelessWidget {
  const NearYouCard({
    super.key,
    required this.site,
    this.onTap,
  });

  final GeologicalSite site;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StrataRadii.card),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StrataRadii.card),
          child: SizedBox(
            height: 148,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  site.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B6A45), Color(0xFF4A3220)],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.diamond_outlined,
                            color: StrataColors.gold,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'NEAR YOU',
                            style: GoogleFonts.dmSans(
                              color: StrataColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        site.headline,
                        style: GoogleFonts.libreBaskerville(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        site.detailLabel,
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
