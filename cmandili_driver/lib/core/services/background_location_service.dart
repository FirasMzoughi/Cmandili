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

// Same alarm channel/notification ID as push_service.dart and
// CmandiliMessagingService.kt — shown directly from this isolate as a
// Realtime-driven fallback (see _onStart) for when the FCM broadcast never
// reaches the app at all (observed: MIUI cancels the wake broadcast for a
// closed app before either FCM handler runs, even with battery/autostart/
// appops all granted). Reusing the ID means whichever path fires first wins
// and the other is a harmless no-op update/cancel on the same notification.
const _kAlarmChannelId = 'cmandili_driver_alarm_2';
const _kAlarmChannelName = 'Delivery Offer';
const _kAlarmChannelDesc =
    'Incoming delivery requests that require immediate attention';
const _kAlarmNotifId = 101;

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

  /// Android only grants "Allow all the time" via a second prompt, and only
  /// after "While using the app" is already granted — requesting it too
  /// early (e.g. at cold start) silently fails on Android 11+. Call this
  /// right before starting the service, once foreground permission is known
  /// to be granted, so the GPS stream keeps delivering once the app is
  /// actually backgrounded instead of pausing after a few minutes.
  /// iOS relies on UIBackgroundModes=location (see Info.plist) once
  /// when-in-use is granted, so no extra request is needed there.
  static Future<void> _ensureBackgroundPermission() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      await Permission.locationAlways.request();
    }
  }

  /// Call when driver accepts an order. Persists IDs so the isolate can read them.
  static Future<void> startTracking({
    required String driverId,
    required String deliveryId,
  }) async {
    await _ensureBackgroundPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDriverIdKey, driverId);
    await prefs.setString(_kDeliveryIdKey, deliveryId);
    _service.startService();
  }

  /// Call when driver toggles online but has no active delivery yet.
  /// Starts the foreground service (persistent "online" notification) so
  /// Android OEMs keep FCM push alive even when the app is backgrounded.
  static Future<void> startOnlinePresence({required String driverId}) async {
    await _ensureBackgroundPermission();
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

  // ── Delivery-offer alarm via Realtime — bypasses FCM entirely ─────────────
  // This foreground service is already running whenever the driver is online,
  // so instead of depending on an FCM broadcast waking a closed app (which
  // MIUI has been observed to cancel before either the native or Dart FCM
  // handler ever runs), listen to the DB directly for this driver being
  // offered an order and show the same alarm notification from here.
  final offerLocal = FlutterLocalNotificationsPlugin();
  await offerLocal.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await offerLocal
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(AndroidNotificationChannel(
        _kAlarmChannelId,
        _kAlarmChannelName,
        description: _kAlarmChannelDesc,
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('new_order'),
        enableVibration: true,
        vibrationPattern:
            Int64List.fromList([0, 400, 200, 400, 200, 400, 200, 800]),
      ));

  // Tracks the order currently being alarmed so a repeat snapshot of the same
  // still-open offer doesn't re-trigger the sound, and so the notification is
  // cancelled once the offer is no longer open (accepted elsewhere in the UI,
  // or rotated away by rotate_expired_offers()).
  String? activeOfferOrderId;
  final offerSub = supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('assigned_driver_id', driverId)
      .listen((rows) async {
    Map<String, dynamic>? openOffer;
    for (final row in rows) {
      if (row['driver_id'] == null) {
        openOffer = row;
        break;
      }
    }

    if (openOffer != null && openOffer['id'] != activeOfferOrderId) {
      activeOfferOrderId = openOffer['id'] as String;
      final distanceKm = openOffer['distance_km'] as num?;
      final body = distanceKm != null
          ? 'Acceptez dans les 30 secondes.  (${distanceKm.toStringAsFixed(1)} km)'
          : 'Acceptez dans les 30 secondes.';
      await offerLocal.show(
        _kAlarmNotifId,
        '🔔 Nouvelle livraison',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kAlarmChannelId,
            _kAlarmChannelName,
            channelDescription: _kAlarmChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('new_order'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            vibrationPattern:
                Int64List.fromList([0, 400, 200, 400, 200, 400, 200, 800]),
            additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.call,
            ongoing: true,
            autoCancel: false,
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: true,
            sound: 'new_order.mp3',
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
      );
    } else if (openOffer == null && activeOfferOrderId != null) {
      activeOfferOrderId = null;
      await offerLocal.cancel(_kAlarmNotifId);
    }
  });

  service.on('stop').listen((_) {
    offerSub.cancel();
    offerLocal.cancel(_kAlarmNotifId);
  });

  // Stream GPS with high accuracy, 30m filter
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
    // Both writes are independent (different tables, unrelated failure
    // modes), so run them concurrently instead of one after the other --
    // sequential awaits were paying double the network round-trip on every
    // single GPS tick in the exact path the client's live tracking map
    // depends on. Each keeps its own try/catch so one failing doesn't cancel
    // or delay the other.
    await Future.wait([
      () async {
        try {
          await supabase.from('drivers').update({
            'current_lat': pos.latitude,
            'current_lng': pos.longitude,
            'last_location_update': DateTime.now().toIso8601String(),
          }).eq('id', driverId);
        } catch (e) {
          debugPrint('[BG] driver update failed: $e');
        }
      }(),
      if (deliveryId != null)
        () async {
          try {
            await supabase.from('deliveries').update({
              'current_lat': pos.latitude,
              'current_lng': pos.longitude,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', deliveryId);
          } catch (e) {
            debugPrint('[BG] delivery update failed: $e');
          }
        }(),
    ]);
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
