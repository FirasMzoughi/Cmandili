import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final _supabase = Supabase.instance.client;

  // Get current user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (phone != null) updates['phone'] = phone;

      await _supabase.from('profiles').update(updates).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // Upload profile picture (requires File from dart:io)
  // Future<String?> uploadProfilePicture(File file) async {
  //   try {
  //     final userId = _supabase.auth.currentUser?.id;
  //     if (userId == null) return null;

  //     final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
  //     
  //     await _supabase.storage
  //         .from('avatars')
  //         .upload(fileName, file);

  //     final publicUrl = _supabase.storage
  //         .from('avatars')
  //         .getPublicUrl(fileName);

  //     return publicUrl;
  //   } catch (e) {
  //     debugPrint('Error uploading profile picture: $e');
  //     return null;
  //   }
  // }
}
