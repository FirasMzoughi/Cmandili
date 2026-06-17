package com.cmandili.driver

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * CmandiliMessagingService — Driver App
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
 * Channel "cmandili_driver_alarm" is pre-created in Application.onCreate()
 * with AudioAttributes.USAGE_ALARM + custom sound.
 */
class CmandiliMessagingService : FirebaseMessagingService() {

    companion object {
        private const val ALARM_CHANNEL_ID = "cmandili_driver_alarm"
        private const val ALARM_NOTIF_ID   = 101  // matches kDriverAlarmNotifId in push_service.dart
    }

    override fun onMessageReceived(message: RemoteMessage) {
        if (message.data["event"] == "offer_to_driver") {
            showDeliveryOffer(message.data)
        }
        // No super call needed — base FirebaseMessagingService.onMessageReceived() is a no-op.
        // The Flutter foreground listener (FirebaseMessaging.onMessage) fires via a separate
        // broadcast mechanism and is unaffected by this service replacement.
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }

    private fun showDeliveryOffer(data: Map<String, String>) {
        val title      = data["title"]      ?: "🔔 Nouvelle livraison"
        val body       = data["body"]       ?: "Acceptez dans les 30 secondes."
        val distanceKm = data["distance_km"]

        val displayBody = if (!distanceKm.isNullOrBlank()) "$body  ($distanceKm km)" else body

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_type", "offer_to_driver")
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
            .setContentText(displayBody)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            // CATEGORY_CALL: call-style priority on lock screen and in DND.
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // ongoing = true: driver cannot swipe away — must open app to respond.
            .setOngoing(true)
            .setAutoCancel(false)
            // Covers the lock screen like an incoming call. Requires USE_FULL_SCREEN_INTENT.
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .build()

        // FLAG_INSISTENT loops the sound until explicitly cancelled via
        // PushService.cancelDeliveryAlarm() after the driver accepts/rejects.
        notification.flags = notification.flags or Notification.FLAG_INSISTENT

        getSystemService(NotificationManager::class.java)
            .notify(ALARM_NOTIF_ID, notification)
    }

    /** Called from PushService.cancelDeliveryAlarm() after accept/reject. */
    fun cancelDeliveryOffer() {
        getSystemService(NotificationManager::class.java)
            .cancel(ALARM_NOTIF_ID)
    }
}
