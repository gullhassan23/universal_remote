package com.FutureDialLabs.tv.remote.universal.control.androidtv

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import com.FutureDialLabs.tv.remote.universal.control.androidtv.cert.CertificateFilesResult
import com.FutureDialLabs.tv.remote.universal.control.androidtv.cert.CertificateGenerator
import com.FutureDialLabs.tv.remote.universal.control.androidtv.cert.CertificateManager
import com.FutureDialLabs.tv.remote.universal.control.androidtv.connection.TLSManager
import com.FutureDialLabs.tv.remote.universal.control.androidtv.protocol.MessageParser
import com.FutureDialLabs.tv.remote.universal.control.androidtv.protocol.ProtobufMessage
import com.FutureDialLabs.tv.remote.universal.control.androidtv.remote.RemoteController
import com.FutureDialLabs.tv.remote.universal.control.androidtv.util.Constants
import com.FutureDialLabs.tv.remote.universal.control.androidtv.util.Logger
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
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
import java.util.concurrent.atomic.AtomicBoolean

class AndroidTvRemotePlugin(private val context: Context) {
    private companion object {
        const val KEYCODE_HOME = 3
        const val KEYCODE_ENTER = 23
        const val KEYCODE_DPAD_DOWN = 20
        const val KEYCODE_SEARCH = 84
        const val KEYCODE_ASSIST = 219
        const val CHANNEL = "com.example.smartapp/android_tv_remote"

        /** Move focus off the top "favourites" row before Enter on some launchers (e.g. Xiaomi). */
        const val LAUNCH_APP_FOCUS_NUDGE_STEPS = 3
    }

    private lateinit var methodChannel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var certificateManager: CertificateManager? = null
    private var tlsPairing: TLSManager? = null
    private var tlsRemote: TLSManager? = null
    private var remoteController: RemoteController? = null
    private var remoteReaderJob: Job? = null
    private val remoteReady = AtomicBoolean(false)
    private val imeCounter = java.util.concurrent.atomic.AtomicInteger(0)
    private val imeFieldCounter = java.util.concurrent.atomic.AtomicInteger(0)
    private val lastImeUpdateAtMs = java.util.concurrent.atomic.AtomicLong(0L)
    private var multicastLock: WifiManager.MulticastLock? = null

    fun registerWith(flutterEngine: FlutterEngine) {
        AndroidTvKeepAliveRegistry.plugin = this
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
                "sendText" -> scope.launch {
                    sendText(
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any?>(),
                        result,
                    )
                }
                "sendTextPrepared" -> scope.launch {
                    sendTextPrepared(
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any?>(),
                        result,
                    )
                }
                "launchApp" -> scope.launch {
                    launchApp(
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any?>(),
                        result,
                    )
                }
                "openUrlOnTv" -> scope.launch {
                    openUrlOnTv(
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
                "isRemoteSessionAlive" -> mainHandler.post {
                    result.success(evaluateRemoteSessionAlive())
                }
                "startTerminationKeepAlive" -> scope.launch {
                    startTerminationKeepAlive(
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any?>(),
                        result,
                    )
                }
                "startBackgroundKeepAlive" -> scope.launch {
                    startBackgroundKeepAlive(
                        call.arguments as? Map<*, *> ?: emptyMap<String, Any?>(),
                        result,
                    )
                }
                "stopBackgroundKeepAlive" -> mainHandler.post {
                    stopBackgroundKeepAlive(result)
                }
                "adoptKeepAliveSessionIfAvailable" -> mainHandler.post {
                    adoptKeepAliveSessionIfAvailable(result)
                }
                "getKeepAliveStatus" -> mainHandler.post {
                    getKeepAliveStatus(result)
                }
                else -> mainHandler.post { result.notImplemented() }
            }
        }
    }

    /** True when remote TLS, reader job, and handshake-ready flag all look healthy. */
    private fun evaluateRemoteSessionAlive(): Boolean {
        val remote = tlsRemote ?: return false
        if (!remote.isConnected()) return false
        if (!remoteReady.get()) return false
        val job = remoteReaderJob ?: return false
        return job.isActive
    }

    private fun notifyDartRemoteSessionEnded(reason: String) {
        if (!::methodChannel.isInitialized) return
        try {
            methodChannel.invokeMethod(
                "onRemoteSessionEnded",
                mapOf("reason" to reason),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {}
                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                    }

                    override fun notImplemented() {}
                },
            )
        } catch (e: Exception) {
            Logger.e("notifyDartRemoteSessionEnded: ${e.message}", e)
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

        disconnectTlsOnly(skipReaderJobCancel = false)

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
        val ready = waitForRemoteReady()
        if (!ready) {
            Logger.e("connectAndPair: remote_not_ready_timeout host=$host port=$remotePort")
            disconnectTlsOnly()
            mainHandler.post { result.success(false) }
            return
        }
        Logger.d("connectAndPair: remote channel ready host=$host port=$remotePort")
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
        if (!remoteReady.get()) {
            waitForRemoteReady()
        }
        var ok = remoteController?.sendKeyCode(code) == true
        if (!ok && remoteReady.get()) {
            // One quick retry handles occasional first-frame race conditions.
            Thread.sleep(40)
            ok = remoteController?.sendKeyCode(code) == true
        }
        Logger.d(
            "sendKeyCode: code=$code ok=$ok remoteReady=${remoteReady.get()} " +
                "imeCounter=${imeCounter.get()} fieldCounter=${imeFieldCounter.get()}",
        )
        mainHandler.post { result.success(ok) }
    }

    private fun sendText(arguments: Map<*, *>, result: MethodChannel.Result) {
        val text = arguments["text"] as? String
        if (text.isNullOrEmpty()) {
            mainHandler.post { result.success(false) }
            return
        }
        if (!remoteReady.get()) {
            waitForRemoteReady()
        }
        val ok = sendTextWithCounterFallback(text)
        mainHandler.post { result.success(ok) }
    }

    private suspend fun sendTextPrepared(arguments: Map<*, *>, result: MethodChannel.Result) {
        val text = arguments["text"] as? String
        val autoPrepareInputContext = arguments["autoPrepareInputContext"] as? Boolean ?: true
        if (text.isNullOrBlank()) {
            mainHandler.post { result.success(false) }
            return
        }
        if (!remoteReady.get()) {
            waitForRemoteReady()
        }
        val remote = remoteController
        if (remote == null || !remoteReady.get()) {
            Logger.e(
                "sendTextPrepared: remote unavailable " +
                    "remoteNull=${remote == null} remoteReady=${remoteReady.get()}",
            )
            mainHandler.post { result.success(false) }
            return
        }

        Logger.d(
            "sendTextPrepared: start length=${text.length} " +
                "autoPrepare=$autoPrepareInputContext " +
                "imeCounter=${imeCounter.get()} fieldCounter=${imeFieldCounter.get()} " +
                "imeFresh=${isImeContextFresh()}",
        )

        if (autoPrepareInputContext && !isImeContextFresh()) {
            Logger.d("sendTextPrepared: stale IME context, preparing before first send")
            ensureInputContext(remote)
        }

        var sent = sendTextWithCounterFallback(text)
        Logger.d("sendTextPrepared: directOrPrepreparedSend sent=$sent")
        if (sent) {
            mainHandler.post { result.success(true) }
            return
        }
        if (!autoPrepareInputContext) {
            mainHandler.post { result.success(false) }
            return
        }

        val prepared = ensureInputContext(remote)
        Logger.d("sendTextPrepared: ensureInputContext prepared=$prepared")
        if (!prepared) {
            mainHandler.post { result.success(false) }
            return
        }

        repeat(2) { retry ->
            if (retry > 0) {
                Thread.sleep(55)
            }
            sent = sendTextWithCounterFallback(text)
            Logger.d("sendTextPrepared: postPrepareRetry=$retry sent=$sent")
            if (sent) {
                mainHandler.post { result.success(true) }
                return
            }
        }
        mainHandler.post { result.success(false) }
    }

    private fun sendTextWithCounterFallback(text: String): Boolean {
        val remote = remoteController ?: return false
        val currentIme = imeCounter.get()
        val currentField = imeFieldCounter.get()
        val attempts =
            listOf(
                currentIme to currentField,
                (currentIme + 1) to currentField,
                currentIme to (currentField + 1),
                (currentIme + 1) to (currentField + 1),
                0 to 0,
                1 to 0,
                0 to 1,
            ).distinct()

        for ((attemptIdx, pair) in attempts.withIndex()) {
            val ime = pair.first
            val field = pair.second
            val sent = remote.sendText(text = text, imeCounter = ime, fieldCounter = field)
            Logger.d(
                "sendText: attempt=$attemptIdx ime=$ime field=$field " +
                    "length=${text.length} sent=$sent remoteReady=${remoteReady.get()}",
            )
            if (sent) {
                // Advance local counters to match the next IME write expectation.
                // Reader loop updates from TV still take precedence when available.
                imeCounter.set(ime + 1)
                imeFieldCounter.set(field)
                return true
            }
            if (!remoteReady.get()) {
                break
            }
            Thread.sleep(40)
        }
        return false
    }

    private suspend fun ensureInputContext(remote: RemoteController): Boolean {
        if (isImeContextFresh()) {
            return true
        }

        // Try search first; if launcher does not expose search focus reliably, fall back to assist.
        val searchPrepared = triggerInputContext(
            remote = remote,
            keyCode = KEYCODE_SEARCH,
            contextName = "search",
        )
        if (searchPrepared) {
            return true
        }
        return triggerInputContext(
            remote = remote,
            keyCode = KEYCODE_ASSIST,
            contextName = "assist",
        )
    }

    private suspend fun triggerInputContext(
        remote: RemoteController,
        keyCode: Int,
        contextName: String,
    ): Boolean {
        val homeOk = remote.sendKeyCode(KEYCODE_HOME)
        if (!homeOk) {
            Logger.e("ensureInputContext: failed to send HOME before $contextName")
            return false
        }
        delay(180)
        val actionOk = remote.sendKeyCode(keyCode)
        if (!actionOk) {
            Logger.e("ensureInputContext: failed to send key=$keyCode context=$contextName")
            return false
        }
        delay(260)
        val ready = waitForImeContextReady()
        Logger.d("ensureInputContext: context=$contextName ready=$ready")
        return ready
    }

    private suspend fun waitForImeContextReady(timeoutMs: Long = 1800): Boolean {
        val started = System.currentTimeMillis()
        while ((System.currentTimeMillis() - started) < timeoutMs) {
            if (isImeContextFresh()) {
                return true
            }
            delay(70)
        }
        return false
    }

    private fun isImeContextFresh(freshnessMs: Long = 6000): Boolean {
        val updatedAt = lastImeUpdateAtMs.get()
        if (updatedAt <= 0L) return false
        return (System.currentTimeMillis() - updatedAt) <= freshnessMs
    }

    private fun launchApp(arguments: Map<*, *>, result: MethodChannel.Result) {
        val packageName = (arguments["packageName"] as? String)?.trim()
        if (packageName.isNullOrBlank()) {
            mainHandler.post { result.success(false) }
            return
        }
        try {
            if (!remoteReady.get()) {
                waitForRemoteReady()
            }
            val remote = remoteController
            if (remote == null || !remoteReady.get()) {
                Logger.e("launchApp: remote session is not ready package=$packageName")
                mainHandler.post { result.success(false) }
                return
            }
            val appLink = "market://launch?id=$packageName"
            Logger.d("launchApp: package=$packageName appLink=$appLink command=app_link_launch")
            val openedByAppLink = remote.sendAppLinkLaunch(appLink)
            Logger.d("launchApp: package=$packageName openedByAppLink=$openedByAppLink")
            if (openedByAppLink) {
                mainHandler.post { result.success(true) }
                return
            }

            Logger.d("launchApp: package=$packageName fallback=assist_search_sequence")
            val queries = resolveAppSearchQueries(packageName)
            Logger.d("launchApp: package=$packageName queries=$queries")
            val openedDirectly = launchAppByAssistIntent(remote = remote, query = queries.first())
            Logger.d("launchApp: package=$packageName openedDirectly=$openedDirectly")
            if (openedDirectly) {
                mainHandler.post { result.success(true) }
                return
            }
            val openedBySearch = launchAppBySearch(remote = remote, queries = queries)
            Logger.d("launchApp: package=$packageName openedBySearch=$openedBySearch")
            mainHandler.post { result.success(openedBySearch) }
        } catch (e: Exception) {
            Logger.e("launchApp: ${e.message}", e)
            mainHandler.post { result.success(false) }
        }
    }

    private fun launchAppByAssistIntent(remote: RemoteController, query: String): Boolean {
        val homeOk = remote.sendKeyCode(KEYCODE_HOME)
        Logger.d("launchAppByAssistIntent: homeOk=$homeOk query=$query")
        if (!homeOk) return false
        Thread.sleep(180)

        val assistOk = remote.sendKeyCode(KEYCODE_ASSIST)
        Logger.d("launchAppByAssistIntent: assistOk=$assistOk")
        if (!assistOk) return false
        Thread.sleep(300)

        val textOk =
            remote.sendText(
                text = query,
                imeCounter = imeCounter.get(),
                fieldCounter = imeFieldCounter.get(),
            )
        Logger.d("launchAppByAssistIntent: textOk=$textOk")
        if (!textOk) return false
        Thread.sleep(280)
        nudgeFocusOffLauncherTopRow(remote)

        val enterOk = remote.sendKeyCode(KEYCODE_ENTER)
        Logger.d("launchAppByAssistIntent: enterOk=$enterOk")
        return enterOk
    }

    /**
     * Many Android TV launchers keep focus on the top favourites strip after search text is entered;
     * Enter then opens that app (e.g. Xiaomi TV+) instead of the search hit. Nudge focus downward first.
     */
    private fun nudgeFocusOffLauncherTopRow(remote: RemoteController) {
        repeat(LAUNCH_APP_FOCUS_NUDGE_STEPS) { step ->
            if (step > 0) {
                Thread.sleep(100)
            }
            remote.sendKeyCode(KEYCODE_DPAD_DOWN)
        }
        Thread.sleep(120)
    }

    private fun launchAppBySearch(remote: RemoteController, queries: List<String>): Boolean {
        for (query in queries) {
            repeat(2) { attempt ->
                if (attempt > 0) {
                    Thread.sleep(220)
                }
                val homeOk = remote.sendKeyCode(KEYCODE_HOME)
                Logger.d("launchAppBySearch: query=$query attempt=$attempt homeOk=$homeOk")
                if (!homeOk) return@repeat
                Thread.sleep(180)

                val searchOk = remote.sendKeyCode(KEYCODE_SEARCH)
                Logger.d("launchAppBySearch: query=$query attempt=$attempt searchOk=$searchOk")
                if (!searchOk) return@repeat
                Thread.sleep(280)

                val textOk =
                    remote.sendText(
                        text = query,
                        imeCounter = imeCounter.get(),
                        fieldCounter = imeFieldCounter.get(),
                    )
                Logger.d("launchAppBySearch: query=$query attempt=$attempt textOk=$textOk")
                if (!textOk) return@repeat
                Thread.sleep(280)
                nudgeFocusOffLauncherTopRow(remote)

                val enterOk = remote.sendKeyCode(KEYCODE_ENTER)
                Logger.d("launchAppBySearch: query=$query attempt=$attempt enterOk=$enterOk")
                if (enterOk) {
                    return true
                }
            }
        }
        return false
    }

    private fun openUrlOnTv(arguments: Map<*, *>, result: MethodChannel.Result) {
        val url = arguments["url"] as? String
        if (url.isNullOrBlank() || remoteController == null) {
            mainHandler.post { result.success(false) }
            return
        }
        if (!remoteReady.get()) {
            waitForRemoteReady()
        }

        val opened = runCatching {
            var success = false
            repeat(3) { attempt ->
                if (attempt > 0) {
                    Thread.sleep(140)
                }
                success = openUrlByRemoteSequence(url)
                if (success) {
                    return@repeat
                }
            }
            success
        }.getOrDefault(false)
        mainHandler.post { result.success(opened) }
    }

    private fun openUrlByRemoteSequence(url: String): Boolean {
        val remote = remoteController ?: return false
        val homeOk = remote.sendKeyCode(3)
        if (!homeOk) return false
        Thread.sleep(180)

        val searchOk = remote.sendKeyCode(84)
        if (!searchOk) return false
        Thread.sleep(220)

        val textOk =
            remote.sendText(
                text = url,
                imeCounter = imeCounter.get(),
                fieldCounter = imeFieldCounter.get(),
            )
        if (!textOk) return false
        Thread.sleep(160)

        return remote.sendKeyCode(23)
    }

    private fun resolveAppSearchQueries(packageName: String): List<String> {
        val appName =
            when (packageName.trim()) {
                "com.netflix.ninja" -> "Netflix"
                "com.google.android.youtube.tv" -> "YouTube"
                "com.amazon.amazonvideo.livingroom" -> "Prime Video"
                "com.disney.disneyplus" -> "Disney Plus"
                "com.hulu.livingroomplus" -> "Hulu"
                else -> packageName.substringAfterLast('.').replace('_', ' ').replace('-', ' ')
            }.trim()
        if (appName.isEmpty()) return emptyList()
        // Prefer plain app name first: "Open …" can confuse assistants; order matters for assist path.
        return listOf(appName, "Open $appName").distinct()
    }

    private fun disconnectSession(result: MethodChannel.Result) {
        try {
            AndroidTvKeepAliveRegistry.clearKeepAlive()
            AndroidTvKeepAliveService.stop(context.applicationContext)
            disconnectTlsOnly()
            mainHandler.post { result.success(true) }
        } catch (e: Exception) {
            mainHandler.post { result.error("DISC", e.message, null) }
        }
    }

    fun forceDisconnectForKeepAliveTimeout() {
        disconnectTlsOnly()
    }

    fun scheduleTerminationKeepAlive(durationMs: Long): Boolean {
        if (!evaluateRemoteSessionAlive()) return false
        AndroidTvKeepAliveService.start(
            context.applicationContext,
            durationMs.coerceAtLeast(1L),
        )
        return true
    }

    fun scheduleBackgroundKeepAlive(durationMs: Long?): Boolean {
        if (!evaluateRemoteSessionAlive()) return false
        AndroidTvKeepAliveService.start(
            context.applicationContext,
            durationMs = durationMs,
        )
        return true
    }

    private fun startTerminationKeepAlive(
        arguments: Map<*, *>,
        result: MethodChannel.Result,
    ) {
        val durationMs =
            (arguments["durationMs"] as? Number)?.toLong()
                ?: AndroidTvKeepAliveRegistry.DEFAULT_KEEP_ALIVE_MS
        val started = scheduleTerminationKeepAlive(durationMs)
        mainHandler.post { result.success(started) }
    }

    private fun startBackgroundKeepAlive(
        arguments: Map<*, *>,
        result: MethodChannel.Result,
    ) {
        val durationMs = (arguments["durationMs"] as? Number)?.toLong()
        val started = scheduleBackgroundKeepAlive(durationMs)
        mainHandler.post { result.success(started) }
    }

    private fun stopBackgroundKeepAlive(result: MethodChannel.Result) {
        AndroidTvKeepAliveRegistry.clearKeepAlive()
        AndroidTvKeepAliveService.stop(context.applicationContext)
        result.success(true)
    }

    private fun adoptKeepAliveSessionIfAvailable(result: MethodChannel.Result) {
        val keepAliveActive =
            AndroidTvKeepAliveRegistry.keepAliveIndefinite ||
                AndroidTvKeepAliveRegistry.isKeepAliveActive()
        val active = keepAliveActive && evaluateRemoteSessionAlive()
        if (active) {
            AndroidTvKeepAliveRegistry.clearKeepAlive()
            AndroidTvKeepAliveService.stop(context.applicationContext)
            result.success(true)
            return
        }
        result.success(false)
    }

    private fun getKeepAliveStatus(result: MethodChannel.Result) {
        val isActive = AndroidTvKeepAliveRegistry.isKeepAliveActive()
        val remainingMs = AndroidTvKeepAliveRegistry.remainingMs()
        result.success(
            mapOf(
                "active" to isActive,
                "remainingMs" to remainingMs,
            ),
        )
    }

    /**
     * @param skipReaderJobCancel When true, the remote reader coroutine is already exiting; only
     * clear native state (avoids canceling the job that invoked this path from the main thread).
     */
    private fun disconnectTlsOnly(skipReaderJobCancel: Boolean = false) {
        if (!skipReaderJobCancel) {
            remoteReaderJob?.cancel()
        }
        remoteReaderJob = null
        remoteReady.set(false)
        imeCounter.set(0)
        imeFieldCounter.set(0)
        lastImeUpdateAtMs.set(0L)
        remoteController?.destroy()
        remoteController = null
        tlsRemote?.disconnect()
        tlsRemote = null
        tlsPairing?.disconnect()
        tlsPairing = null
    }

    fun destroy() {
        try {
            AndroidTvKeepAliveRegistry.plugin = null
            AndroidTvKeepAliveRegistry.clearKeepAlive()
            AndroidTvKeepAliveService.stop(context.applicationContext)
            disconnectTlsOnly()
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
            multicastLock = null
        } catch (e: Exception) {
            Logger.e("destroy: ${e.message}", e)
        }
    }

    private fun startRemoteReaderLoop() {
        remoteReaderJob?.cancel()
        remoteReady.set(false)
        val remote = tlsRemote ?: return
        remoteReaderJob = scope.launch {
            try {
                while (isActive && remote.isConnected()) {
                    val msg = remote.receiveData()
                    if (msg == null) {
                        if (!remote.isConnected()) {
                            break
                        }
                        continue
                    }
                    when (MessageParser.parseRemoteMessageType(msg)) {
                        MessageParser.RemoteMessageType.CONFIGURE -> {
                            remote.sendData(ProtobufMessage.createRemoteConfigureMessage())
                            remoteReady.set(true)
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
                        MessageParser.RemoteMessageType.OTHER -> {
                            val counters = MessageParser.parseRemoteImeBatchEditCounters(msg)
                            if (counters != null) {
                                imeCounter.set(counters.first)
                                imeFieldCounter.set(counters.second)
                                lastImeUpdateAtMs.set(System.currentTimeMillis())
                                Logger.d(
                                    "remoteImeCountersUpdated: ime=${counters.first} field=${counters.second}",
                                )
                            }
                        }
                    }
                }
                if (!isActive) {
                    return@launch
                }
                Logger.d("remoteReaderLoop: session lost (socket closed or reader stopped)")
                mainHandler.post {
                    notifyDartRemoteSessionEnded("remote_session_lost")
                    disconnectTlsOnly(skipReaderJobCancel = true)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Logger.e("remoteReaderLoop: ${e.message}", e)
                if (isActive) {
                    mainHandler.post {
                        notifyDartRemoteSessionEnded("remote_reader_error")
                        disconnectTlsOnly(skipReaderJobCancel = true)
                    }
                }
            }
        }
    }

    private fun waitForRemoteReady(timeoutMs: Long = 1800): Boolean {
        val started = System.currentTimeMillis()
        while (!remoteReady.get() && (System.currentTimeMillis() - started) < timeoutMs) {
            Thread.sleep(30)
        }
        return remoteReady.get()
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
