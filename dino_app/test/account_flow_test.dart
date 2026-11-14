import 'dart:typed_data';

import 'package:dino_app/app.dart';
import 'package:dino_app/data/repositories/account_repository.dart';
import 'package:dino_app/data/strata_services.dart';
import 'package:dino_app/models/user_profile.dart';
import 'package:dino_app/screens/home/home_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _MemoryAccounts implements AccountRepository {
  final Map<String, Map<String, Object?>> users = {};
  UserProfile? _current;

  @override
  Stream<UserProfile?> watchProfile() => Stream.value(_current);

  @override
  Future<UserProfile?> getProfile() async => _current;

  @override
  Future<UserProfile> createAccount({
    required String email,
    required String password,
  }) async {
    const uid = 'new-user-1';
    final profile = UserProfile(
      uid: uid,
      displayName: email.split('@').first,
      createdAt: DateTime.utc(2026, 1, 1),
      friendCode: 'A2BCDE',
    );
    users[uid] = {
      'displayName': profile.displayName,
      'accountKind': 'standard',
      'createdAt': profile.createdAt,
      'badgeCount': 0,
      'friendCode': profile.friendCode,
    };
    _current = profile;
    return profile;
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    if (_current == null) throw StateError('No account');
    return _current!;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final profile = _current!;
    _current = UserProfile(
      uid: profile.uid,
      displayName: displayName,
      accountKind: profile.accountKind,
      createdAt: profile.createdAt,
      badgeCount: profile.badgeCount,
      friendCode: profile.friendCode,
    );
    users[profile.uid]!['displayName'] = displayName;
  }

  @override
  Future<String> updateProfilePhoto(Uint8List imageBytes) async {
    final profile = _current!;
    const photoUrl = 'https://example.test/profile.jpg';
    _current = UserProfile(
      uid: profile.uid,
      displayName: profile.displayName,
      accountKind: profile.accountKind,
      createdAt: profile.createdAt,
      badgeCount: profile.badgeCount,
      friendCode: profile.friendCode,
      photoUrl: photoUrl,
    );
    users[profile.uid]!['photoURL'] = photoUrl;
    return photoUrl;
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  tearDown(() async {
    StrataServices.resetForTest();
  });

  testWidgets('Home greeting is generic signed out and named signed in', (
    tester,
  ) async {
    final accounts = _MemoryAccounts();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(accountRepository: accounts)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Good '), findsOneWidget);

    await accounts.createAccount(email: 'Ada@example.com', password: 'secret1');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(accountRepository: accounts)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(', Ada'), findsOneWidget);
  });

  testWidgets('Onboarding sign-up creates a standard users profile', (
    tester,
  ) async {
    final accounts = _MemoryAccounts();
    await StrataServices.init(
      initializeFirebase: () async => false,
      accountRepository: accounts,
    );
    await tester.pumpWidget(StrataApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to Strata? Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ada@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'safe-password');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(accounts.users, contains('new-user-1'));
    expect(
      accounts.users['new-user-1'],
      containsPair('accountKind', 'standard'),
    );
    expect(accounts.users['new-user-1'], containsPair('badgeCount', 0));
    expect(accounts.users['new-user-1'], containsPair('friendCode', 'A2BCDE'));
    expect(find.textContaining(', Ada'), findsOneWidget);
  });
}
