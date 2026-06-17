import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Channel IDs ──────────────────────────────────────────────────────────────
const String _kChannelId   = 'cmandili_orders';
const String _kChannelName = 'Order updates';
const String _kChannelDesc = 'New deliveries and order updates';

// Alarm channel — alarm AudioAttributes + max importance so the offer rings
// even when the phone is in silent/vibrate mode.
const String _kAlarmChannelId   = 'cmandili_driver_alarm';
const String _kAlarmChannelName = 'Delivery Offer';
const String _kAlarmChannelDesc =
    'Incoming delivery requests that require immediate attention';

// Stable notification ID so the alarm can be programmatically cancelled
// once the driver accepts or rejects the offer.
const int kDriverAlarmNotifId = 101;

// ── Background handler ───────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final event = message.data['event'] as String?;
  if (event != 'offer_to_driver') return; // Only handle delivery offers here.

  // Re-init flutter_local_notifications inside the background isolate.
  final local = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await local.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  // Create the alarm channel (idempotent — safe to call every time).
  await local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(AndroidNotificationChannel(
        _kAlarmChannelId,
        _kAlarmChannelName,
        description: _kAlarmChannelDesc,
        importance: Importance.max,
        playSound: true,
        // File: android/app/src/main/res/raw/new_order.mp3
        sound: const RawResourceAndroidNotificationSound('new_order'),
        enableVibration: true,
        vibrationPattern:
            Int64List.fromList([0, 400, 200, 400, 200, 400, 200, 800]),
      ));

  final title = message.data['title'] as String? ?? '🔔 Nouvelle livraison !';
  final body  = message.data['body']  as String?
      ?? 'Vous avez 15 secondes pour accepter.';

  await local.show(
    kDriverAlarmNotifId,
    title,
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
        // FLAG_INSISTENT (0x04) — repeats the sound continuously until the
        // notification is dismissed. This is the same flag used by ringtones.
        additionalFlags: Int32List.fromList([4]),
        // fullScreenIntent: turns on the screen and shows the notification
        // as a heads-up card even on the lock screen — call-style behaviour.
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        // AndroidNotificationCategory.call gives it call-like priority.
        category: AndroidNotificationCategory.call,
        // ongoing: true — notification cannot be swiped away, forcing the
        // driver to open the app and explicitly respond.
        ongoing: true,
        autoCancel: false,
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        // File: Runner/Resources/driver_alarm.wav (max 30 s on iOS).
        sound: 'new_order.wav',
        // critical alert: overrides silent/DND on iOS (requires entitlement).
        interruptionLevel: InterruptionLevel.critical,
      ),
    ),
  );
}

// ── PushService ──────────────────────────────────────────────────────────────

/// Single 15-second offer pushed by the backend when a new delivery is ready.
/// The home screen watches [PushService.instance.offerStream] to show a
/// full-screen accept/reject modal.
class OrderOffer {
  final String orderId;
  final DateTime receivedAt;
  const OrderOffer({required this.orderId, required this.receivedAt});
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fcm   = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  final _offerController = StreamController<OrderOffer>.broadcast();

  /// Emits when an FCM `offer_to_driver` message arrives while the app is in
  /// the FOREGROUND. The home screen shows an accept/reject modal.
  ///
  /// Background/terminated-state offers wake the device via the alarm
  /// notification; when the driver taps it the app opens, and the
  /// orders-stream provider surfaces the pending offer automatically.
  Stream<OrderOffer> get offerStream => _offerController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // On OEM Android (Xiaomi, Samsung, Huawei) battery optimization kills the
    // background Dart isolate, preventing delivery-offer alarms when terminated.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // for critical alerts on iOS
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Standard channel for non-urgent status updates.
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.high,
    ));

    // Alarm channel for delivery offers.
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
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

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _registerToken();
    _fcm.onTokenRefresh.listen((_) => _registerToken());

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _registerToken();
    });
  }

  // ── Token registration ──────────────────────────────────────────────────

  Future<void> _registerToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final token = await _fcm.getToken();
    if (token == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
      }, onConflict: 'token');
    } catch (_) {}
  }

  // ── Foreground message handler ──────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    final event = message.data['event'] as String?;

    // ── Delivery offer → emit on offerStream + show alarm notification ────
    if (event == 'offer_to_driver') {
      final orderId = message.data['order_id'] as String?;
      if (orderId != null && orderId.isNotEmpty) {
        _offerController.add(
          OrderOffer(orderId: orderId, receivedAt: DateTime.now()),
        );
      }
      // Show the alarm notification even in foreground so the driver can't
      // miss it if their phone is lying face-down.
      final title = message.data['title'] as String? ?? '🔔 Nouvelle livraison !';
      final body  = message.data['body']  as String?
          ?? 'Vous avez 15 secondes pour accepter.';
      _local.show(
        kDriverAlarmNotifId,
        title,
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
            additionalFlags: Int32List.fromList([4]),
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.call,
            ongoing: true,
            autoCancel: false,
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: true,
            sound: 'new_order.wav',
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
      );
      return;
    }

    // ── All other status updates → standard banner ────────────────────────
    final title = message.notification?.title ?? message.data['title'] as String?;
    final body  = message.notification?.body  ?? message.data['body']  as String?;
    if (title == null && body == null) return;
    _local.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ── Cancel alarm notification ───────────────────────────────────────────
  // MUST be called after the driver accepts or rejects the offer to stop the
  // continuous ringing. If this is not called the notification rings forever.
  Future<void> cancelDeliveryAlarm() => _local.cancel(kDriverAlarmNotifId);
}
