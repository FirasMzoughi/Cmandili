import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_navigation.dart';

// ── Channel IDs ──────────────────────────────────────────────────────────────
// Standard order-status updates (confirmed, preparing, etc.)
const String _kChannelId   = 'cmandili_orders';
const String _kChannelName = 'Order updates';
const String _kChannelDesc = 'Notifications about your orders';

// Alarm channel for NEW orders — uses alarm audio attributes so Android
// respects the sound even in DND. Must match the channel created at runtime.
const String _kAlarmChannelId   = 'cmandili_orders_urgent_2';
const String _kAlarmChannelName = 'Urgent Order updates';
const String _kAlarmChannelDesc = 'Urgent alerts for new incoming orders';

// Stable notification ID used for the alarm notification so we can cancel it.
const int _kAlarmNotifId = 42;

// ── Background handler ───────────────────────────────────────────────────────
// Must be a top-level function annotated with @pragma('vm:entry-point') so the
// Dart AOT compiler keeps it alive in the background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final type = message.data['type'] as String?;
  if (type != 'new_order') return; // Only handle new-order alarms here.

  // Re-initialise flutter_local_notifications inside the background isolate —
  // it doesn't inherit the main isolate's state.
  final local = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await local.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  // Pre-create the alarm channel (safe to call multiple times — Android is
  // idempotent on channel creation once the channel ID exists).
  await local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(AndroidNotificationChannel(
        _kAlarmChannelId,
        _kAlarmChannelName,
        description: _kAlarmChannelDesc,
        importance: Importance.max,
        playSound: true,
        // raw resource name without extension — file lives at:
        // android/app/src/main/res/raw/new_order.mp3
        sound: const RawResourceAndroidNotificationSound('new_order'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 300, 700, 300, 700]),
      ));

  final title = message.data['title'] as String? ?? 'Nouvelle commande !';
  final body  = message.data['body']  as String?
      ?? 'Vous avez une commande en attente.';

  await local.show(
    _kAlarmNotifId,
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
        vibrationPattern: Int64List.fromList([0, 500, 300, 700, 300, 700]),
        // FLAG_INSISTENT (0x04) — repeats the sound until the notification
        // is dismissed. Combined with the alarm channel this gives continuous
        // ringing like a real alarm.
        additionalFlags: Int32List.fromList([4]),
        // fullScreenIntent wakes the screen / shows on lock screen.
        fullScreenIntent: true,
        // Show on lock screen without requiring unlock.
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        // Keeps the notification at the top of the shade.
        ongoing: false,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        // File must be bundled in Runner/Resources/ — 30-second max on iOS.
        sound: 'new_order.wav',
        interruptionLevel: InterruptionLevel.critical,
      ),
    ),
  );
}

// ── PushService ──────────────────────────────────────────────────────────────

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fcm   = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // On OEM Android (Xiaomi, Samsung, Huawei) battery optimization kills the
    // background Dart isolate before it can show alarm notifications for new
    // orders when the app is terminated. Requesting exemption keeps the app
    // reachable so the alarm fires reliably.
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
      requestCriticalPermission: true, // required for critical alerts on iOS
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

    // Alarm channel for new orders. Created here AND in the background handler
    // so it exists whichever path fires first.
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _kAlarmChannelId,
      _kAlarmChannelName,
      description: _kAlarmChannelDesc,
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('new_order'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 300, 700, 300, 700]),
    ));

    // Show heads-up banners while the app is in the foreground on iOS.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    // Register the same top-level handler used for background.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── Notification-tap deep-linking ────────────────────────────────────────
    // These fire for taps on a real FCM `notification` payload. The native
    // killed-app alarm (CmandiliMessagingService) is data-only, so its taps
    // route through MainActivity's intent extras instead (see
    // NotificationNavigation). Handling both keeps every path covered.
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) _onNotificationTap(initialMessage);

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
  // Fired when the app is in the FOREGROUND. Re-uses the same alarm logic so
  // the restaurant owner is alerted even if they're actively using the app.

  void _onForegroundMessage(RemoteMessage message) {
    final type  = message.data['type'] as String?;
    final title = message.notification?.title ?? message.data['title'] as String?;
    final body  = message.notification?.body  ?? message.data['body']  as String?;
    if (title == null && body == null) return;

    final isNewOrder = type == 'new_order';

    _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isNewOrder ? _kAlarmChannelId : _kChannelId,
          isNewOrder ? _kAlarmChannelName : _kChannelName,
          channelDescription: isNewOrder ? _kAlarmChannelDesc : _kChannelDesc,
          importance:       isNewOrder ? Importance.max  : Importance.high,
          priority:         isNewOrder ? Priority.max    : Priority.high,
          playSound:        true,
          sound:            isNewOrder
              ? const RawResourceAndroidNotificationSound('new_order')
              : null,
          audioAttributesUsage: isNewOrder
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          additionalFlags: isNewOrder ? Int32List.fromList([4]) : null,
          fullScreenIntent: isNewOrder,
          visibility: isNewOrder
              ? NotificationVisibility.public
              : NotificationVisibility.private,
          category: isNewOrder
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.message,
          enableVibration: isNewOrder,
          vibrationPattern: isNewOrder
              ? Int64List.fromList([0, 500, 300, 700, 300, 700])
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          sound: isNewOrder ? 'new_order.wav' : null,
          interruptionLevel: isNewOrder
              ? InterruptionLevel.critical
              : InterruptionLevel.active,
        ),
      ),
    );
  }

  // ── Notification-tap handler ────────────────────────────────────────────
  // Fired when the partner taps an FCM `notification`-payload notification
  // (background tap → onMessageOpenedApp, terminated tap → getInitialMessage).
  // Deep-links to the order's detail screen.
  void _onNotificationTap(RemoteMessage message) {
    final orderId = message.data['order_id'] as String?;
    if (orderId != null && orderId.isNotEmpty) {
      NotificationNavigation.instance.openOrder(orderId);
    }
  }

  // ── Cancel alarm notification ───────────────────────────────────────────
  // Call this after the partner accepts/rejects an order to stop the ringing.
  Future<void> cancelOrderAlarm() => _local.cancel(_kAlarmNotifId);
}
