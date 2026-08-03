import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/strata_theme.dart';

/// Temporary home until Iteration 2 builds the full shell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StrataColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, Betty',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Home shell arrives in Iteration 2.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: StrataColors.muted,
                    ),
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/onboarding'),
                  child: const Text('Back to onboarding'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
