import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/fossil_repository.dart';
import '../../theme/strata_theme.dart';
import '../../widgets/recent_match_card.dart';

class RecentMatchesScreen extends StatelessWidget {
  const RecentMatchesScreen({
    super.key,
    this.fossilRepository = const MockFossilRepository(),
  });

  final FossilRepository fossilRepository;

  @override
  Widget build(BuildContext context) {
    final matches = fossilRepository.getRecentMatches();

    return Scaffold(
      backgroundColor: StrataColors.cream,
      appBar: AppBar(
        title: const Text('Recently identified'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: matches.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final match = matches[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecentMatchCard(
                match: match,
                onTap: () => context.push('/id-result?id=${match.id}'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.speciesName,
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: StrataColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        match.eraLabel,
                        style: GoogleFonts.dmSans(
                          color: StrataColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${match.confidence}% model confidence',
                        style: GoogleFonts.dmSans(
                          color: StrataColors.confidence,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
