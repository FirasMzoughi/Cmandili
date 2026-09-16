package com.cmandili.driver

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

            // Android caches a channel's sound/importance at creation time and
            // ignores later edits to the same id, so the previously-silent
            // alarm channel had to be re-created under a new id (_2 -> _3).
            // Drop the stale one so it doesn't linger in the system settings
            // list as a dead, permanently-silent duplicate.
            nm.deleteNotificationChannel("cmandili_driver_alarm_2")

            // Same caching rule applies to the standard channel: the installed
            // "cmandili_orders" was created silent (the Dart side created it
            // first, without a sound) and cannot be fixed in place, so it is
            // dropped and re-created under a fresh id.
            nm.deleteNotificationChannel("cmandili_orders")

            // Standard delivery status updates
            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_orders_v2",
                    "Order Updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Notifications about delivery status"
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

            // Alarm channel for delivery offers — call-style alert that wakes the
            // screen and rings continuously until the driver accepts or rejects.
            val soundUri = Uri.parse(
                "android.resource://$packageName/raw/new_order"
            )
            val alarmAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_driver_alarm_3",
                    "Delivery Offer Alert",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Alarm-level alert for incoming delivery offers"
                    setSound(soundUri, alarmAttrs)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 400, 200, 400, 200, 400, 200, 800)
                    setShowBadge(true)
                }
            )
        }
    }
}
