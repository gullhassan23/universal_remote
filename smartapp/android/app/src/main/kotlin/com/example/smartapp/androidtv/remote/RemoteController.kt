package com.mg.smart.tv.remote.control.androidtv.remote

import com.mg.smart.tv.remote.control.androidtv.connection.TLSManager
import com.mg.smart.tv.remote.control.androidtv.protocol.ProtobufMessage
import com.mg.smart.tv.remote.control.androidtv.util.Logger

class RemoteController(
    private val tlsManager: TLSManager,
) {
    private companion object {
        // Android KeyEvent.KEYCODE_A .. KEYCODE_Z
        const val KEYCODE_A = 29
        const val KEYCODE_Z = 54
    }

    fun sendKeyCode(keycode: Int): Boolean {
        return try {
            // Android TV remote protocol expects a short key inject for regular key taps.
            val result = sendShortPress(keycode)
            if (!result && keycode in KEYCODE_A..KEYCODE_Z) {
                // Some TV OEMs ignore letter keys on SHORT; DOWN+UP is more reliable.
                val downUpResult = sendDownUpPress(keycode)
                if (downUpResult) {
                    Logger.d("Keycode sent via DOWN+UP fallback: $keycode")
                }
                return downUpResult
            }
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
            var message = ProtobufMessage.createRemoteImeBatchEditMessage(
                text = text,
                imeCounter = imeCounter,
                fieldCounter = fieldCounter,
            )
            var result = tlsManager.sendData(message)
            if (!result) {
                // Compatibility fallback for TVs that only accept legacy cursor index.
                message = ProtobufMessage.createRemoteImeBatchEditMessage(
                    text = text,
                    imeCounter = imeCounter,
                    fieldCounter = fieldCounter,
                    useLegacyCursor = true,
                )
                result = tlsManager.sendData(message)
            }
            if (result) {
                Logger.d("Text sent via IME batch edit: \"$text\"")
            }
            result
        } catch (e: Exception) {
            Logger.e("Send text error: ${e.message}", e)
            false
        }
    }

    fun sendAppLinkLaunch(appLink: String): Boolean {
        return try {
            val message = ProtobufMessage.createRemoteAppLinkLaunchMessage(appLink)
            val result = tlsManager.sendData(message)
            Logger.d("App link launch sent: appLink=$appLink result=$result")
            result
        } catch (e: Exception) {
            Logger.e("Send app link launch error: ${e.message}", e)
            false
        }
    }

    fun destroy() {
        // TLS lifecycle owned by plugin
    }

    private fun sendShortPress(keycode: Int): Boolean {
        val message = ProtobufMessage.createKeycodeMessage(keycode)
        return tlsManager.sendData(message)
    }

    private fun sendDownUpPress(keycode: Int): Boolean {
        val down = tlsManager.sendData(ProtobufMessage.createKeycodeDownMessage(keycode))
        if (!down) return false
        return tlsManager.sendData(ProtobufMessage.createKeycodeUpMessage(keycode))
    }
}
