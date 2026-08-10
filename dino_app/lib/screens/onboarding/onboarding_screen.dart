import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/strata_theme.dart';
import '../../widgets/gradient_cta_button.dart';
import '../../widgets/strata_logo.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0E08),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Zoom out + shift down so the dinosaur head stays in frame
          ClipRect(
            child: Transform.translate(
              offset: const Offset(0, 72),
              child: Transform.scale(
                scale: 0.98,
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/images/onboarding_hero.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.45),
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFE8913A),
                          Color(0xFF5C2E12),
                          Color(0xFF1A0E08),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Top vignette + bottom readability scrub
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x99000000),
                  Color(0xE6000000),
                ],
                stops: [0.0, 0.28, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: StrataLogo()),
                  const Spacer(flex: 3),
                  _CompanionBadge(),
                  const SizedBox(height: 16),
                  Text(
                    'Read the record\nof life on Earth.',
                    style: GoogleFonts.libreBaskerville(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Identify any fossil from a photo, decode the '
                    'literature, and find where to dig — and where '
                    "it's on display.",
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _FeatureChips(),
                  const SizedBox(height: 28),
                  GradientCtaButton(
                    label: 'Get Started',
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: StrataColors.glass,
          borderRadius: BorderRadius.circular(StrataRadii.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: StrataColors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'THE PALEONTOLOGY FIELD COMPANION',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChips extends StatelessWidget {
  const _FeatureChips();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FeatureChip(
            icon: Icons.photo_camera_outlined,
            label: 'Identify',
            onTap: () => context.push('/identify'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FeatureChip(
            icon: Icons.public_outlined,
            label: 'Dig Map',
            onTap: () => context.go('/map'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FeatureChip(
            icon: Icons.history_outlined,
            label: 'Deep Time',
            onTap: () => context.go('/timeline'),
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StrataColors.glass,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
