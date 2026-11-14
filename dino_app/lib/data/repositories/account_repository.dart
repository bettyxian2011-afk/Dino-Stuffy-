import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/image_compressor.dart';
import '../../models/user_profile.dart';

/// Authentication and the signed-in user's own profile.
abstract class AccountRepository {
  Stream<UserProfile?> watchProfile();

  Future<UserProfile?> getProfile();

  Future<UserProfile> createAccount({
    required String email,
    required String password,
  });

  Future<UserProfile> signIn({required String email, required String password});

  Future<void> updateDisplayName(String displayName);

  Future<String> updateProfilePhoto(Uint8List imageBytes);

  Future<void> signOut();
}

/// Firebase email/password authentication with a read/write boundary limited
/// to the current user's `users/{uid}` profile document.
class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImageCompressor? imageCompressor,
    Random? random,
    DateTime Function()? now,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _imageCompressor =
           imageCompressor ??
           const ImageCompressor(maxSide: 512, jpegQuality: 82),
       _random = random ?? Random.secure(),
       _now = now ?? DateTime.now;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImageCompressor _imageCompressor;
  final Random _random;
  final DateTime Function() _now;

  late final Stream<UserProfile?> _profileChanges = _auth
      .authStateChanges()
      .asyncExpand((user) {
        if (user == null) return Stream<UserProfile?>.value(null);
        return _users.doc(user.uid).snapshots().map((snapshot) {
          final data = snapshot.data();
          return data == null ? null : UserProfile.fromJson(user.uid, data);
        });
      });

  static const _friendCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Stream<UserProfile?> watchProfile() => _profileChanges;

  @override
  Future<UserProfile?> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snapshot = await _users.doc(user.uid).get();
    final data = snapshot.data();
    return data == null ? null : UserProfile.fromJson(user.uid, data);
  }

  @override
  Future<UserProfile> createAccount({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase did not return the new user.');
    return _ensureProfile(user);
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Firebase did not return the user.');
    return _ensureProfile(user);
  }

  Future<UserProfile> _ensureProfile(User user) async {
    final reference = _users.doc(user.uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final existing = snapshot.data();
      if (existing != null) return UserProfile.fromJson(user.uid, existing);

      final displayName = defaultDisplayNameForEmail(user.email ?? '');
      final profile = UserProfile(
        uid: user.uid,
        displayName: displayName,
        createdAt: _now(),
        friendCode: _newFriendCode(),
      );
      transaction.set(reference, {
        'displayName': profile.displayName,
        'accountKind': 'standard',
        'createdAt': FieldValue.serverTimestamp(),
        'badgeCount': 0,
        'friendCode': profile.friendCode,
      });
      return profile;
    });
  }

  String _newFriendCode() {
    return List.generate(
      6,
      (_) => _friendCodeAlphabet[_random.nextInt(_friendCodeAlphabet.length)],
    ).join();
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before editing your profile.');
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError.value(displayName, 'displayName');
    await _users.doc(user.uid).update({'displayName': name});
  }

  @override
  Future<String> updateProfilePhoto(Uint8List imageBytes) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in before changing your photo.');
    final bytes = _imageCompressor.forVision(imageBytes);
    final mimeType = ImageCompressor.mimeTypeFor(bytes);
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    }.contains(mimeType)) {
      throw UnsupportedError('Choose a JPEG, PNG, WebP, HEIC, or HEIF photo.');
    }
    final photoRef = _storage.ref('users/${user.uid}/profile');
    await photoRef.putData(bytes, SettableMetadata(contentType: mimeType));
    final photoURL = await photoRef.getDownloadURL();
    await _users.doc(user.uid).update({'photoURL': photoURL});
    return photoURL;
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Local fallback used when Firebase client configuration is unavailable.
class GuestAccountRepository implements AccountRepository {
  const GuestAccountRepository();

  @override
  Stream<UserProfile?> watchProfile() => Stream.value(null);

  @override
  Future<UserProfile?> getProfile() async => null;

  @override
  Future<UserProfile> createAccount({
    required String email,
    required String password,
  }) => Future.error(StateError('Accounts require Firebase configuration.'));

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) => Future.error(StateError('Accounts require Firebase configuration.'));

  @override
  Future<void> updateDisplayName(String displayName) =>
      Future.error(StateError('Accounts require Firebase configuration.'));

  @override
  Future<String> updateProfilePhoto(Uint8List imageBytes) =>
      Future.error(StateError('Accounts require Firebase configuration.'));

  @override
  Future<void> signOut() async {}
}

String defaultDisplayNameForEmail(String email) {
  final prefix = email.trim().split('@').first;
  if (prefix.isEmpty) return 'Explorer';
  return prefix.length > 80 ? prefix.substring(0, 80) : prefix;
}
