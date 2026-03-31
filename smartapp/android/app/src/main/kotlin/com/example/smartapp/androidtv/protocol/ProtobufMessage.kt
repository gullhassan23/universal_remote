package com.mg.smart.tv.remote.control.androidtv.protocol

import android.os.Build
import java.io.ByteArrayOutputStream

object ProtobufMessage {
    private const val STATUS_OK = 200
    private const val PAIRING_PROTOCOL_VERSION = 2

    fun createPairingRequest(): ByteArray {
        return createPairingMessage(fieldNumber = 10) {
            val serviceName = "androidtvremote"
            val serviceNameBytes = serviceName.toByteArray()
            writeLengthDelimited(1, serviceNameBytes)
            val clientName = "SmartApp Remote"
            val clientNameBytes = clientName.toByteArray()
            writeLengthDelimited(2, clientNameBytes)
        }
    }

    fun createOptionsMessage(): ByteArray {
        return createPairingMessage(fieldNumber = 20) {
            // PairingOption.input_encodings[0]
            val encoding = ByteArrayOutputStream().apply {
                // ENCODING_TYPE_HEXADECIMAL
                writeVarintTo(this, 1 shl 3 or 0)
                writeVarintTo(this, 3)
                writeVarintTo(this, 2 shl 3 or 0)
                writeVarintTo(this, 6)
            }.toByteArray()
            writeLengthDelimited(1, encoding)
            // ROLE_TYPE_INPUT
            writeVarintTo(this, 3 shl 3 or 0)
            writeVarintTo(this, 1)
        }
    }

    fun createConfigurationMessage(): ByteArray {
        return createPairingMessage(fieldNumber = 30) {
            val encoding = ByteArrayOutputStream().apply {
                writeVarintTo(this, 1 shl 3 or 0)
                writeVarintTo(this, 3) // ENCODING_TYPE_HEXADECIMAL
                writeVarintTo(this, 2 shl 3 or 0)
                writeVarintTo(this, 6)
            }.toByteArray()
            writeLengthDelimited(1, encoding)
            // ROLE_TYPE_INPUT
            writeVarintTo(this, 2 shl 3 or 0)
            writeVarintTo(this, 1)
        }
    }

    fun createSecretMessage(secretBytes: ByteArray): ByteArray {
        return createPairingMessage(fieldNumber = 40) {
            writeLengthDelimited(1, secretBytes)
        }
    }

    fun createKeycodeMessage(keycode: Int): ByteArray {
        val keyInject = ByteArrayOutputStream().apply {
            // RemoteKeyInject.key_code
            writeVarintTo(this, 1 shl 3 or 0)
            writeVarintTo(this, keycode)
            // RemoteKeyInject.direction = SHORT (3)
            writeVarintTo(this, 2 shl 3 or 0)
            writeVarintTo(this, 3)
        }.toByteArray()
        return createRemoteMessage(fieldNumber = 10, payload = keyInject)
    }

    fun createRemoteConfigureMessage(): ByteArray {
        val deviceInfo = ByteArrayOutputStream().apply {
            writeStringField(1, Build.MODEL ?: "Android")
            writeStringField(2, Build.MANUFACTURER ?: "Android")
            writeVarintTo(this, 3 shl 3 or 0)
            writeVarintTo(this, 1)
            writeStringField(4, "1")
            writeStringField(5, "androidtv-remote")
            writeStringField(6, "1.0.0")
        }.toByteArray()
        val configure = ByteArrayOutputStream().apply {
            writeVarintTo(this, 1 shl 3 or 0)
            writeVarintTo(this, 622)
            writeLengthDelimited(2, deviceInfo)
        }.toByteArray()
        return createRemoteMessage(fieldNumber = 1, payload = configure)
    }

    fun createRemoteSetActiveMessage(active: Int = 622): ByteArray {
        val payload = ByteArrayOutputStream().apply {
            writeVarintTo(this, 1 shl 3 or 0)
            writeVarintTo(this, active)
        }.toByteArray()
        return createRemoteMessage(fieldNumber = 2, payload = payload)
    }

    fun createRemotePingResponseMessage(value: Int): ByteArray {
        val payload = ByteArrayOutputStream().apply {
            writeVarintTo(this, 1 shl 3 or 0)
            writeVarintTo(this, value)
        }.toByteArray()
        return createRemoteMessage(fieldNumber = 9, payload = payload)
    }

    private fun createPairingMessage(
        fieldNumber: Int,
        payloadWriter: ByteArrayOutputStream.() -> Unit,
    ): ByteArray {
        val payload = ByteArrayOutputStream().apply(payloadWriter).toByteArray()
        val out = ByteArrayOutputStream()
        writeVarintTo(out, 1 shl 3 or 0)
        writeVarintTo(out, PAIRING_PROTOCOL_VERSION)
        writeVarintTo(out, 2 shl 3 or 0)
        writeVarintTo(out, STATUS_OK)
        writeVarintTo(out, fieldNumber shl 3 or 2)
        writeVarintTo(out, payload.size)
        out.write(payload)
        return out.toByteArray()
    }

    private fun createRemoteMessage(fieldNumber: Int, payload: ByteArray): ByteArray {
        val out = ByteArrayOutputStream()
        writeVarintTo(out, fieldNumber shl 3 or 2)
        writeVarintTo(out, payload.size)
        out.write(payload)
        return out.toByteArray()
    }
}

private fun ByteArrayOutputStream.writeLengthDelimited(fieldNumber: Int, bytes: ByteArray) {
    writeVarintTo(this, fieldNumber shl 3 or 2)
    writeVarintTo(this, bytes.size)
    write(bytes)
}

private fun ByteArrayOutputStream.writeStringField(fieldNumber: Int, value: String) {
    writeLengthDelimited(fieldNumber, value.toByteArray())
}

private fun writeVarintTo(out: ByteArrayOutputStream, value: Int) {
    var v = value
    while ((v and 0xFFFFFF80.toInt()) != 0) {
        out.write((v and 0x7F) or 0x80)
        v = v ushr 7
    }
    out.write(v and 0x7F)
}
