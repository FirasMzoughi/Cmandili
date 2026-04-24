import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;
  
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> getPartnerOrders(String partnerId) async {
    try {
      final response = await client
          .from('orders')
          .select('*, restaurants(*)')
          .eq('restaurant_id', partnerId)
          .order('created_at', ascending: false)
          .limit(50);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch partner orders: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> getPartnerMenu(String partnerId) async {
    try {
      final response = await client
          .from('food_items')
          .select('*')
          .eq('restaurant_id', partnerId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch partner menu: $e');
    }
  }
  
  Stream<List<Map<String, dynamic>>> streamPartnerOrders(String partnerId) {
    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', partnerId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }
  
  RealtimeChannel subscribeToPartnerNotifications(String partnerId, Function(Map<String, dynamic>) callback) {
    final channel = client
        .channel('partner-$partnerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            if (payload.newRecord['partner_id'] == partnerId) {
              callback(payload.newRecord);
            }
          },
        )
        .subscribe();
    
    return channel;
  }
  
  Future<String> uploadMenuItemImage(String partnerId, String fileName, File file) async {
    try {
      final path = 'partners/$partnerId/menu/$fileName';
      await client.storage.from('menu-images').upload(path, file);
      return client.storage.from('menu-images').getPublicUrl(path);
    } catch (e) {
      throw Exception('Menu image upload failed: $e');
    }
  }
  
  Future<Map<String, dynamic>> getPartnerAnalytics(String partnerId, DateTime startDate, DateTime endDate) async {
    try {
      final response = await client.rpc('get_partner_analytics', params: {
        'partner_id': partnerId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      });
      
      return response;
    } catch (e) {
      throw Exception('Failed to fetch analytics: $e');
    }
  }
}
