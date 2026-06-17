package com.cmandili.partner

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import io.flutter.app.FlutterApplication

class Application : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)

            // Standard order status updates
            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_orders",
                    "Order Updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Notifications about order status changes"
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

            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_orders_urgent_2",
                    "Urgent Order Updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Alarm-level alert for new incoming orders"
                    setSound(soundUri, alarmAttrs)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 300, 700, 300, 700)
                    setShowBadge(true)
                }
            )
        }
    }
}
