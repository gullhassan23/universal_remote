package com.mg.smart.tv.remote.control.androidtv.remote

import com.mg.smart.tv.remote.control.androidtv.connection.TLSManager
import com.mg.smart.tv.remote.control.androidtv.protocol.ProtobufMessage
import com.mg.smart.tv.remote.control.androidtv.util.Logger

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
