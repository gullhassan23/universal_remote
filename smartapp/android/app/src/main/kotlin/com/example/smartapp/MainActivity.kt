package com.FutureDialLabs.tv.remote.universal.control

import com.FutureDialLabs.tv.remote.universal.control.androidtv.AndroidTvRemotePlugin
import android.content.ComponentCallbacks2
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    companion object {
        private var sharedAndroidTvRemotePlugin: AndroidTvRemotePlugin? = null
    }

    private var androidTvRemotePlugin: AndroidTvRemotePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = sharedAndroidTvRemotePlugin ?: AndroidTvRemotePlugin(applicationContext).also {
            sharedAndroidTvRemotePlugin = it
        }
        androidTvRemotePlugin = plugin
        plugin.registerWith(flutterEngine)
    }

    override fun onDestroy() {
        val plugin = androidTvRemotePlugin
        val keepAliveScheduled = plugin?.scheduleTerminationKeepAlive(20 * 60 * 1000L) == true
        if (!keepAliveScheduled) {
            plugin?.destroy()
            if (sharedAndroidTvRemotePlugin === plugin) {
                sharedAndroidTvRemotePlugin = null
            }
        }
        androidTvRemotePlugin = null
        super.onDestroy()
    }

    override fun onStop() {
        androidTvRemotePlugin?.scheduleBackgroundKeepAlive(null)
        super.onStop()
    }

    override fun onTrimMemory(level: Int) {
        if (level >= ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            androidTvRemotePlugin?.scheduleBackgroundKeepAlive(null)
        }
        super.onTrimMemory(level)
    }
}
