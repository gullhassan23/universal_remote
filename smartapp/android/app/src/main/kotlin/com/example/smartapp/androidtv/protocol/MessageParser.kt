package com.example.smartapp.androidtv.protocol

import java.io.ByteArrayInputStream

object MessageParser {

    fun isPairingSuccessful(data: ByteArray): Boolean {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07
                when {
                    fieldNumber == 1 && wireType == 0 -> {
                        val status = readVarint(input)
                        return status == 1
                    }
                    else -> skipField(input, wireType)
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun readVarint(input: ByteArrayInputStream): Int {
        var result = 0
        var shift = 0
        while (true) {
            val byte = input.read()
            if (byte == -1) break
            result = result or ((byte and 0x7F) shl shift)
            if ((byte and 0x80) == 0) break
            shift += 7
        }
        return result
    }

    private fun skipField(input: ByteArrayInputStream, wireType: Int) {
        when (wireType) {
            0 -> readVarint(input)
            1 -> input.skip(8)
            2 -> {
                val length = readVarint(input)
                input.skip(length.toLong())
            }
            5 -> input.skip(4)
        }
    }
}
