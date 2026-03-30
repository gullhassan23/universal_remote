package com.example.smartapp.androidtv.connection

import android.util.Log
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.IOException
import javax.net.ssl.SSLSocket

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
                it.writeInt(data.size)
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
                val length = it.readInt()
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

    companion object {
        private const val TAG = "TLSManager"
    }
}
