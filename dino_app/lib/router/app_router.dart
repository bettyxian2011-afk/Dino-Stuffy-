import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/captured_specimen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/recent_matches_screen.dart';
import '../screens/id_result/id_result_screen.dart';
import '../screens/id_result/species_profile_screen.dart';
import '../screens/identify/identify_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/placeholders/placeholder_screen.dart';
import '../screens/placeholders/shell_placeholder_tab.dart';
import '../screens/shell/main_shell.dart';
import '../screens/translate/translate_screen.dart';

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
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
}
