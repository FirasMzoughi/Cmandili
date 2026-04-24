import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;
  
  // Driver-specific auth methods
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: e');
    }
  }
  
  // Driver delivery management
  Future<List<Map<String, dynamic>>> getAvailableDeliveries() async {
    try {
      final response = await client
          .from('deliveries')
          .select('*, orders(*, restaurants(*), customers(*))')
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(20);
      
      return response;
    } catch (e) {
      throw Exception('Failed to fetch available deliveries: e');
    }
  }
  
  Future<List<Map<String, dynamic>>> getDriverDeliveries(String driverId) async {
    try {
      final response = await client
          .from('deliveries')
          .select('*, orders(*, restaurants(*))')
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(50);
      
      return response;
    } catch (e) {
      throw Exception('Failed to fetch driver deliveries: e');
    }
  }
  
  Future<void> updateDeliveryStatus(String deliveryId, String status, {
    double? currentLat,
    double? currentLng,
  }) async {
    try {
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (currentLat != null && currentLng != null) {
        updates['current_lat'] = currentLat;
        updates['current_lng'] = currentLng;
      }
      
      await client
          .from('deliveries')
          .update(updates)
          .eq('id', deliveryId);
    } catch (e) {
      throw Exception('Failed to update delivery status: e');
    }
  }
  
  // Real-time subscriptions for driver assignments
  RealtimeChannel subscribeToDriverAssignments(String driverId, Function(dynamic) callback) {
    final channel = client.channel('driver-driverId');
    
    channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: 'INSERT', schema: 'public', table: 'deliveries'),
      (payload, [ref]) {
        if (payload['new']['driver_id'] == driverId) {
          callback(payload);
        }
      },
    ).subscribe();
    
    return channel;
  }
  
  // Driver location tracking
  Future<void> updateDriverLocation(String driverId, double lat, double lng) async {
    try {
      await client
          .from('drivers')
          .update({
            'current_lat': lat,
            'current_lng': lng,
            'last_location_update': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
    } catch (e) {
      throw Exception('Failed to update driver location: e');
    }
  }
  
  // Driver earnings
  Future<Map<String, dynamic>> getDriverEarnings(String driverId, DateTime startDate, DateTime endDate) async {
    try {
      final response = await client.rpc('get_driver_earnings', params: {
        'driver_id': driverId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      });
      
      return response;
    } catch (e) {
      throw Exception('Failed to fetch driver earnings: e');
    }
  }
}