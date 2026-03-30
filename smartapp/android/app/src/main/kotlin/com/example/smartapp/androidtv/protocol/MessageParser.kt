package com.example.smartapp.androidtv.protocol

import java.io.ByteArrayInputStream

object MessageParser {
    private const val STATUS_OK = 200
    private const val FIELD_PAIRING_REQUEST_ACK = 11
    private const val FIELD_PAIRING_OPTION = 20
    private const val FIELD_PAIRING_CONFIGURATION_ACK = 31
    private const val FIELD_PAIRING_SECRET_ACK = 41
    private const val FIELD_REMOTE_CONFIGURE = 1
    private const val FIELD_REMOTE_SET_ACTIVE = 2
    private const val FIELD_REMOTE_PING_REQUEST = 8

    enum class PairingStep {
        REQUEST_ACK,
        OPTION,
        CONFIG_ACK,
        SECRET_ACK,
    }

    enum class RemoteMessageType {
        CONFIGURE,
        SET_ACTIVE,
        PING_REQUEST,
        OTHER,
    }

    fun parsePairingStep(data: ByteArray): PairingStep? {
        val parsed = parsePairingMessage(data) ?: return null
        if (parsed.status != STATUS_OK) return null
        return when (parsed.messageField) {
            FIELD_PAIRING_REQUEST_ACK -> PairingStep.REQUEST_ACK
            FIELD_PAIRING_OPTION -> PairingStep.OPTION
            FIELD_PAIRING_CONFIGURATION_ACK -> PairingStep.CONFIG_ACK
            FIELD_PAIRING_SECRET_ACK -> PairingStep.SECRET_ACK
            else -> null
        }
    }

    fun parseRemoteMessageType(data: ByteArray): RemoteMessageType {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07
                when (fieldNumber) {
                    FIELD_REMOTE_CONFIGURE -> return RemoteMessageType.CONFIGURE
                    FIELD_REMOTE_SET_ACTIVE -> return RemoteMessageType.SET_ACTIVE
                    FIELD_REMOTE_PING_REQUEST -> return RemoteMessageType.PING_REQUEST
                    else -> skipField(input, wireType)
                }
            }
            RemoteMessageType.OTHER
        } catch (_: Exception) {
            RemoteMessageType.OTHER
        }
    }

    fun parseRemotePingValue(data: ByteArray): Int? {
        return try {
            val input = ByteArrayInputStream(data)
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07
                if (fieldNumber == FIELD_REMOTE_PING_REQUEST && wireType == 2) {
                    val length = readVarint(input)
                    val nested = ByteArray(length)
                    input.read(nested)
                    return parsePingVal1(nested)
                }
                skipField(input, wireType)
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    private data class ParsedPairingMessage(val status: Int, val messageField: Int?)

    private fun parsePairingMessage(data: ByteArray): ParsedPairingMessage? {
        return try {
            val input = ByteArrayInputStream(data)
            var status = -1
            var messageField: Int? = null
            while (input.available() > 0) {
                val tag = readVarint(input)
                val fieldNumber = tag shr 3
                val wireType = tag and 0x07
                when {
                    fieldNumber == 2 && wireType == 0 -> status = readVarint(input)
                    fieldNumber in setOf(
                        FIELD_PAIRING_REQUEST_ACK,
                        FIELD_PAIRING_OPTION,
                        FIELD_PAIRING_CONFIGURATION_ACK,
                        FIELD_PAIRING_SECRET_ACK,
                    ) && wireType == 2 -> {
                        messageField = fieldNumber
                        val len = readVarint(input)
                        input.skip(len.toLong())
                    }
                    else -> skipField(input, wireType)
                }
            }
            if (status == -1) null else ParsedPairingMessage(status = status, messageField = messageField)
        } catch (_: Exception) {
            null
        }
    }

    private fun parsePingVal1(data: ByteArray): Int? {
        val input = ByteArrayInputStream(data)
        while (input.available() > 0) {
            val tag = readVarint(input)
            val fieldNumber = tag shr 3
            val wireType = tag and 0x07
            if (fieldNumber == 1 && wireType == 0) {
                return readVarint(input)
            }
            skipField(input, wireType)
        }
        return null
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
