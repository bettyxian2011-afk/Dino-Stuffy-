import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/strata_theme.dart';
import '../../widgets/strata_bottom_nav.dart';

/// Hosts Home / Map / Time / Museums with persistent bottom navigation.
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  ShellTab get _active {
    switch (navigationShell.currentIndex) {
      case 1:
        return ShellTab.map;
      case 2:
        return ShellTab.timeline;
      case 3:
        return ShellTab.museums;
      default:
        return ShellTab.home;
    }
  }

  void _onSelect(ShellTab tab) {
    final index = switch (tab) {
      ShellTab.home => 0,
      ShellTab.map => 1,
      ShellTab.timeline => 2,
      ShellTab.museums => 3,
    };
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StrataColors.cream,
      body: navigationShell,
      bottomNavigationBar: StrataBottomNav(
        active: _active,
        onSelect: _onSelect,
        onScan: () => context.push('/identify'),
      ),
    );
  }
}
