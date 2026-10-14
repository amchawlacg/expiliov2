import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../database/database_helper.dart';
import 'attachment_service.dart';
import 'sync_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final SyncService _syncService;
  final AttachmentService _attachmentService;

  AuthService({
    SyncService? syncService,
    AttachmentService? attachmentService,
  })  : _syncService = syncService ?? SyncService(),
        _attachmentService = attachmentService ?? AttachmentService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Helper to handle session persistence and initial cloud data pull
  Future<void> _handlePostSignIn(User user) async {
    // 1. Re-arm network listeners and clear any stop/lock flags from logout
    _syncService.resumeSync();

    // 2. Fetch and hydrate all remote transactions & attachments FIRST
    await _syncService.pullRemoteData(user.uid);

    // 3. Save local session to SQLite AFTER hydration completes
    await DatabaseHelper.instance.saveUserSession(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
    debugPrint('[AUTH] Local session and initial sync ready for: ${user.email}');

    // 4. Notify main.dart root listener that session & data are ready
    SyncService.onDataChanged.value++;
  }

  // --- Google Sign-In ---
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      debugPrint('[AUTH] Google Sign-In canceled by user.');
      return null;
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 1. Sign in to Firebase Auth
    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    // 2. Hydrate data and record session
    if (user != null) {
      _syncService.resumeSync();
      await _syncService.pullRemoteData(user.uid);
      await DatabaseHelper.instance.saveUserSession(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
      debugPrint('[AUTH] Session & remote sync ready for: ${user.email}');
    }

    return userCredential;
  }

  // --- Apple Sign-In ---
  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final OAuthCredential credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      _syncService.resumeSync();
      await _syncService.pullRemoteData(user.uid);
      await DatabaseHelper.instance.saveUserSession(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
      debugPrint('[AUTH] Session & remote sync ready for: ${user.email}');
    }

    return userCredential;
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    try {
      // 1. Cancel listeners and lock active background sync loops
      await _syncService.stopAndReset();

      // 2. Wipe cached data & session to keep local state clean for next login
      await DatabaseHelper.instance.clearAllUserData();
      await DatabaseHelper.instance.clearUserSession();

      // 3. Clear auth providers
      await GoogleSignIn().signOut();
      await _auth.signOut();

      debugPrint('[AUTH] User successfully signed out and local cache cleared.');
    } catch (e) {
      debugPrint('[AUTH] Error during sign-out: $e');
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
}