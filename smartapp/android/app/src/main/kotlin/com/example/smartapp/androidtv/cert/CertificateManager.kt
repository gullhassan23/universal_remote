package com.mg.smart.tv.remote.control.androidtv.cert

import java.io.FileInputStream
import java.security.KeyStore
import java.security.SecureRandom
import java.security.Security
import java.security.cert.X509Certificate
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import org.bouncycastle.jce.provider.BouncyCastleProvider

class CertificateManager {
    init {
        if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
            Security.addProvider(BouncyCastleProvider())
        }
    }

    fun loadPKCS12KeyStore(pkcs12Path: String, password: String = ""): KeyStore? {
        return try {
            val keyStore = KeyStore.getInstance("PKCS12", BouncyCastleProvider.PROVIDER_NAME)
            FileInputStream(pkcs12Path).use { fis ->
                keyStore.load(fis, password.toCharArray())
            }
            keyStore
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Client cert for mutual TLS + permissive server trust (TV uses its own cert).
     */
    fun createSSLContext(pkcs12Path: String, password: String = ""): SSLContext? {
        return try {
            val keyStore = loadPKCS12KeyStore(pkcs12Path, password) ?: return null
            val kmf = try {
                KeyManagerFactory.getInstance("X509")
            } catch (_: Exception) {
                KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
            }
            kmf.init(keyStore, password.toCharArray())

            val trustAll = arrayOf<TrustManager>(
                object : X509TrustManager {
                    override fun checkClientTrusted(
                        chain: Array<out X509Certificate>?,
                        authType: String?,
                    ) {
                    }

                    override fun checkServerTrusted(
                        chain: Array<out X509Certificate>?,
                        authType: String?,
                    ) {
                    }

                    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                },
            )

            val sslContext = SSLContext.getInstance("TLS")
            sslContext.init(kmf.keyManagers, trustAll, SecureRandom())
            sslContext
        } catch (e: Exception) {
            null
        }
    }
}
