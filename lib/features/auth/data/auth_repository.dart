import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:google_sign_in/google_sign_in.dart';

// Simple User class to replace Firebase User
class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String role;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.role = 'client',
  });

  factory User.fromSupabase(supabase.User user) {
    return User(
      uid: user.id,
      email: user.email,
      displayName: user.userMetadata?['full_name'] as String? ?? user.userMetadata?['name'] as String?,
      photoURL: user.userMetadata?['avatar_url'] as String? ?? user.userMetadata?['picture'] as String?,
      role: user.appMetadata['role'] as String? ?? 'client',
    );
  }
}

class AuthRepository {
  final _supabase = supabase.Supabase.instance.client;
  final _googleSignIn = GoogleSignIn(
    serverClientId: '1047309149711-09in2f2qoce5upqcno61ekuevp2e5hjk.apps.googleusercontent.com',
  );
  
  // Get current user
  User? get currentUser {
    final user = _supabase.auth.currentUser;
    return user != null ? User.fromSupabase(user) : null;
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      return user != null ? User.fromSupabase(user) : null;
    });
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    // GoTrue can occasionally hang indefinitely on this call (observed after
    // a sign-out earlier in the same session) — without a timeout the button
    // spins forever with no error and no way to recover short of killing the
    // app. Force it to fail instead so the UI can reset and the user can retry.
    final response = await _supabase.auth
        .signInWithPassword(email: email, password: password)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw 'La connexion prend trop de temps. Réessaie.',
        );

    final user = response.user;
    if (user == null) throw 'Sign in failed';

    return User.fromSupabase(user);
  }

  // Sign up with email and password — also inserts a drivers row immediately
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );

    final user = response.user;
    if (user == null) throw 'Sign up failed';

    await _ensureDriverRow(user.id, phone);
    return User.fromSupabase(user);
  }

  Future<void> _ensureDriverRow(String userId, String phone) async {
    await _supabase.from('drivers').upsert({
      'user_id': userId,
      'is_online': false,
    }, onConflict: 'user_id');

    // Store phone on the profiles row (created by the auth trigger)
    if (phone.isNotEmpty) {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'phone': phone,
      }, onConflict: 'id');
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw 'No Access Token found.';
      }

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) throw 'Google sign in failed';

      // Google sign-in: phone not available at this point; driver can update it from profile settings
      await _ensureDriverRow(user.id, '');

      return User.fromSupabase(user);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  // Apple Sign-In not surfaced in driver UI — reserved for future use.
  Future<User?> signInWithApple() async {
    throw UnimplementedError('Apple Sign In is not available in the driver app.');
  }

  // Sign out
  Future<void> signOut() async {
    // Remove this device's push token before the session ends. Left
    // unremoved, a stale row keeps receiving pushes for this account even
    // after a different account signs in on the same physical device --
    // confirmed live: a driver's status-update pushes were reaching a
    // phone that had since switched to a different test account, because
    // its old token from months ago was still sitting in device_tokens.
    // Must run before auth.signOut() -- the RLS policy needs auth.uid()
    // to still resolve to this user.
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _supabase.from('device_tokens').delete().eq('token', token);
      }
    } catch (e) {
      debugPrint('signOut: failed to remove device token: $e');
    }
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }

  // ── Password reset (OTP flow) ──────────────────────────────────────────────

  /// Step 1 — Sends a 6-digit recovery code to [email].
  Future<void> sendPasswordResetOtp(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Step 2 — Verifies the 6-digit [token] and establishes a recovery session.
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: supabase.OtpType.recovery,
    );
  }

  /// Step 3 — Updates the password.  Must follow a successful [verifyPasswordResetOtp].
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      supabase.UserAttributes(password: newPassword),
    );
  }
}
