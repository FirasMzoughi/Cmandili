package com.cmandili.partner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.app.FlutterApplication

class Application : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)

            // Android caches a channel's sound at creation and ignores every
            // later edit to the same id, so the already-installed, permanently
            // silent "cmandili_orders" cannot be repaired in place -- it has to
            // be re-created under a fresh id. Drop the stale one so it doesn't
            // linger in system settings as a dead silent duplicate.
            nm.deleteNotificationChannel("cmandili_orders")

            // Standard order status updates
            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_orders_v2",
                    "Order Updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Notifications about order status changes"
                    // This channel is the manifest default_notification_channel_id,
                    // so it's what any FCM `notification`-payload message lands on.
                    // It had no setSound() at all, which on Android O+ is NOT the
                    // same as "use the default tone" — an IMPORTANCE_HIGH channel
                    // created without a sound is created permanently silent.
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    enableVibration(true)
                    setShowBadge(true)
                }
            )

            // Alarm channel for new incoming orders — uses alarm audio attributes
            // so Android plays the sound even in Do Not Disturb mode.
            val soundUri = Uri.parse(
                "android.resource://$packageName/raw/new_order"
            )
            val alarmAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            // _3 -> _4: importance and DND-bypass are also frozen at creation
            // time, so raising the channel to IMPORTANCE_MAX and letting it
            // through Do Not Disturb needs a new id. IMPORTANCE_HIGH shows a
            // heads-up but IMPORTANCE_MAX is what reliably drives the
            // full-screen intent on a locked screen.
            nm.deleteNotificationChannel("cmandili_orders_urgent_3")

            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_orders_urgent_4",
                    "Urgent Order Updates",
                    NotificationManager.IMPORTANCE_MAX,
                ).apply {
                    description = "Alarm-level alert for new incoming orders"
                    setSound(soundUri, alarmAttrs)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 300, 700, 300, 700)
                    setShowBadge(true)
                    // A restaurant loses the order if the alert is muted by a
                    // Do Not Disturb schedule they forgot was on.
                    setBypassDnd(true)
                    enableLights(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            )
        }
    }
}
