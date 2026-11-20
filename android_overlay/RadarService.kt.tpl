package __PKG__

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

class RadarService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val b: Notification.Builder = if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel("radar_service", "Radar actif", NotificationManager.IMPORTANCE_LOW)
            )
            Notification.Builder(this, "radar_service")
        } else {
            Notification.Builder(this)
        }
        val n = b.setContentTitle("Crypto Radar actif")
            .setContentText("Surveillance des jetons Binance en cours")
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(1, n)
        }
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "cryptoradar:ws")
            wakeLock?.acquire()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        try {
            wakeLock?.release()
        } catch (e: Exception) {
        }
        wakeLock = null
        super.onDestroy()
    }
}
