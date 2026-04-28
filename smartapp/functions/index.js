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

function inferIosExpiryIso(productId) {
  const now = new Date();
  const id = String(productId || "").toLowerCase();
  if (id.includes("weekly") || id.includes("weakly")) {
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

function buildIosTemporaryResult(payload) {
  const inferredExpiry = inferIosExpiryIso(payload.productId);
  return {
    isValid: true,
    message: "Apple temporary verification enabled (status 21002)",
    state: "APPLE_TEMP_ACTIVE_21002",
    expiryTime: inferredExpiry,
    purchaseDate: new Date().toISOString(),
    autoRenew: true,
    isExpired: false,
    raw: {
      platform: "ios",
      verificationMode: "apple_temp_21002",
      productId: payload.productId || null,
      transactionId: payload.transactionId || null,
    },
  };
}

async function verifyAppleReceipt(receiptData) {
  const sharedSecret = APPSTORE_SHARED_SECRET.value();
  if (!sharedSecret) {
    return {status: 21002, statusText: "APPSTORE_SHARED_SECRET missing"};
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

function buildReceiptCandidates(data) {
  const candidates = [];
  const primary = typeof data.receiptData === "string" ? data.receiptData.trim() : "";
  const local = typeof data.localReceiptData === "string" ? data.localReceiptData.trim() : "";
  if (primary) candidates.push(primary);
  if (local && local !== primary) candidates.push(local);
  return candidates;
}

async function verifyAppleReceiptWithFallback(candidates) {
  let lastResponse = null;
  for (const candidate of candidates) {
    // StoreKit2 JWS token is dot-separated; verifyReceipt expects base64 app receipt.
    const isLikelyJws = candidate.includes(".");
    if (isLikelyJws) continue;
    const response = await verifyAppleReceipt(candidate);
    lastResponse = response;
    if (response?.status === 0) return response;
    // 21002 = malformed/unreadable receipt. Try next candidate.
    if (response?.status !== 21002) return response;
  }
  return lastResponse || {status: 21002};
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

function toMillisOrZero(iso) {
  if (!iso || typeof iso !== "string") return 0;
  const ms = Date.parse(iso);
  return Number.isFinite(ms) ? ms : 0;
}

function buildSubscriptionEvent({
  payload,
  previousIsPremium,
  previousExpiry,
  currentResult,
}) {
  const nowPremium = currentResult.isValid === true;
  const wasPremium = previousIsPremium === true;
  const isRestore = Boolean(payload.isRestore);
  const oldExpiryMs = toMillisOrZero(previousExpiry);
  const newExpiryMs = toMillisOrZero(currentResult.expiryTime);

  if (nowPremium && isRestore) {
    return {
      type: "SUBSCRIPTION_RESTORED",
      title: "Subscription Restored",
      body: "Your premium subscription has been restored successfully.",
    };
  }

  if (nowPremium && !wasPremium) {
    return {
      type: "SUBSCRIPTION_STARTED",
      title: "Welcome to Premium",
      body: "Your subscription is active. Enjoy all premium features!",
    };
  }

  if (nowPremium && wasPremium && newExpiryMs > oldExpiryMs && oldExpiryMs > 0) {
    return {
      type: "SUBSCRIPTION_RENEWED",
      title: "Subscription Renewed",
      body: "Your premium subscription renewed successfully.",
    };
  }

  if (!nowPremium && wasPremium) {
    return {
      type: "SUBSCRIPTION_CANCELED_OR_EXPIRED",
      title: "Subscription Ended",
      body: "Your premium subscription is no longer active.",
    };
  }

  return null;
}

async function sendSubscriptionNotification({token, event}) {
  if (!token || typeof token !== "string" || token.length <= 20 || !event) return;
  try {
    await admin.messaging().send({
      token,
      notification: {
        title: event.title,
        body: event.body,
      },
      data: {
        type: event.type,
      },
    });
  } catch (error) {
    logger.warn("Subscription notification send failed", {
      type: event.type,
      error: String(error),
    });
  }
}

async function persistSubscriptionResult({userId, payload, result}) {
  const userRef = db.collection("Users").doc(userId);
  const beforeSnap = await userRef.get();
  const beforeData = beforeSnap.data() || {};
  const previousIsPremium = beforeData.isPremium === true;
  const previousExpiry =
    beforeData.premiumExpiry ||
    beforeData.subscription?.expiryTime ||
    null;

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

  const expiryDate = result.expiryTime ? new Date(result.expiryTime) : null;
  const purchaseDate = result.purchaseDate ? new Date(result.purchaseDate) : null;

  await userRef.set({
    isPremium: result.isValid,
    premiumProductId: result.isValid ? (payload.productId || null) : null,
    premiumVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiryDate: expiryDate ? admin.firestore.Timestamp.fromDate(expiryDate) : null,
    premiumExpiry: result.expiryTime || null,
    purchaseDate: purchaseDate ?
      admin.firestore.Timestamp.fromDate(purchaseDate) :
      admin.firestore.FieldValue.serverTimestamp(),
    autoRenew: result.isValid ? Boolean(result.autoRenew) : false,
    subscription: {
      platform: payload.platform || "ios",
      productId: payload.productId || null,
      expiryTime: result.expiryTime || null,
      state: result.state || null,
      autoRenew: result.autoRenew || false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    fcmToken: payload.fcmToken || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    subscriptionHistory: admin.firestore.FieldValue.arrayUnion(historyItem),
  }, {merge: true});

  const event = buildSubscriptionEvent({
    payload,
    previousIsPremium,
    previousExpiry,
    currentResult: result,
  });

  const notificationToken = payload.fcmToken || beforeData.fcmToken || null;
  await sendSubscriptionNotification({token: notificationToken, event});
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
          const candidates = buildReceiptCandidates(data);
          const appleResponse = await verifyAppleReceiptWithFallback(candidates);
          if (appleResponse.status === 21002) {
            logger.warn("Apple verifyReceipt returned 21002, enabling temporary iOS fallback", {
              productId: data.productId || null,
              userId,
              hasPrimaryReceipt: typeof data.receiptData === "string" &&
                data.receiptData.length > 20,
              hasLocalReceipt: typeof data.localReceiptData === "string" &&
                data.localReceiptData.length > 20,
            });
            const iosTempResult = buildIosTemporaryResult(data);
            await persistSubscriptionResult({
              userId,
              payload: data,
              result: iosTempResult,
            });
            return iosTempResult;
          }
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
      const nowMs = Date.now();
      const oneDayFromNowMs = nowMs + 24 * 60 * 60 * 1000;
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

        const expiryMs = Date.parse(expiry);
        const expired = Number.isFinite(expiryMs) && expiryMs <= nowMs;
        const renewingSoon =
          Number.isFinite(expiryMs) &&
          expiryMs > nowMs &&
          expiryMs <= oneDayFromNowMs &&
          data.subscription?.autoRenew === true;

        if (renewingSoon && typeof fcmToken === "string" && fcmToken.length > 20) {
          messages.push({
            token: fcmToken,
            notification: {
              title: "Subscription Renewing Soon",
              body: "Your premium subscription is set to auto-renew soon.",
            },
            data: {
              type: "SUBSCRIPTION_RENEWING_SOON",
              expiryTime: expiry,
            },
          });
        }

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
