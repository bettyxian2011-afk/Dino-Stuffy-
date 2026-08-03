import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/strata_theme.dart';

class StrataApp extends StatelessWidget {
  StrataApp({super.key});

  final _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Strata',
      debugShowCheckedModeBanner: false,
      theme: StrataTheme.light(),
      routerConfig: _router,
    );
  }
}
