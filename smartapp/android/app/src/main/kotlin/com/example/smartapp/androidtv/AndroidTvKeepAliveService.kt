package com.FutureDialLabs.tv.remote.universal.control.androidtv

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.FutureDialLabs.tv.remote.universal.control.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class AndroidTvKeepAliveService : Service() {
    companion object {
        private const val CHANNEL_ID = "android_tv_keep_alive"
        private const val NOTIFICATION_ID = 42011
        private const val ACTION_START = "com.example.smartapp.action.START_KEEP_ALIVE"
        private const val ACTION_STOP = "com.example.smartapp.action.STOP_KEEP_ALIVE"
        const val EXTRA_DURATION_MS = "durationMs"

        fun start(context: Context, durationMs: Long?) {
            val intent = Intent(context, AndroidTvKeepAliveService::class.java).apply {
                action = ACTION_START
                if (durationMs != null) {
                    putExtra(EXTRA_DURATION_MS, durationMs)
                }
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, AndroidTvKeepAliveService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var watchdogJob: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                AndroidTvKeepAliveRegistry.clearKeepAlive()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                val durationMs =
                    if (intent?.hasExtra(EXTRA_DURATION_MS) == true) {
                        intent.getLongExtra(
                            EXTRA_DURATION_MS,
                            AndroidTvKeepAliveRegistry.DEFAULT_KEEP_ALIVE_MS,
                        ).coerceAtLeast(1L)
                    } else {
                        null
                    }
                AndroidTvKeepAliveRegistry.keepAliveExpiryAtMs = durationMs?.let {
                    System.currentTimeMillis() + it
                } ?: 0L
                AndroidTvKeepAliveRegistry.keepAliveIndefinite = durationMs == null
                startForeground(NOTIFICATION_ID, buildNotification())
                startWatchdog()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        watchdogJob?.cancel()
        super.onDestroy()
    }

    private fun startWatchdog() {
        watchdogJob?.cancel()
        watchdogJob = scope.launch {
            while (isActive) {
                val remaining = AndroidTvKeepAliveRegistry.remainingMs()
                if (AndroidTvKeepAliveRegistry.keepAliveIndefinite) {
                    delay(1000L)
                    continue
                }
                if (remaining <= 0L) {
                    AndroidTvKeepAliveRegistry.plugin?.forceDisconnectForKeepAliveTimeout()
                    AndroidTvKeepAliveRegistry.clearKeepAlive()
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                    return@launch
                }
                delay(minOf(remaining, 1000L))
            }
        }
    }

    private fun buildNotification(): Notification {
        ensureChannel()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Remote connection active")
            .setContentText(
                if (AndroidTvKeepAliveRegistry.keepAliveIndefinite) {
                    "Connection stays alive until you disconnect."
                } else {
                    "Connection will stay alive for up to 20 minutes."
                },
            )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Android TV keep-alive",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }
}
