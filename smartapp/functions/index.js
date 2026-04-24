const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");

admin.initializeApp();

const db = admin.firestore();

const REGION = "us-central1";

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
        return {
          isValid: false,
          message: "Only Android verification is enabled currently",
          state: "PLATFORM_NOT_SUPPORTED",
          expiryTime: null,
          purchaseDate: null,
          autoRenew: false,
          raw: {
            platform: platform || "unknown",
            verificationMode: "android_only",
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
