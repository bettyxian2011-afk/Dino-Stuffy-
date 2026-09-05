import 'package:flutter/material.dart';

/// Disables Android's stretch/glow overscroll so lists don't distort at edges.
class StrataScrollBehavior extends MaterialScrollBehavior {
  const StrataScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Skip StretchingOverscrollIndicator / GlowingOverscrollIndicator.
    return child;
  }
}
