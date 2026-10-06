import 'package:dino_app/app.dart';
import 'package:dino_app/data/services/firebase_bootstrap.dart';
import 'package:dino_app/data/strata_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  tearDown(StrataServices.resetForTest);

  test('hasGeneratedOptions is false until flutterfire configure', () {
    expect(FirebaseBootstrap.hasGeneratedOptions, isFalse);
  });

  test('constructFirebase returns null when options are missing', () async {
    expect(await FirebaseBootstrap.constructFirebase(), isNull);
  });

  test(
    'init keeps local repositories when Firebase is not configured',
    () async {
      await StrataServices.init(initializeFirebase: () async => false);
      expect(StrataServices.isFirebaseReady, isFalse);
      expect(StrataServices.identifyRepository, isNotNull);
      expect(StrataServices.taxonRepository, isNotNull);
    },
  );

  test('init records Firebase when construction succeeds', () async {
    await StrataServices.init(initializeFirebase: () async => true);
    expect(StrataServices.isFirebaseReady, isTrue);
    expect(StrataServices.identifyRepository, isNotNull);
  });

  testWidgets('onboarding still loads without a Firebase project file', (
    tester,
  ) async {
    await StrataServices.init(initializeFirebase: () async => false);
    await tester.pumpWidget(StrataApp());
    await tester.pump();

    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Get Started reaches Home when Firebase is configured', (
    tester,
  ) async {
    await StrataServices.init(initializeFirebase: () async => true);
    expect(StrataServices.isFirebaseReady, isTrue);

    await tester.pumpWidget(StrataApp());
    await tester.pump();
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Betty'), findsOneWidget);
    expect(find.text('Scan now'), findsOneWidget);
  });

  testWidgets('Get Started reaches Home when Firebase is skipped', (
    tester,
  ) async {
    await StrataServices.init(initializeFirebase: () async => false);
    expect(StrataServices.isFirebaseReady, isFalse);

    await tester.pumpWidget(StrataApp());
    await tester.pump();
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Betty'), findsOneWidget);
    expect(find.text('Scan now'), findsOneWidget);
  });
}
