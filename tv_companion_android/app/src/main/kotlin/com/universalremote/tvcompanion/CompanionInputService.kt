package com.universalremote.tvcompanion

import android.app.Service
import android.content.Intent
import android.os.IBinder

class CompanionInputService : Service() {
    private var protocolServer: CompanionProtocolServer? = null

    override fun onCreate() {
        super.onCreate()
        protocolServer = CompanionProtocolServer()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        protocolServer?.start()
        return START_STICKY
    }

    override fun onDestroy() {
        protocolServer?.stop()
        protocolServer = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
