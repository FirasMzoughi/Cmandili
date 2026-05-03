import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/background_location_service.dart';
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
    final driverId = await _ref.read(currentDriverIdProvider.future);
    if (driverId == null) return;
    final row = await Supabase.instance.client
        .from('drivers')
        .select('is_online')
        .eq('id', driverId)
        .maybeSingle();
    if (mounted) state = row?['is_online'] as bool? ?? false;
  }

  Future<void> setOnline(bool next) async {
    if (state == next) return;
    final driverId = await _ref.read(currentDriverIdProvider.future);
    if (driverId == null) return;
    state = next;
    await Supabase.instance.client
        .from('drivers')
        .update({'is_online': next})
        .eq('id', driverId);

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
