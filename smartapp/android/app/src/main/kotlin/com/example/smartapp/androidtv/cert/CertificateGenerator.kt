package com.example.smartapp.androidtv.cert

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.SecureRandom
import java.security.Security
import java.security.cert.Certificate
import java.security.cert.X509Certificate
import java.util.Date
import java.util.Random
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x509.BasicConstraints
import org.bouncycastle.asn1.x509.Extension
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder

class CertificateGenerator {

    init {
        if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
            Security.addProvider(BouncyCastleProvider())
        }
    }

    fun generateCertificates(
        context: Context,
        certificateName: String = "androidtvremote",
    ): CertificateFilesResult {
        return try {
            val keyPair = generateKeyPair()
            val certificate = generateX509Certificate(
                keyPair.public,
                keyPair.private,
                certificateName,
            )
            val derPath = saveDERCertificate(context, certificate)
            val pkcs12Path = savePKCS12Certificate(
                context,
                certificate,
                keyPair.private,
                certificateName,
            )
            CertificateFilesResult(
                derPath = derPath,
                pkcs12Path = pkcs12Path,
                success = true,
            )
        } catch (e: Exception) {
            CertificateFilesResult(
                error = "Certificate generation failed: ${e.message}",
                success = false,
            )
        }
    }

    private fun generateKeyPair(): KeyPair {
        val keyGen = KeyPairGenerator.getInstance("RSA", BouncyCastleProvider.PROVIDER_NAME)
        keyGen.initialize(2048)
        return keyGen.generateKeyPair()
    }

    private fun generateX509Certificate(
        publicKey: PublicKey,
        privateKey: PrivateKey,
        commonName: String,
    ): X509Certificate {
        val now = Date()
        val until = Date(now.time + 1825L * 24 * 60 * 60 * 1000L)
        val x500Name = X500Name("CN=$commonName")
        val serialNumber = BigInteger.probablePrime(64, Random())
        val builder = JcaX509v3CertificateBuilder(
            x500Name,
            serialNumber,
            now,
            until,
            x500Name,
            publicKey,
        )
        builder.addExtension(
            Extension.basicConstraints,
            true,
            BasicConstraints(true),
        )
        val contentSigner = JcaContentSignerBuilder("SHA256WithRSA")
            .setProvider(BouncyCastleProvider.PROVIDER_NAME)
            .build(privateKey)
        val certHolder = builder.build(contentSigner)
        return JcaX509CertificateConverter()
            .setProvider(BouncyCastleProvider.PROVIDER_NAME)
            .getCertificate(certHolder)
    }

    private fun saveDERCertificate(context: Context, certificate: X509Certificate): String {
        val file = File(context.filesDir, "cert.der")
        FileOutputStream(file).use { fos ->
            fos.write(certificate.encoded)
        }
        return file.absolutePath
    }

    private fun savePKCS12Certificate(
        context: Context,
        certificate: X509Certificate,
        privateKey: PrivateKey,
        certificateName: String,
    ): String {
        val file = File(context.filesDir, "cert.p12")
        val keyStore = KeyStore.getInstance("PKCS12", BouncyCastleProvider.PROVIDER_NAME)
        keyStore.load(null, null)
        val chain = arrayOf<Certificate>(certificate)
        keyStore.setKeyEntry(
            certificateName,
            privateKey,
            CharArray(0),
            chain,
        )
        FileOutputStream(file).use { fos ->
            keyStore.store(fos, CharArray(0))
        }
        return file.absolutePath
    }
}

data class CertificateFilesResult(
    val derPath: String = "",
    val pkcs12Path: String = "",
    val success: Boolean = false,
    val error: String = "",
)
