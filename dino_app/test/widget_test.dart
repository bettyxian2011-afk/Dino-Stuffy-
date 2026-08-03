import 'package:flutter_test/flutter_test.dart';

import 'package:dino_app/app.dart';

void main() {
  testWidgets('Onboarding shows Strata branding and Get Started', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(StrataApp());
    await tester.pumpAndSettle();

    expect(find.text('Strata'), findsOneWidget);
    expect(find.textContaining('Read the record'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
