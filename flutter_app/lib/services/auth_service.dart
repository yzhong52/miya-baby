/// Sign-in: Google accounts through Firebase Auth.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

/// The signed-in parent.
class AppUser {
  final String uid;
  final String? displayName;
  final String? email;

  const AppUser({required this.uid, this.displayName, this.email});
}

abstract interface class AuthService {
  /// The current user (null when signed out), then every change.
  Stream<AppUser?> userChanges();

  /// Sign in with a Google account. Completes without signing in if the
  /// user cancels; throws on other failures.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth;
  FirebaseAuthService(this._auth);

  /// `GoogleSignIn.instance.initialize` must run once before any other
  /// GoogleSignIn call.
  Future<void>? _googleReady;

  @override
  Stream<AppUser?> userChanges() => _auth.authStateChanges().map(
        (u) => u == null
            ? null
            : AppUser(uid: u.uid, displayName: u.displayName, email: u.email),
      );

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // google_sign_in's web plugin can't start sign-in from our own
      // button; Firebase's popup flow can.
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    await _initGoogle();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _initGoogle();
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  /// iOS needs the OAuth client id from GoogleService-Info.plist; Android
  /// reads its own from google-services.json.
  Future<void> _initGoogle() =>
      _googleReady ??= GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? DefaultFirebaseOptions.currentPlatform.iosClientId
            : null,
      );
}
