package com.example.smartapp

import com.example.smartapp.androidtv.AndroidTvRemotePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var androidTvRemotePlugin: AndroidTvRemotePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        androidTvRemotePlugin = AndroidTvRemotePlugin(this).also {
            it.registerWith(flutterEngine)
        }
    }

    override fun onDestroy() {
        androidTvRemotePlugin?.destroy()
        androidTvRemotePlugin = null
        super.onDestroy()
    }
}
