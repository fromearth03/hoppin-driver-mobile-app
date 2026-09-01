package tech.hoppin.hoppin_driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The ride-offer push targets this exact channel id (the service's
        // push.RideAlertsChannel). IMPORTANCE_HIGH is what makes the offer
        // surface as a heads-up alert with the screen off.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ride_alerts",
                "Ride alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "New ride offers and trip updates"
                enableVibration(true)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}
