import 'package:supabase_flutter/supabase_flutter.dart';

class AddressRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUserAddresses() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final response = await _supabase
          .from('user_addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> addAddress({
    required String name,
    required String fullAddress,
    required bool isDefault,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      if (isDefault) {
        await _supabase
            .from('user_addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      final response = await _supabase
          .from('user_addresses')
          .insert({
            'user_id': userId,
            'name': name,
            'full_address': fullAddress,
            'is_default': isDefault,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteAddress(String id) async {
    try {
      await _supabase.from('user_addresses').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setDefault(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      await _supabase
          .from('user_addresses')
          .update({'is_default': false})
          .eq('user_id', userId);
      await _supabase
          .from('user_addresses')
          .update({'is_default': true})
          .eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }
}
