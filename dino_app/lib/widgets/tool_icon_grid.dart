import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/strata_theme.dart';

class ToolItem {
  const ToolItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class ToolIconGrid extends StatelessWidget {
  const ToolIconGrid({super.key, required this.items});

  final List<ToolItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _ToolButton(item: items[i])),
        ],
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.item});

  final ToolItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: item.color,
          borderRadius: BorderRadius.circular(StrataRadii.icon),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(StrataRadii.icon),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Icon(item.icon, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: StrataColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
