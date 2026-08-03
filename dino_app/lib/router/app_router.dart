import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/placeholders/placeholder_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
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
        path: '/map',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Dig Map',
          subtitle: 'Public fossil sites — coming soon.',
        ),
      ),
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Deep Time',
          subtitle: 'Geological timeline — coming soon.',
        ),
      ),
      GoRoute(
        path: '/museums',
        builder: (context, state) => const PlaceholderScreen(
          title: 'Museums',
          subtitle: 'Exhibits near you — coming soon.',
        ),
      ),
      GoRoute(
        path: '/at-risk',
        builder: (context, state) => const PlaceholderScreen(
          title: 'At Risk',
          subtitle: 'Endangered species — coming soon.',
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
}
