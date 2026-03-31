package com.mg.smart.tv.remote.control.androidtv.connection

import android.util.Log
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.IOException
import javax.net.ssl.SSLSocket
import java.security.cert.X509Certificate

class TLSManager(
    private val sslContext: javax.net.ssl.SSLContext
) {

    private var socket: SSLSocket? = null
    private var inputStream: DataInputStream? = null
    private var outputStream: DataOutputStream? = null

    @Throws(IOException::class)
    fun connect(host: String, port: Int): Boolean {
        return try {
            val socketFactory = sslContext.socketFactory
            socket = socketFactory.createSocket(host, port) as SSLSocket
            socket?.apply {
                enabledProtocols = arrayOf("TLSv1.2", "TLSv1.3")
                soTimeout = 3000
                startHandshake()
            }
            inputStream = DataInputStream(socket?.inputStream)
            outputStream = DataOutputStream(socket?.outputStream)
            Log.d(TAG, "TLS connection established with $host:$port")
            true
        } catch (e: Exception) {
            Log.e(TAG, "TLS connection failed: ${e.message}")
            disconnect()
            false
        }
    }

    fun sendData(data: ByteArray): Boolean {
        return try {
            outputStream?.let {
                writeVarint(it, data.size)
                it.write(data)
                it.flush()
                true
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Send failed: ${e.message}")
            false
        }
    }

    fun receiveData(): ByteArray? {
        return try {
            inputStream?.let {
                val length = readVarint(it)
                if (length <= 0 || length > 65536) return null
                val data = ByteArray(length)
                it.readFully(data)
                data
            }
        } catch (e: java.io.EOFException) {
            Log.d(TAG, "Connection closed by peer")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Receive failed: ${e.message}")
            null
        }
    }

    fun disconnect() {
        try {
            inputStream?.close()
            outputStream?.close()
            socket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Disconnect error: ${e.message}")
        }
        socket = null
        inputStream = null
        outputStream = null
    }

    fun isConnected(): Boolean = socket?.isConnected == true

    fun getLocalCertificate(): X509Certificate? {
        return try {
            val cert = socket?.session?.localCertificates?.firstOrNull()
            cert as? X509Certificate
        } catch (_: Exception) {
            null
        }
    }

    fun getPeerCertificate(): X509Certificate? {
        return try {
            val cert = socket?.session?.peerCertificates?.firstOrNull()
            cert as? X509Certificate
        } catch (_: Exception) {
            null
        }
    }

    private fun writeVarint(out: DataOutputStream, value: Int) {
        var v = value
        while ((v and 0xFFFFFF80.toInt()) != 0) {
            out.writeByte((v and 0x7F) or 0x80)
            v = v ushr 7
        }
        out.writeByte(v and 0x7F)
    }

    private fun readVarint(input: DataInputStream): Int {
        var result = 0
        var shift = 0
        while (shift < 35) {
            val b = input.readUnsignedByte()
            result = result or ((b and 0x7F) shl shift)
            if ((b and 0x80) == 0) return result
            shift += 7
        }
        throw IOException("Invalid varint length")
    }

    companion object {
        private const val TAG = "TLSManager"
    }
}
