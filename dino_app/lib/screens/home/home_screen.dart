import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/fossil_repository.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/site_repository.dart';
import '../../data/strata_services.dart';
import '../../models/user_profile.dart';
import '../../theme/strata_theme.dart';
import '../../widgets/gradient_hero_card.dart';
import '../../widgets/near_you_card.dart';
import '../../widgets/recent_match_card.dart';
import '../../widgets/tool_icon_grid.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.fossilRepository = const MockFossilRepository(),
    this.siteRepository = const MockSiteRepository(),
    this.accountRepository,
  });

  final FossilRepository fossilRepository;
  final SiteRepository siteRepository;
  final AccountRepository? accountRepository;

  String _greeting(String displayName) {
    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return displayName.isEmpty ? salutation : '$salutation, $displayName';
  }

  @override
  Widget build(BuildContext context) {
    final recent = fossilRepository.getRecentMatches();
    final nearYou = siteRepository.getNearYou();
    final accounts = accountRepository ?? StrataServices.accountRepository;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<UserProfile?>(
                stream: accounts.watchProfile(),
                builder: (context, snapshot) {
                  final name = snapshot.data?.displayName.trim() ?? '';
                  final avatar = name.isEmpty ? 'S' : name[0].toUpperCase();
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          _greeting(name),
                          style: GoogleFonts.libreBaskerville(
                            color: StrataColors.ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Account',
                        onPressed: () => context.push(
                          snapshot.data == null ? '/sign-in' : '/account',
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: _Avatar(
                          initial: avatar,
                          photoUrl: snapshot.data?.photoUrl,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: GradientHeroCard(
                onScanNow: () => context.push('/identify'),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: ToolIconGrid(
                items: [
                  ToolItem(
                    label: 'Translate',
                    icon: Icons.translate_rounded,
                    color: StrataColors.teal,
                    onTap: () => context.push('/translate'),
                  ),
                  ToolItem(
                    label: 'Dig Map',
                    icon: Icons.public_outlined,
                    color: StrataColors.brown,
                    onTap: () => context.go('/map'),
                  ),
                  ToolItem(
                    label: 'Deep Time',
                    icon: Icons.history,
                    color: const Color(0xFF7B5EA7),
                    onTap: () => context.go('/timeline'),
                  ),
                  ToolItem(
                    label: 'At Risk',
                    icon: Icons.pets_outlined,
                    color: const Color(0xFFD94F3D),
                    onTap: () => context.push('/at-risk'),
                  ),
                  ToolItem(
                    label: 'Museums',
                    icon: Icons.account_balance_outlined,
                    color: const Color(0xFF3D6FBF),
                    onTap: () => context.go('/museums'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recently identified',
                      style: GoogleFonts.dmSans(
                        color: StrataColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/recent'),
                    style: TextButton.styleFrom(
                      foregroundColor: StrataColors.orange,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'See all',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (recent.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 210,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final match = recent[index];
                    return RecentMatchCard(
                      match: match,
                      onTap: () => context.push('/id-result?id=${match.id}'),
                    );
                  },
                ),
              ),
            ),
          if (nearYou != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              sliver: SliverToBoxAdapter(
                child: NearYouCard(
                  site: nearYou,
                  onTap: () => context.go('/map'),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, this.photoUrl});

  final String initial;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFE8DFD4),
      child: photoUrl == null
          ? _initialText()
          : ClipOval(
              child: Image.network(
                photoUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initialText(),
              ),
            ),
    );
  }

  Widget _initialText() => Text(
    initial,
    style: GoogleFonts.dmSans(
      color: StrataColors.brown,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
  );
}
