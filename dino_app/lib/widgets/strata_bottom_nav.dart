import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/strata_theme.dart';

enum ShellTab { home, map, timeline, museums }

class StrataBottomNav extends StatelessWidget {
  const StrataBottomNav({
    super.key,
    required this.active,
    required this.onSelect,
    required this.onScan,
  });

  final ShellTab active;
  final ValueChanged<ShellTab> onSelect;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: active == ShellTab.home,
                onTap: () => onSelect(ShellTab.home),
              ),
              _NavItem(
                icon: Icons.public_outlined,
                label: 'Map',
                selected: active == ShellTab.map,
                onTap: () => onSelect(ShellTab.map),
              ),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: Material(
                      color: StrataColors.orange,
                      borderRadius: BorderRadius.circular(18),
                      elevation: 6,
                      shadowColor: StrataColors.orange.withValues(alpha: 0.45),
                      child: InkWell(
                        onTap: onScan,
                        borderRadius: BorderRadius.circular(18),
                        child: const SizedBox(
                          width: 58,
                          height: 58,
                          child: Icon(
                            Icons.photo_camera,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.history,
                label: 'Time',
                selected: active == ShellTab.timeline,
                onTap: () => onSelect(ShellTab.timeline),
              ),
              _NavItem(
                icon: Icons.account_balance_outlined,
                label: 'Museums',
                selected: active == ShellTab.museums,
                onTap: () => onSelect(ShellTab.museums),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? StrataColors.orange : StrataColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
