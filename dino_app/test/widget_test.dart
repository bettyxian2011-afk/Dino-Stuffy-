import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dino_app/app.dart';
import 'package:dino_app/data/strata_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  tearDown(StrataServices.resetForTest);

  testWidgets('Onboarding shows Strata branding and Get Started', (
    WidgetTester tester,
  ) async {
    await StrataServices.init(initializeFirebase: () async => false);
    await tester.pumpWidget(StrataApp());
    await tester.pump();

    expect(find.text('Strata'), findsOneWidget);
    expect(find.textContaining('Read the record'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
