package com.mg.smart.tv.remote.control.androidtv.remote

import com.mg.smart.tv.remote.control.androidtv.connection.TLSManager
import com.mg.smart.tv.remote.control.androidtv.protocol.ProtobufMessage
import com.mg.smart.tv.remote.control.androidtv.util.Logger

class RemoteController(
    private val tlsManager: TLSManager,
) {
    fun sendKeyCode(keycode: Int): Boolean {
        return try {
            // Android TV remote protocol expects a short key inject for regular key taps.
            val message = ProtobufMessage.createKeycodeMessage(keycode)
            val result = tlsManager.sendData(message)
            if (result) {
                Logger.d("Keycode sent: $keycode")
            }
            result
        } catch (e: Exception) {
            Logger.e("Send keycode error: ${e.message}", e)
            false
        }
    }

    fun sendText(text: String, imeCounter: Int, fieldCounter: Int): Boolean {
        return try {
            val message = ProtobufMessage.createRemoteImeBatchEditMessage(
                text = text,
                imeCounter = imeCounter,
                fieldCounter = fieldCounter,
            )
            val result = tlsManager.sendData(message)
            if (result) {
                Logger.d("Text sent via IME batch edit: \"$text\"")
            }
            result
        } catch (e: Exception) {
            Logger.e("Send text error: ${e.message}", e)
            false
        }
    }

    fun destroy() {
        // TLS lifecycle owned by plugin
    }
}
