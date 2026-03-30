package com.example.smartapp.androidtv.protocol

import java.io.ByteArrayOutputStream

object ProtobufMessage {
    private const val PAIRING_REQUEST_TYPE = 1
    private const val SECRET_MESSAGE_TYPE = 2
    private const val KEYCODE_MESSAGE_TYPE = 3

    fun createPairingRequest(): ByteArray {
        val out = ByteArrayOutputStream()
        writeVarint(out, 1 shl 3 or 0)
        writeVarint(out, PAIRING_REQUEST_TYPE)
        val clientName = "android_tv_remote"
        val nameBytes = clientName.toByteArray()
        writeVarint(out, 2 shl 3 or 2)
        writeVarint(out, nameBytes.size)
        out.write(nameBytes)
        return out.toByteArray()
    }

    fun createSecretMessage(pin: String): ByteArray {
        val out = ByteArrayOutputStream()
        writeVarint(out, 1 shl 3 or 0)
        writeVarint(out, SECRET_MESSAGE_TYPE)
        val secretBytes = pin.toByteArray()
        writeVarint(out, 2 shl 3 or 2)
        writeVarint(out, secretBytes.size)
        out.write(secretBytes)
        return out.toByteArray()
    }

    fun createKeycodeMessage(keycode: Int): ByteArray {
        val out = ByteArrayOutputStream()
        writeVarint(out, 1 shl 3 or 0)
        writeVarint(out, KEYCODE_MESSAGE_TYPE)
        writeVarint(out, 2 shl 3 or 0)
        writeVarint(out, keycode)
        return out.toByteArray()
    }

    private fun writeVarint(out: ByteArrayOutputStream, value: Int) {
        var v = value
        while ((v and 0xFFFFFF80.toInt()) != 0) {
            out.write((v and 0x7F) or 0x80)
            v = v ushr 7
        }
        out.write(v and 0x7F)
    }
}
