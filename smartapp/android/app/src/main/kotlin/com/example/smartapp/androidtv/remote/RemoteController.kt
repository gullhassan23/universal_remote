package com.FutureDialLabs.tv.remote.universal.control.androidtv.remote

import com.FutureDialLabs.tv.remote.universal.control.androidtv.connection.TLSManager
import com.FutureDialLabs.tv.remote.universal.control.androidtv.protocol.ProtobufMessage
import com.FutureDialLabs.tv.remote.universal.control.androidtv.util.Logger

class RemoteController(
    private val tlsManager: TLSManager,
) {
    private companion object {
        // Android KeyEvent.KEYCODE_A .. KEYCODE_Z
        const val KEYCODE_A = 29
        const val KEYCODE_Z = 54
        const val KEYCODE_POWER = 26
        const val KEYCODE_TV_POWER = 116
    }

    fun sendKeyCode(keycode: Int): Boolean {
        return try {
            val isPowerKey = keycode == KEYCODE_POWER || keycode == KEYCODE_TV_POWER
            if (isPowerKey) {
                // Some OEM TVs accept power reliably only when a full DOWN+UP is sent.
                val downUpFirst = sendDownUpPress(keycode)
                if (downUpFirst) {
                    Logger.d("Power keycode sent via DOWN+UP: $keycode")
                    return true
                }
                // Fallback to short press for devices that reject down/up framing.
                val shortFallback = sendShortPress(keycode)
                if (shortFallback) {
                    Logger.d("Power keycode sent via SHORT fallback: $keycode")
                }
                return shortFallback
            }

            // Android TV remote protocol expects a short key inject for regular key taps.
            val result = sendShortPress(keycode)
            val shouldTryDownUpFallback =
                keycode in KEYCODE_A..KEYCODE_Z ||
                    isPowerKey
            if (!result && shouldTryDownUpFallback) {
                // Some TV OEMs ignore SHORT for letter/power keys; DOWN+UP is more reliable.
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
