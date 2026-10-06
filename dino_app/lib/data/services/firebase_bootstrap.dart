import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Optional Firebase startup. Missing FlutterFire config must not crash the app.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  /// True when [DefaultFirebaseOptions.currentPlatform] returns real options.
  static bool get hasGeneratedOptions {
    try {
      DefaultFirebaseOptions.currentPlatform;
      return true;
    } on UnsupportedError {
      return false;
    }
  }

  /// Creates the default Firebase app when options exist.
  ///
  /// Returns `null` when FlutterFire has not been run, the platform is
  /// unsupported, or native plugins are unavailable (widget tests).
  static Future<FirebaseApp?> constructFirebase() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        return Firebase.app();
      }
      if (!hasGeneratedOptions) {
        debugPrint(
          'StrataServices: Firebase options missing. Using local repositories.',
        );
        return null;
      }
      final options = DefaultFirebaseOptions.currentPlatform;
      final app = await Firebase.initializeApp(options: options);
      debugPrint('StrataServices: Firebase initialized (${options.projectId})');
      return app;
    } on UnsupportedError catch (e) {
      debugPrint(
        'StrataServices: Firebase options missing ($e). Using local repositories.',
      );
      return null;
    } catch (e) {
      debugPrint(
        'StrataServices: Firebase init skipped ($e). Using local repositories.',
      );
      return null;
    }
  }

  static Future<bool> initialize() async {
    final app = await constructFirebase();
    return app != null;
  }
}
