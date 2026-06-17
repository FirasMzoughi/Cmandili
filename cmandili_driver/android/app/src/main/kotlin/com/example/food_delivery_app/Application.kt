package com.cmandili.driver

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

            // Standard delivery status updates
            nm.createNotificationChannel(
                NotificationChannel(
                    "cmandili_orders",
                    "Order Updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Notifications about delivery status"
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
                    "cmandili_driver_alarm",
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
