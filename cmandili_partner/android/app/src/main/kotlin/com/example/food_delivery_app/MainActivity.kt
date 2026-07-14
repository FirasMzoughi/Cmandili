package com.cmandili.partner

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — Partner App
 *
 * Bridges the native notification tap (built by CmandiliMessagingService when
 * the app is killed) into Dart so the app can deep-link to the tapped order.
 *
 * When the app is terminated, the alarm notification is built natively and its
 * tap PendingIntent launches THIS activity with `order_id` / `notification_type`
 * extras. FirebaseMessaging.getInitialMessage() is NULL on this path (no FCM
 * message object is reconstructed), so Dart must read these intent extras over
 * the MethodChannel below instead.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.cmandili.partner/notifications"
    }

    private var channel: MethodChannel? = null

    // Holds the order_id from the launch intent until Dart asks for it via
    // getInitialNotification(). Consumed once so a hot restart doesn't re-navigate.
    private var pendingOrderId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingOrderId = orderIdFrom(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Cold-start path: Dart calls this after the engine is ready to
                // see if the app was launched by tapping an order notification.
                "getInitialNotification" -> {
                    result.success(pendingOrderId)
                    pendingOrderId = null // consume — only deep-link once
                }
                else -> result.notImplemented()
            }
        }
    }

    // Warm path: app already running in background, user taps the notification.
    // Android delivers the tap via onNewIntent (singleTop launch mode), so push
    // the order_id straight to Dart instead of stashing it for a cold start.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val orderId = orderIdFrom(intent)
        if (orderId != null) {
            channel?.invokeMethod("onNotificationTap", orderId)
        }
    }

    private fun orderIdFrom(intent: Intent?): String? {
        if (intent?.getStringExtra("notification_type") != "new_order") return null
        val orderId = intent.getStringExtra("order_id")
        return if (orderId.isNullOrBlank()) null else orderId
    }
}
