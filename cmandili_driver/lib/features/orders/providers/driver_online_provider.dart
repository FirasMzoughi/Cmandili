import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/background_location_service.dart';
import '../../../core/utils/location_service.dart';
import 'driver_orders_provider.dart';

/// Public state for the driver's online/offline toggle. Reads the current
/// `drivers.is_online` row on init and persists toggles back to Supabase.
/// Also starts/stops the foreground location service so push + GPS keep
/// working while the driver is online and the app is backgrounded.
final driverOnlineProvider =
    StateNotifierProvider<DriverOnlineNotifier, bool>((ref) {
  return DriverOnlineNotifier(ref);
});

class DriverOnlineNotifier extends StateNotifier<bool> {
  final Ref _ref;
  DriverOnlineNotifier(this._ref) : super(false) {
    _init();
  }

  Future<void> _init() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final row = await Supabase.instance.client
        .from('drivers')
        .select('is_online')
        .eq('user_id', userId)
        .maybeSingle();
    if (mounted) state = row?['is_online'] as bool? ?? false;
  }

  Future<void> setOnline(bool next) async {
    if (state == next) return;
    final driverId = await _ref.read(currentDriverIdProvider.future);
    if (driverId == null) return;
    state = next;

    final Map<String, dynamic> payload = {'is_online': next};
    if (next) {
      debugPrint('[Online] Fetching GPS position...');
      final position = await LocationService.getCurrentPosition();
      debugPrint('[Online] Position result: $position');
      if (position != null) {
        debugPrint('[Online] lat=${position.latitude}, lng=${position.longitude}');
        payload['current_lat'] = position.latitude;
        payload['current_lng'] = position.longitude;
        payload['last_location_update'] = DateTime.now().toIso8601String();
      } else {
        debugPrint('[Online] ⚠️ Position is NULL — coordinates will NOT be updated');
      }
    }

    final authUid = Supabase.instance.client.auth.currentUser?.id;
    debugPrint('[Online] driverId (drivers.id)=$driverId  auth.uid()=$authUid');
    debugPrint('[Online] Supabase payload: $payload');
    try {
      // Filter by user_id = auth.uid() so the WHERE clause matches the RLS
      // UPDATE policy exactly. Filtering by drivers.id alone can silently affect
      // 0 rows if RLS blocks the row (Supabase returns 200 with no error).
      final updated = await Supabase.instance.client
          .from('drivers')
          .update(payload)
          .eq('user_id', authUid!)
          .select('id, current_lat, current_lng');
      if ((updated as List).isEmpty) {
        debugPrint('[Online] ⚠️ UPDATE affected 0 rows — RLS may be blocking or user_id mismatch');
      } else {
        debugPrint('[Online] Supabase update SUCCESS → $updated');
      }
    } catch (e) {
      debugPrint('[Online] ❌ Supabase update FAILED: $e');
    }

    if (next) {
      await BackgroundLocationService.startOnlinePresence(driverId: driverId);
    } else {
      if (await BackgroundLocationService.isRunning) {
        await BackgroundLocationService.stopTracking();
      }
    }
  }

  Future<void> toggle() => setOnline(!state);
}
