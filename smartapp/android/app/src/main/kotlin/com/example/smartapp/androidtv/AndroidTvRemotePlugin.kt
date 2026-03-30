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
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import java.security.MessageDigest
import java.security.interfaces.RSAPublicKey

class AndroidTvRemotePlugin(private val context: Context) {

    private lateinit var methodChannel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var certificateManager: CertificateManager? = null
    private var tlsPairing: TLSManager? = null
    private var tlsRemote: TLSManager? = null
    private var remoteController: RemoteController? = null
    private var remoteReaderJob: Job? = null
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
                val derExists = certResult.derPath.isNotBlank() && java.io.File(certResult.derPath).exists()
                val pkcs12Exists = certResult.pkcs12Path.isNotBlank() && java.io.File(certResult.pkcs12Path).exists()
                if (!derExists || !pkcs12Exists) {
                    val details = "Certificate files missing after generation: derExists=$derExists pkcs12Exists=$pkcs12Exists derPath=${certResult.derPath} pkcs12Path=${certResult.pkcs12Path}"
                    mainHandler.post {
                        result.error("CERT_ERROR", details, null)
                    }
                    return
                }
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

        if (!awaitPairingStep(MessageParser.PairingStep.REQUEST_ACK, 8)) {
            Logger.e("connectAndPair: pairing request ACK not received")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        if (!tlsPairing!!.sendData(ProtobufMessage.createOptionsMessage())) {
            Logger.e("connectAndPair: failed to send options message")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        if (!awaitPairingStep(MessageParser.PairingStep.OPTION, 8)) {
            Logger.e("connectAndPair: pairing option from TV not received")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        if (!tlsPairing!!.sendData(ProtobufMessage.createConfigurationMessage())) {
            Logger.e("connectAndPair: failed to send configuration message")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        if (!awaitPairingStep(MessageParser.PairingStep.CONFIG_ACK, 8)) {
            Logger.e("connectAndPair: configuration ACK not received (PIN screen not triggered)")
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

        val secretBytes = buildPairingSecret(pin)
        if (secretBytes == null) {
            Logger.e("connectAndPair: invalid code format or failed to create pairing secret")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        val secret = ProtobufMessage.createSecretMessage(secretBytes)
        if (!tlsPairing!!.sendData(secret)) {
            Logger.e("connectAndPair: failed to send secret message")
            tlsPairing?.disconnect()
            tlsPairing = null
            mainHandler.post { result.success(false) }
            return
        }

        val paired = awaitPairingStep(MessageParser.PairingStep.SECRET_ACK, 12)

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
        startRemoteReaderLoop()
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
        remoteReaderJob?.cancel()
        remoteReaderJob = null
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

    private fun startRemoteReaderLoop() {
        remoteReaderJob?.cancel()
        val remote = tlsRemote ?: return
        remoteReaderJob = scope.launch {
            while (isActive && remote.isConnected()) {
                val msg = remote.receiveData() ?: continue
                when (MessageParser.parseRemoteMessageType(msg)) {
                    MessageParser.RemoteMessageType.CONFIGURE -> {
                        remote.sendData(ProtobufMessage.createRemoteConfigureMessage())
                    }
                    MessageParser.RemoteMessageType.SET_ACTIVE -> {
                        remote.sendData(ProtobufMessage.createRemoteSetActiveMessage())
                    }
                    MessageParser.RemoteMessageType.PING_REQUEST -> {
                        val ping = MessageParser.parseRemotePingValue(msg)
                        if (ping != null) {
                            remote.sendData(ProtobufMessage.createRemotePingResponseMessage(ping))
                        }
                    }
                    MessageParser.RemoteMessageType.OTHER -> Unit
                }
            }
        }
    }

    private suspend fun awaitPairingStep(
        expected: MessageParser.PairingStep,
        tries: Int,
    ): Boolean {
        repeat(tries) {
            val resp = tlsPairing?.receiveData() ?: return@repeat
            val step = MessageParser.parsePairingStep(resp)
            if (step == expected) return true
            // Small yield before reading next frame.
            delay(30)
        }
        return false
    }

    private fun buildPairingSecret(pinInput: String): ByteArray? {
        val pinHex = normalizeHexPin(pinInput) ?: return null
        val codeBytes = hexToBytes(pinHex) ?: return null
        if (codeBytes.isEmpty()) return null
        val clientCert = tlsPairing?.getLocalCertificate() ?: return null
        val serverCert = tlsPairing?.getPeerCertificate() ?: return null
        val clientKey = clientCert.publicKey as? RSAPublicKey ?: return null
        val serverKey = serverCert.publicKey as? RSAPublicKey ?: return null

        val digest = MessageDigest.getInstance("SHA-256")
        digest.update(unsignedBigIntBytes(clientKey.modulus))
        digest.update(unsignedBigIntBytes(clientKey.publicExponent))
        digest.update(unsignedBigIntBytes(serverKey.modulus))
        digest.update(unsignedBigIntBytes(serverKey.publicExponent))
        digest.update(hexToBytes(pinHex.substring(2)) ?: return null)

        val hash = digest.digest()
        if (hash.isEmpty()) return null
        return if (hash[0] == codeBytes[0]) hash else null
    }

    private fun normalizeHexPin(input: String): String? {
        val value = input.trim().replace(" ", "").replace("-", "").uppercase()
        if (value.length != 6) return null
        return if (value.all { it in '0'..'9' || it in 'A'..'F' }) value else null
    }

    private fun hexToBytes(value: String): ByteArray? {
        if (value.length % 2 != 0) return null
        return try {
            ByteArray(value.length / 2) { idx ->
                value.substring(idx * 2, idx * 2 + 2).toInt(16).toByte()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun unsignedBigIntBytes(value: java.math.BigInteger): ByteArray {
        val bytes = value.toByteArray()
        return if (bytes.size > 1 && bytes[0].toInt() == 0) bytes.copyOfRange(1, bytes.size) else bytes
    }
}
