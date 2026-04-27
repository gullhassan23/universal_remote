const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

admin.initializeApp();

const db = admin.firestore();

const REGION = "us-central1";
const APPSTORE_SHARED_SECRET = defineSecret("APPSTORE_SHARED_SECRET");

function toIsoOrNull(msString) {
  const ms = Number(msString || 0);
  if (!ms) return null;
  return new Date(ms).toISOString();
}

function inferAndroidExpiryIso(productId) {
  const now = new Date();
  const id = String(productId || "").toLowerCase();
  if (id.includes("weekly")) {
    now.setDate(now.getDate() + 7);
    return now.toISOString();
  }
  if (id.includes("monthly")) {
    now.setMonth(now.getMonth() + 1);
    return now.toISOString();
  }
  if (id.includes("yearly") || id.includes("annual")) {
    now.setFullYear(now.getFullYear() + 1);
    return now.toISOString();
  }
  return null;
}

function buildAndroidTemporaryResult(payload) {
  const inferredExpiry = inferAndroidExpiryIso(payload.productId);
  return {
    isValid: true,
    message: "Android temporary verification enabled",
    state: "ANDROID_TEMP_ACTIVE",
    expiryTime: inferredExpiry,
    purchaseDate: new Date().toISOString(),
    autoRenew: true,
    raw: {
      platform: "android",
      verificationMode: "temporary_unverified",
      productId: payload.productId || null,
      transactionId: payload.transactionId || null,
      orderId: payload.orderId || null,
      purchaseTokenPresent: Boolean(payload.purchaseToken),
    },
  };
}

async function verifyAppleReceipt(receiptData) {
  const sharedSecret = APPSTORE_SHARED_SECRET.value();
  if (!sharedSecret) {
    throw new Error("APPSTORE_SHARED_SECRET is not configured");
  }
  const payload = {
    "receipt-data": receiptData,
    "password": sharedSecret,
    "exclude-old-transactions": true,
  };

  const verify = async (url) => {
    const response = await fetch(url, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload),
    });
    return response.json();
  };

  let data = await verify("https://buy.itunes.apple.com/verifyReceipt");
  if (data.status === 21007) {
    data = await verify("https://sandbox.itunes.apple.com/verifyReceipt");
  }
  return data;
}

function buildIosResult(payload, appleResponse) {
  const latestReceiptInfo = Array.isArray(appleResponse.latest_receipt_info) ?
    appleResponse.latest_receipt_info :
    (Array.isArray(appleResponse.receipt?.in_app) ?
      appleResponse.receipt.in_app :
      []);

  const matched = latestReceiptInfo
      .filter((item) => item?.product_id === payload.productId);
  const candidates = matched.length ? matched : latestReceiptInfo;
  const latest = candidates.reduce((best, current) => {
    const bestMs = Number(best?.expires_date_ms || 0);
    const curMs = Number(current?.expires_date_ms || 0);
    return curMs > bestMs ? current : best;
  }, null);

  const expiryIso = toIsoOrNull(latest?.expires_date_ms);
  const purchaseIso = toIsoOrNull(latest?.purchase_date_ms);
  const nowMs = Date.now();
  const expiryMs = Number(latest?.expires_date_ms || 0);
  const isActive = expiryMs > nowMs;

  const pendingRenewalInfo = Array.isArray(appleResponse.pending_renewal_info) ?
    appleResponse.pending_renewal_info :
    [];
  const renewalInfo = pendingRenewalInfo.find(
      (item) =>
        item?.auto_renew_product_id === payload.productId ||
        item?.product_id === payload.productId,
  ) || null;
  const autoRenew = renewalInfo?.auto_renew_status === "1";

  return {
    isValid: isActive,
    message: isActive ? "Apple receipt verified" : "Subscription expired/inactive",
    state: isActive ? "APPLE_ACTIVE" : "APPLE_INACTIVE",
    expiryTime: expiryIso,
    purchaseDate: purchaseIso,
    autoRenew,
    isExpired: !isActive,
    raw: {
      platform: "ios",
      verificationMode: "apple_verify_receipt",
      appleStatus: appleResponse.status,
      latestProductId: latest?.product_id || null,
      transactionId: latest?.transaction_id || payload.transactionId || null,
      originalTransactionId: latest?.original_transaction_id || null,
    },
  };
}

async function persistSubscriptionResult({userId, payload, result}) {
  const userRef = db.collection("Users").doc(userId);

  const historyItem = {
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    platform: payload.platform || "ios",
    productId: payload.productId || null,
    transactionId: payload.transactionId || null,
    orderId: payload.orderId || null,
    isRestore: Boolean(payload.isRestore),
    isValid: result.isValid,
    state: result.state || null,
    expiryTime: result.expiryTime || null,
    message: result.message || null,
    source: "cloud_function_v2",
  };

  await userRef.set({
    isPremium: result.isValid,
    subscription: {
      platform: payload.platform || "ios",
      productId: payload.productId || null,
      expiryTime: result.expiryTime || null,
      state: result.state || null,
      autoRenew: result.autoRenew || false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    premiumExpiry: result.expiryTime || null,
    fcmToken: payload.fcmToken || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    subscriptionHistory: admin.firestore.FieldValue.arrayUnion(historyItem),
  }, {merge: true});
}

exports.verifyIapPurchaseCallable = onCall(
    {
      region: REGION,
      timeoutSeconds: 30,
      memory: "256MiB",
      secrets: [APPSTORE_SHARED_SECRET],
    },
    async (request) => {
      const data = request.data || {};
      const receiptData = data.receiptData;
      const userId = data.userId;
      const platform = String(data.platform || "").toLowerCase();

      if (!receiptData || typeof receiptData !== "string") {
        throw new HttpsError("invalid-argument", "receiptData is required");
      }

      if (!userId || typeof userId !== "string") {
        throw new HttpsError("invalid-argument", "userId is required");
      }

      try {
        if (platform === "android") {
          const androidResult = buildAndroidTemporaryResult(data);
          await persistSubscriptionResult({
            userId,
            payload: data,
            result: androidResult,
          });
          return androidResult;
        }
        if (platform === "ios") {
          const appleResponse = await verifyAppleReceipt(receiptData);
          if (appleResponse.status !== 0) {
            return {
              isValid: false,
              message: `Apple verification failed (${appleResponse.status})`,
              state: "APPLE_VERIFY_FAILED",
              expiryTime: null,
              purchaseDate: null,
              autoRenew: false,
              isExpired: false,
              raw: {
                platform: "ios",
                verificationMode: "apple_verify_receipt",
                appleStatus: appleResponse.status,
              },
            };
          }

          const iosResult = buildIosResult(data, appleResponse);
          await persistSubscriptionResult({
            userId,
            payload: data,
            result: iosResult,
          });
          return iosResult;
        }
        return {
          isValid: false,
          message: "Unsupported platform for verification",
          state: "PLATFORM_NOT_SUPPORTED",
          expiryTime: null,
          purchaseDate: null,
          autoRenew: false,
          isExpired: false,
          raw: {
            platform: platform || "unknown",
            verificationMode: "unsupported_platform",
          },
        };
      } catch (error) {
        logger.error("verifyIapPurchaseCallable failed", {error: String(error)});
        throw new HttpsError("internal", "Receipt verification failed");
      }
    },
);

exports.checkSubscriptionExpiryAndNotify = onSchedule(
    {
      schedule: "every 24 hours",
      region: REGION,
      timeZone: "UTC",
      memory: "256MiB",
    },
    async () => {
      const nowIso = new Date().toISOString();
      const snapshot = await db
          .collection("Users")
          .where("isPremium", "==", true)
          .get();

      const messages = [];
      const batch = db.batch();

      snapshot.forEach((doc) => {
        const data = doc.data() || {};
        const expiry = data.premiumExpiry || data.subscription?.expiryTime;
        const fcmToken = data.fcmToken;

        if (!expiry) return;

        const expired = new Date(expiry).getTime() <= Date.now();
        if (!expired) return;

        batch.set(doc.ref, {
          isPremium: false,
          subscription: {
            ...(data.subscription || {}),
            state: "APPLE_INACTIVE",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          subscriptionHistory: admin.firestore.FieldValue.arrayUnion({
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            source: "expiry_scheduler",
            isValid: false,
            state: "APPLE_INACTIVE",
            message: "Subscription expired via scheduled check",
            expiryTime: expiry,
          }),
        }, {merge: true});

        if (typeof fcmToken === "string" && fcmToken.length > 20) {
          messages.push({
            token: fcmToken,
            notification: {
              title: "Subscription Expired",
              body: "Your premium subscription has expired. Renew to keep premium access.",
            },
            data: {
              type: "SUBSCRIPTION_EXPIRED",
              expiredAt: nowIso,
            },
          });
        }
      });

      await batch.commit();

      for (const msg of messages) {
        try {
          await admin.messaging().send(msg);
        } catch (err) {
          logger.warn("FCM send failed", {error: String(err)});
        }
      }

      logger.info("checkSubscriptionExpiryAndNotify completed", {
        usersScanned: snapshot.size,
        notificationsAttempted: messages.length,
      });
    },
);
