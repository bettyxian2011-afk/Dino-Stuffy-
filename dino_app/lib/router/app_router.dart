import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/account_repository.dart';
import '../data/repositories/fossil_knowledge_repository.dart';
import '../data/repositories/period_repository.dart';
import '../models/captured_specimen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/account_screen.dart';
import '../screens/home/recent_matches_screen.dart';
import '../screens/id_result/id_result_screen.dart';
import '../screens/id_result/species_profile_screen.dart';
import '../screens/identify/identify_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/sign_in_screen.dart';
import '../screens/placeholders/placeholder_screen.dart';
import '../screens/placeholders/shell_placeholder_tab.dart';
import '../screens/shell/main_shell.dart';
import '../screens/timeline/period_detail_screen.dart';
import '../screens/timeline/timeline_screen.dart';
import '../screens/translate/translate_screen.dart';

GoRouter createAppRouter({
  AccountRepository? accountRepository,
  PeriodRepository? periodRepository,
  FossilKnowledgeRepository? knowledgeRepository,
}) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) =>
            SignInScreen(accountRepository: accountRepository),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) =>
            AccountScreen(accountRepository: accountRepository),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    HomeScreen(accountRepository: accountRepository),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const ShellPlaceholderTab(
                  title: 'Dig Map',
                  subtitle:
                      'Public fossil-hunting sites with permits, terrain '
                      'notes, and Camp Prep checklists.',
                  icon: Icons.public_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timeline',
                builder: (context, state) => TimelineScreen(
                  periodRepository: periodRepository,
                  knowledgeRepository: knowledgeRepository,
                ),
                routes: [
                  GoRoute(
                    path: ':periodId',
                    builder: (context, state) => PeriodDetailScreen(
                      periodId: state.pathParameters['periodId']!,
                      periodRepository: periodRepository,
                      knowledgeRepository: knowledgeRepository,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/museums',
                builder: (context, state) => const ShellPlaceholderTab(
                  title: 'Museums',
                  subtitle: 'Find exhibits and specimens on display near you.',
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/identify',
        builder: (context, state) => const IdentifyScreen(),
      ),
      GoRoute(
        path: '/id-result',
        builder: (context, state) {
          final captured = state.extra;
          if (captured is CapturedSpecimen) {
            return IdResultScreen(captured: captured);
          }
          final id = state.uri.queryParameters['id'] ?? 'dact-1';
          return IdResultScreen(specimenId: id);
        },
      ),
      GoRoute(
        path: '/species/:genus',
        builder: (context, state) {
          final genus = state.pathParameters['genus'] ?? 'Unknown';
          return SpeciesProfileScreen(
            genus: Uri.decodeComponent(genus),
            commonGroup: state.uri.queryParameters['group'],
            family: state.uri.queryParameters['family'],
          );
        },
      ),
      GoRoute(
        path: '/translate',
        builder: (context, state) => const TranslateScreen(),
      ),
      GoRoute(
        path: '/at-risk',
        builder: (context, state) => const PlaceholderScreen(
          title: 'At Risk',
          subtitle: 'Endangered species — coming soon.',
        ),
      ),
      GoRoute(
        path: '/recent',
        builder: (context, state) => const RecentMatchesScreen(),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Route not found: ${state.uri}'))),
  );
}
