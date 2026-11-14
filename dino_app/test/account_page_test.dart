import 'dart:typed_data';

import 'package:dino_app/data/repositories/account_repository.dart';
import 'package:dino_app/models/user_profile.dart';
import 'package:dino_app/router/app_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _AccountRepository implements AccountRepository {
  UserProfile profile = UserProfile(
    uid: 'test-user',
    displayName: 'Ada',
    createdAt: DateTime.utc(2026),
    friendCode: 'A2BCDE',
  );

  @override
  Stream<UserProfile?> watchProfile() => Stream.value(profile);

  @override
  Future<UserProfile?> getProfile() async => profile;

  @override
  Future<UserProfile> createAccount({
    required String email,
    required String password,
  }) async => profile;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async => profile;

  @override
  Future<void> updateDisplayName(String displayName) async {
    profile = UserProfile(
      uid: profile.uid,
      displayName: displayName,
      accountKind: profile.accountKind,
      createdAt: profile.createdAt,
      badgeCount: profile.badgeCount,
      friendCode: profile.friendCode,
      photoUrl: profile.photoUrl,
    );
  }

  @override
  Future<String> updateProfilePhoto(Uint8List imageBytes) async =>
      'https://example.test/profile.jpg';

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Home profile icon opens account page and saves the name', (
    tester,
  ) async {
    final accounts = _AccountRepository();
    final router = createAppRouter(accountRepository: accounts);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/home');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Change profile photo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ada Lovelace');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();
    expect(accounts.profile.displayName, 'Ada Lovelace');
    router.dispose();
  });
}
