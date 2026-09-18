package com.cmandili.partner

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * CmandiliMessagingService — Partner App
 *
 * Extends FirebaseMessagingService directly (NOT FlutterFirebaseMessagingService,
 * which is an internal class of the flutter plugin and cannot be subclassed).
 *
 * This native Kotlin service runs in milliseconds. OEM Android (Xiaomi MIUI,
 * Samsung One UI) cannot kill it before the alarm fires, unlike the Dart
 * background isolate which needs 1-3 seconds to boot Flutter.
 *
 * Registered in AndroidManifest.xml in place of the Flutter plugin's default
 * service (tools:node="remove" on FlutterFirebaseMessagingService + new entry).
 *
 * The Dart foreground handler (FirebaseMessaging.onMessage) still fires
 * normally when the app is open — this service only handles background/terminated.
 *
 * Channel "cmandili_orders_urgent_4" is pre-created in Application.onCreate()
 * with AudioAttributes.USAGE_ALARM + custom sound.
 */
class CmandiliMessagingService : FirebaseMessagingService() {

    companion object {
        private const val ALARM_CHANNEL_ID = "cmandili_orders_urgent_4"
        private const val ALARM_NOTIF_ID   = 42   // matches _kAlarmNotifId in push_service.dart
    }

    override fun onMessageReceived(message: RemoteMessage) {
        if (message.data["type"] == "new_order") {
            showOrderAlarm(message.data)
        }
        // No super call needed — base FirebaseMessagingService.onMessageReceived() is a no-op.
        // The Flutter foreground listener (FirebaseMessaging.onMessage) fires via a separate
        // broadcast mechanism and is unaffected by this service replacement.
    }

    // Token refresh is handled by the Flutter plugin's separate token-refresh receiver.
    // Override here only if you need custom token-refresh logic.
    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }

    private fun showOrderAlarm(data: Map<String, String>) {
        val title = data["title"] ?: "🔔 Nouvelle commande !"
        val body  = data["body"]  ?: "Vous avez une commande en attente."

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_type", "new_order")
            putExtra("order_id", data["order_id"] ?: "")
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            ALARM_NOTIF_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, ALARM_CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            // CATEGORY_CALL rather than CATEGORY_ALARM: Android gives call-style
            // notifications the strongest lock-screen and Do Not Disturb
            // treatment, which is what makes the full-screen intent fire
            // reliably on a locked phone. Matches the driver app.
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // Cannot be swiped away: the restaurant has to open the app and
            // answer the order rather than flicking the alert off the shade.
            // Paired with FLAG_INSISTENT below, this is what keeps it ringing.
            .setOngoing(true)
            .setAutoCancel(false)
            // Covers the lock screen like an incoming call. Requires USE_FULL_SCREEN_INTENT.
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .build()

        // FLAG_INSISTENT loops the sound until the notification is dismissed.
        // AudioAttributes.USAGE_ALARM on the channel makes it ring through DND.
        notification.flags = notification.flags or Notification.FLAG_INSISTENT

        getSystemService(NotificationManager::class.java)
            .notify(ALARM_NOTIF_ID, notification)
    }
}
