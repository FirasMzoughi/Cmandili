import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:google_sign_in/google_sign_in.dart';
import 'models/partner_model.dart';

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
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) throw 'Sign in failed';

    return User.fromSupabase(user);
  }

  // Sign up with email, password, name, and partner type
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String name,
    String partnerType,
  ) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'partner_type': partnerType},
    );

    final user = response.user;
    if (user == null) throw 'Sign up failed';

    // Insert into partners table and create corresponding restaurant/supermarket record
    try {
      // 1. Create the restaurant or supermarket record first
      final tableName = partnerType == 'restaurant' ? 'restaurants' : 'supermarkets';
      final entityRow = await _supabase
          .from(tableName)
          .insert({'name': name, 'is_open': true})
          .select('id')
          .single();
      final entityId = entityRow['id'] as String;

      // 2. Upsert into partners table with real entity_id (safe on retry)
      await _supabase.from('partners').upsert({
        'user_id': user.id,
        'partner_type': partnerType,
        'business_name': name,
        'entity_id': entityId,
      }, onConflict: 'user_id');
    } catch (e) {
      // Partners table insert failed — non-blocking, profile can be created later
      debugPrint('Warning: Could not insert into partners table: $e');
    }

    return User.fromSupabase(user);
  }

  // Complete onboarding for Google Sign-in users.
  // Idempotent: if the user already has a partners row (e.g. from a previous
  // attempt that errored mid-way), update it instead of inserting a duplicate.
  Future<void> completeOnboarding(String name, String partnerType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw 'Not logged in';

    final existing = await _supabase
        .from('partners')
        .select('entity_id, partner_type')
        .eq('user_id', user.id)
        .maybeSingle();

    final tableName = partnerType == 'restaurant' ? 'restaurants' : 'supermarkets';

    String entityId;
    if (existing != null && existing['entity_id'] != null && existing['partner_type'] == partnerType) {
      // Reuse the entity already linked to this partner; just rename it.
      entityId = existing['entity_id'] as String;
      await _supabase
          .from(tableName)
          .update({'name': name})
          .eq('id', entityId);
    } else {
      // Create a fresh restaurant/supermarket row.
      final entityRow = await _supabase
          .from(tableName)
          .insert({'name': name, 'is_open': true})
          .select('id')
          .single();
      entityId = entityRow['id'] as String;
    }

    await _supabase.from('partners').upsert({
      'user_id': user.id,
      'partner_type': partnerType,
      'business_name': name,
      'entity_id': entityId,
    }, onConflict: 'user_id');
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) throw 'No Access Token found.';
      if (idToken == null) throw 'No ID Token found.';

      final response = await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) throw 'Google sign in failed';

      return User.fromSupabase(user);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  // Apple Sign-In is not surfaced in the partner UI — reserved for future use.
  Future<User?> signInWithApple() async {
    throw UnimplementedError('Apple Sign In is not available in the partner app.');
  }

  // Fetch partner profile from partners table
  Future<PartnerProfile?> fetchPartnerProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('partners')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return PartnerProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching partner profile: $e');
      return null;
    }
  }

  // Update partner profile
  Future<bool> updatePartnerProfile(PartnerProfile profile) async {
    try {
      await _supabase
          .from('partners')
          .update({
            'business_name': profile.businessName,
            'address': profile.address,
            'phone': profile.phone ?? '',
            'bio': profile.bio ?? '',
            'avatar_url': profile.avatarUrl ?? '',
          })
          .eq('user_id', profile.userId);
      return true;
    } catch (e) {
      debugPrint('Error updating partner profile: $e');
      return false;
    }
  }

  // Upload Avatar
  Future<String?> uploadAvatar(String path, dynamic fileBytesOrFile) async {
    try {
      await _supabase.storage.from('profiles').upload(
            path,
            fileBytesOrFile,
            fileOptions: const supabase.FileOptions(cacheControl: '3600', upsert: true),
          );
      return _supabase.storage.from('profiles').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
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
