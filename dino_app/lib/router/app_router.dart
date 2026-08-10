import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/home/recent_matches_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/placeholders/placeholder_screen.dart';
import '../screens/placeholders/shell_placeholder_tab.dart';
import '../screens/shell/main_shell.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
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
                builder: (context, state) => const HomeScreen(),
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
                builder: (context, state) => const ShellPlaceholderTab(
                  title: 'Deep Time',
                  subtitle:
                      'Geological eras from Cambrian to Holocene with '
                      'iconic species per period.',
                  icon: Icons.history,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/museums',
                builder: (context, state) => const ShellPlaceholderTab(
                  title: 'Museums',
                  subtitle:
                      'Find exhibits and specimens on display near you.',
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/identify',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Identify',
          subtitle: 'Camera identify arrives in Iteration 3.',
        ),
      ),
      GoRoute(
        path: '/id-result',
        builder: (context, state) => const PlaceholderScreen(
          title: 'ID Result',
          subtitle: 'Identification results arrive in Iteration 4.',
        ),
      ),
      GoRoute(
        path: '/translate',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Paleo Translate',
          subtitle: 'Translate arrives in Iteration 5.',
        ),
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
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
}
