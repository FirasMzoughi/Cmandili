import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDriverIdKey = 'bg_driver_id';
const _kDeliveryIdKey = 'bg_delivery_id';
const _kNotifChannelId = 'cmandili_driver_location';
const _kNotifId = 888;

/// Starts / stops a foreground background-service that streams GPS to Supabase
/// even when the driver navigates away from the tracking screen or backgrounds the app.
class BackgroundLocationService {
  BackgroundLocationService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> initialize() async {
    // Android 13+ requires the POST_NOTIFICATIONS runtime permission, otherwise
    // startForeground crashes with CannotPostForegroundServiceNotificationException.
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }

      // Explicitly register the channel the foreground service will post to.
      // flutter_background_service relies on this existing — if missing,
      // the OS rejects the notification and kills the process.
      const channel = AndroidNotificationChannel(
        _kNotifChannelId,
        'Cmandili Driver Location',
        description: 'Keeps GPS tracking active while delivering',
        importance: Importance.low,
      );
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _kNotifChannelId,
        initialNotificationTitle: 'Cmandili Driver',
        initialNotificationContent: 'Location tracking active',
        foregroundServiceNotificationId: _kNotifId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Call when driver accepts an order. Persists IDs so the isolate can read them.
  static Future<void> startTracking({
    required String driverId,
    required String deliveryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDriverIdKey, driverId);
    await prefs.setString(_kDeliveryIdKey, deliveryId);
    _service.startService();
  }

  /// Call when driver toggles online but has no active delivery yet.
  /// Starts the foreground service (persistent "online" notification) so
  /// Android OEMs keep FCM push alive even when the app is backgrounded.
  static Future<void> startOnlinePresence({required String driverId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDriverIdKey, driverId);
    await prefs.remove(_kDeliveryIdKey);
    if (!(await _service.isRunning())) {
      _service.startService();
    }
  }

  /// Call when delivery is marked delivered or cancelled.
  static Future<void> stopTracking() async {
    _service.invoke('stop');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDriverIdKey);
    await prefs.remove(_kDeliveryIdKey);
  }

  static Future<bool> get isRunning => _service.isRunning();
}

// ── Background isolate entry point ───────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Read persisted IDs (SharedPreferences works across isolates on Android)
  final prefs = await SharedPreferences.getInstance();
  final driverId = prefs.getString(_kDriverIdKey);
  final deliveryId = prefs.getString(_kDeliveryIdKey);

  if (driverId == null) {
    service.stopSelf();
    return;
  }

  // Initialize Supabase inside this isolate.
  // Supabase.initialize is a no-op if already initialized in the same process,
  // but the background isolate on Android is separate — read env from prefs.
  final supabaseUrl = prefs.getString('supabase_url') ?? '';
  final supabaseKey = prefs.getString('supabase_anon_key') ?? '';
  if (supabaseUrl.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    } catch (_) {
      // Already initialized in same process (iOS foreground mode)
    }
  }

  final supabase = Supabase.instance.client;

  // Listen for stop command from UI
  service.on('stop').listen((_) {
    service.stopSelf();
  });

  // Stream GPS with high accuracy, 10m filter
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    service.stopSelf();
    return;
  }

  Future<void> pushLocation(Position pos) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Cmandili Driver',
        content:
            'Location tracking active • ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
      );
    }
    try {
      await supabase.from('drivers').update({
        'current_lat': pos.latitude,
        'current_lng': pos.longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', driverId);
    } catch (e) {
      debugPrint('[BG] driver update failed: $e');
    }
    if (deliveryId != null) {
      try {
        await supabase.from('deliveries').update({
          'current_lat': pos.latitude,
          'current_lng': pos.longitude,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', deliveryId);
      } catch (e) {
        debugPrint('[BG] delivery update failed: $e');
      }
    }
  }

  StreamSubscription<Position>? posStream;
  posStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 30, // Mise à jour de la position uniquement après 30 mètres de déplacement
    ),
  ).listen((pos) async {
    await pushLocation(pos);
  });

  // Fetch initial location immediately so we have at least one record
  try {
    final initialPos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await pushLocation(initialPos);
  } catch (_) {}

  // Clean up when service stops
  service.on('stop').listen((_) {
    posStream?.cancel();
  });
}
