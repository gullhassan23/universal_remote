package com.example.smartapp.androidtv.util

import android.util.Log

object Logger {
    private const val TAG = "AndroidTvRemote"

    fun d(message: String) {
        Log.d(TAG, message)
    }

    fun e(message: String, t: Throwable? = null) {
        if (t != null) Log.e(TAG, message, t) else Log.e(TAG, message)
    }
}
