package com.example.smartapp.androidtv.remote

import com.example.smartapp.androidtv.connection.TLSManager
import com.example.smartapp.androidtv.protocol.ProtobufMessage
import com.example.smartapp.androidtv.util.Logger

class RemoteController(
    private val tlsManager: TLSManager,
) {

    fun sendKeyCode(keycode: Int): Boolean {
        return try {
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

    fun destroy() {
        // TLS lifecycle owned by plugin
    }
}
