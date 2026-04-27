package com.FutureDialLabs.tv.remote.universal.control.androidtv

object AndroidTvKeepAliveRegistry {
    const val DEFAULT_KEEP_ALIVE_MS: Long = 20 * 60 * 1000L
    @Volatile
    var plugin: AndroidTvRemotePlugin? = null

    @Volatile
    var keepAliveExpiryAtMs: Long = 0L
    @Volatile
    var keepAliveIndefinite: Boolean = false

    fun remainingMs(nowMs: Long = System.currentTimeMillis()): Long {
        val expiry = keepAliveExpiryAtMs
        if (expiry <= nowMs) return 0L
        return expiry - nowMs
    }

    fun isKeepAliveActive(nowMs: Long = System.currentTimeMillis()): Boolean {
        return remainingMs(nowMs) > 0L
    }

    fun clearKeepAlive() {
        keepAliveExpiryAtMs = 0L
        keepAliveIndefinite = false
    }
}
