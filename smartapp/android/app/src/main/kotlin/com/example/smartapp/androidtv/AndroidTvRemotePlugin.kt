package com.example.smartapp.androidtv

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import com.example.smartapp.androidtv.cert.CertificateFilesResult
import com.example.smartapp.androidtv.cert.CertificateGenerator
import com.example.smartapp.androidtv.cert.CertificateManager
import com.example.smartapp.androidtv.connection.TLSManager
import com.example.smartapp.androidtv.protocol.MessageParser
import com.example.smartapp.androidtv.protocol.ProtobufMessage
import com.example.smartapp.androidtv.remote.RemoteController
import com.example.smartapp.androidtv.util.Constants
import com.example.smartapp.androidtv.util.Logger
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

class AndroidTvRemotePlugin(private val context: Context) {

    private lateinit var methodChannel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var certificateManager: CertificateManager? = null
    private var tlsPairing: TLSManager? = null
    private var tlsRemote: TLSManager? = null
    private var remoteController: RemoteController? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    fun registerWith(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "generateCertificates" -> scope.launch {
                    generateCertificates(result)
                }
                "connectAndPair" -> scope.launch {
                    connectAndPair(
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any?>(),
                        result,
                    )
                }
                "sendKeyCode" -> scope.launch {
                    sendKeyCode(
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any?>(),
                        result,
                    )
                }
                "disconnect" -> scope.launch {
                    disconnectSession(result)
                }
                "acquireMulticastLock" -> scope.launch {
                    acquireMulticastLock(result)
                }
                "releaseMulticastLock" -> scope.launch {
                    releaseMulticastLock(result)
                }
                else -> mainHandler.post { result.notImplemented() }
            }
        }
    }

    private fun acquireMulticastLock(result: MethodChannel.Result) {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            if (wifiManager == null) {
                Logger.e("acquireMulticastLock: WifiManager unavailable")
                mainHandler.post { result.success(false) }
                return
            }
            if (multicastLock == null) {
                multicastLock = wifiManager.createMulticastLock("android_tv_mdns_lock").apply {
                    setReferenceCounted(true)
                }
            }
            if (multicastLock?.isHeld != true) {
                multicastLock?.acquire()
            }
            mainHandler.post { result.success(true) }
        } catch (e: Exception) {
            Logger.e("acquireMulticastLock: ${e.message}", e)
            mainHandler.post { result.success(false) }
        }
    }

    private fun releaseMulticastLock(result: MethodChannel.Result) {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
            mainHandler.post { result.success(true) }
        } catch (e: Exception) {
            Logger.e("releaseMulticastLock: ${e.message}", e)
            mainHandler.post { result.success(false) }
        }
    }

    private fun generateCertificates(result: MethodChannel.Result) {
        try {
            val generator = CertificateGenerator()
            val certResult: CertificateFilesResult = generator.generateCertificates(context)
            certificateManager = CertificateManager()
            if (certResult.success) {
                mainHandler.post {
                    result.success(
                        mapOf(
                            "success" to true,
                            "derPath" to certResult.derPath,
                            "pkcs12Path" to certResult.pkcs12Path,
                        ),
                    )
                }
            } else {
                mainHandler.post {
                    result.error("CERT_ERROR", certResult.error, null)
                }
            }
        } catch (e: Exception) {
            mainHandler.post {
                result.error("CERT_ERROR", e.message, null)
            }
        }
    }

    private suspend fun connectAndPair(arguments: Map<*, *>, result: MethodChannel.Result) {
        val host = arguments["host"] as? String
        val pkcs12Path = arguments["pkcs12Path"] as? String
        val pairingPort = (arguments["pairingPort"] as? Number)?.toInt() ?: Constants.PORT_PAIRING
        val remotePort = (arguments["remotePort"] as? Number)?.toInt() ?: Constants.PORT_REMOTE
        if (host.isNullOrBlank() || pkcs12Path.isNullOrBlank()) {
            Logger.e("connectAndPair: invalid args host=$host pkcs12PathBlank=${pkcs12Path.isNullOrBlank()}")
            mainHandler.post { result.error("ARG", "host and pkcs12Path required", null) }
            return
        }
        val cm = certificateManager ?: CertificateManager().also { certificateManager = it }
        val sslContext = cm.createSSLContext(pkcs12Path) ?: run {
            Logger.e("connectAndPair: SSL context failed for host=$host path=$pkcs12Path")
            mainHandler.post { result.error("SSL", "SSL context failed", null) }
            return
        }

        disconnectTlsOnly()

        tlsPairing = TLSManager(sslContext)
        if (tlsPairing!!.connect(host, pairingPort) != true) {
            Logger.e("connectAndPair: failed to connect pairing socket host=$host port=$pairingPort")
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        val pairingReq = ProtobufMessage.createPairingRequest()
        if (!tlsPairing!!.sendData(pairingReq)) {
            Logger.e("connectAndPair: failed to send pairing request")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        val pin = requestPinFromFlutter()
        if (pin.isNullOrBlank()) {
            Logger.e("Pairing cancelled or empty PIN")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        val secret = ProtobufMessage.createSecretMessage(pin)
        if (!tlsPairing!!.sendData(secret)) {
            Logger.e("connectAndPair: failed to send secret message")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        var paired = false
        repeat(12) {
            val resp = tlsPairing!!.receiveData() ?: return@repeat
            if (MessageParser.isPairingSuccessful(resp)) {
                paired = true
                return@repeat
            }
        }

        tlsPairing?.disconnect()
        tlsPairing = null

        if (!paired) {
            Logger.e("Pairing did not complete successfully")
            mainHandler.post { result.success(false) }
            return
        }

        tlsRemote = TLSManager(sslContext)
        if (tlsRemote!!.connect(host, remotePort) != true) {
            Logger.e("connectAndPair: failed to connect remote socket host=$host port=$remotePort")
            tlsRemote = null
            mainHandler.post { result.success(false) }
            return
        }

        remoteController = RemoteController(tlsRemote!!)
        mainHandler.post { result.success(true) }
    }

    private suspend fun requestPinFromFlutter(): String? = suspendCancellableCoroutine { cont ->
        mainHandler.post {
            methodChannel.invokeMethod(
                "requestPin",
                null,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        cont.resume(result as? String)
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                        cont.resume(null)
                    }

                    override fun notImplemented() {
                        cont.resume(null)
                    }
                },
            )
        }
    }

    private fun sendKeyCode(arguments: Map<*, *>, result: MethodChannel.Result) {
        val code = arguments["keyCode"] as? Int
        if (code == null) {
            mainHandler.post { result.success(false) }
            return
        }
        val ok = remoteController?.sendKeyCode(code) == true
        mainHandler.post { result.success(ok) }
    }

    private fun disconnectSession(result: MethodChannel.Result) {
        try {
            disconnectTlsOnly()
            mainHandler.post { result.success(true) }
        } catch (e: Exception) {
            mainHandler.post { result.error("DISC", e.message, null) }
        }
    }

    private fun disconnectTlsOnly() {
        remoteController?.destroy()
        remoteController = null
        tlsRemote?.disconnect()
        tlsRemote = null
        tlsPairing?.disconnect()
        tlsPairing = null
    }

    fun destroy() {
        try {
            disconnectTlsOnly()
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
            multicastLock = null
        } catch (e: Exception) {
            Logger.e("destroy: ${e.message}", e)
        }
    }

    companion object {
        private const val CHANNEL = "com.example.smartapp/android_tv_remote"
    }
}
