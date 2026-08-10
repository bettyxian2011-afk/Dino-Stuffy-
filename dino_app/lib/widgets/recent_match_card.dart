import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/fossil_match.dart';
import '../theme/strata_theme.dart';

class RecentMatchCard extends StatelessWidget {
  const RecentMatchCard({
    super.key,
    required this.match,
    this.onTap,
  });

  final FossilMatch match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        match.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFFE8DFD4),
                          child: const Icon(
                            Icons.image_outlined,
                            color: StrataColors.muted,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius:
                                BorderRadius.circular(StrataRadii.pill),
                          ),
                          child: Text(
                            match.matchLabel,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                match.speciesName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.libreBaskerville(
                  color: StrataColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                match.eraLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: StrataColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
