import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/orders/data/models/order.dart';
import '../../features/orders/data/partner_order_repository.dart';
import '../../features/orders/presentation/order_detail_screen.dart';

/// Deep-link routing for order notifications.
///
/// When the partner taps an order alarm, all we have is the order id. This
/// resolves the full [Order] and pushes [OrderDetailScreen] using a global
/// navigator key — so it works from outside the widget tree (FCM listeners and
/// the native intent bridge both fire there).
///
/// Three tap paths feed in here:
///   1. App terminated → native notification → MainActivity launch intent.
///      FCM has no message, so we read the `order_id` intent extra over the
///      MethodChannel via [handleInitialNotification].
///   2. App in background → tap → MainActivity.onNewIntent → MethodChannel
///      `onNotificationTap`.
///   3. App in foreground/background via a real FCM tap →
///      FirebaseMessaging.onMessageOpenedApp / getInitialMessage (wired in
///      PushService) calls [openOrder] directly.
class NotificationNavigation {
  NotificationNavigation._();
  static final NotificationNavigation instance = NotificationNavigation._();

  /// Attach to MaterialApp.navigatorKey.
  final navigatorKey = GlobalKey<NavigatorState>();

  static const _channel = MethodChannel('com.cmandili.partner/notifications');
  final _repo = PartnerOrderRepository();

  bool _wired = false;

  /// Call once after runApp(). Wires the warm-path channel handler and drains
  /// any cold-start notification that launched the app.
  void initialize() {
    if (_wired) return;
    _wired = true;

    // Warm path: app already alive, user tapped the notification.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap') {
        final orderId = call.arguments as String?;
        if (orderId != null && orderId.isNotEmpty) await openOrder(orderId);
      }
    });

    // Cold path: app was launched by the tap.
    handleInitialNotification();
  }

  /// Ask the native side whether this launch came from a notification tap.
  Future<void> handleInitialNotification() async {
    try {
      final orderId =
          await _channel.invokeMethod<String>('getInitialNotification');
      if (orderId != null && orderId.isNotEmpty) await openOrder(orderId);
    } on PlatformException {
      // Channel not available (e.g. iOS / not yet attached) — ignore.
    }
  }

  /// Resolve the order and push its detail screen. Safe to call from anywhere.
  Future<void> openOrder(String orderId) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return; // app not ready yet

    Order? order;
    try {
      order = await _repo.fetchOrder(orderId);
    } catch (_) {
      return; // network/RLS failure — don't crash the deep-link
    }
    if (order == null) return;

    // Re-read after the await in case the navigator was torn down meanwhile.
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order!)),
    );
  }
}
