/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {GoogleAuth} = require("google-auth-library");
const admin = require("firebase-admin");

admin.initializeApp();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

const PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const PLAY_API_ROOT =
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";
const ALLOWED_ORIGINS = ["*"];
const APPLE_PROD_URL = "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

/**
 * CORS helper for browser/mobile clients.
 * @param {Object} request
 * @param {Object} response
 * @return {boolean} whether preflight was handled
 */
function handleCors(request, response) {
  const origin = request.headers.origin || "*";
  const allowOrigin = ALLOWED_ORIGINS.includes("*") ? "*" : origin;
  response.set("Access-Control-Allow-Origin", allowOrigin);
  response.set("Access-Control-Allow-Methods", "POST,OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type,Authorization");
  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return true;
  }
  return false;
}

/**
 * @param {string} encodedJson
 * @return {{client_email: string, private_key: string}}
 */
function parseServiceAccount(encodedJson) {
  const parsed = JSON.parse(encodedJson);
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error("Invalid GOOGLE_SERVICE_ACCOUNT_JSON");
  }
  return parsed;
}

/**
 * @param {string} packageName
 * @param {string} productId
 * @param {string} token
 * @param {{client_email: string, private_key: string}} credentials
 * @return {Promise<Object>}
 */
async function verifySubscriptionWithPlay(
    packageName,
    productId,
    token,
    credentials,
) {
  const auth = new GoogleAuth({
    credentials,
    scopes: [PLAY_SCOPE],
  });
  const client = await auth.getClient();
  const accessTokenResponse = await client.getAccessToken();
  const accessToken = accessTokenResponse && accessTokenResponse.token ?
    accessTokenResponse.token :
    null;

  if (!accessToken) {
    throw new Error("Could not acquire Google access token");
  }

  const url =
    `${PLAY_API_ROOT}/${encodeURIComponent(packageName)}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`;
  const response = await fetch(url, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });

  const responseText = await response.text();
  let payload = {};
  try {
    payload = responseText ? JSON.parse(responseText) : {};
  } catch (_) {
    payload = {raw: responseText};
  }

  if (!response.ok) {
    logger.error("Google Play verify failed", {
      status: response.status,
      body: payload,
      packageName,
      productId,
    });
    return {
      ok: false,
      status: response.status,
      payload,
    };
  }

  const lineItems = Array.isArray(payload.lineItems) ? payload.lineItems : [];
  const matchedLineItem = lineItems
      .find((item) => item.productId === productId);
  const latestLineItem = matchedLineItem || lineItems[0] || {};
  const expiryTime = latestLineItem.expiryTime || null;

  const currentState = payload.subscriptionState || "";
  const isActiveState = [
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_ON_HOLD",
  ].includes(currentState);

  return {
    ok: true,
    status: response.status,
    payload,
    isValid: isActiveState,
    state: currentState,
    expiryTime,
  };
}

/**
 * Verify Apple receipt via Apple verifyReceipt endpoint (legacy).
 * For subscriptions, we look for the latest receipt info of the productId.
 *
 * Env:
 * - APPLE_SHARED_SECRET: App Store Connect subscription shared secret
 *
 * @param {string} receiptData base64 receipt data (from serverVerificationData)
 * @param {string} productId expected product identifier
 * @param {boolean} useSandbox whether to call sandbox endpoint
 * @return {Promise<Object>} verification result
 */
async function verifySubscriptionWithApple(receiptData, productId, useSandbox) {
  const sharedSecret = process.env.APPLE_SHARED_SECRET || "";
  if (!sharedSecret) {
    return {
      ok: false,
      status: 500,
      message: "Server not configured. Set APPLE_SHARED_SECRET",
    };
  }

  const url = useSandbox ? APPLE_SANDBOX_URL : APPLE_PROD_URL;
  const response = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      "receipt-data": receiptData,
      "password": sharedSecret,
      "exclude-old-transactions": true,
    }),
  });

  const responseText = await response.text();
  let payload = {};
  try {
    payload = responseText ? JSON.parse(responseText) : {};
  } catch (_) {
    payload = {raw: responseText};
  }

  if (!response.ok) {
    logger.error("Apple verifyReceipt HTTP error", {
      status: response.status,
      body: payload,
    });
    return {ok: false, status: response.status, raw: payload};
  }

  const appleStatus = Number(payload.status);
  // 0=OK
  // 21007=sandbox receipt sent to production
  // 21008=production receipt sent to sandbox
  if (appleStatus === 21007 && !useSandbox) {
    return await verifySubscriptionWithApple(receiptData, productId, true);
  }
  if (appleStatus === 21008 && useSandbox) {
    return await verifySubscriptionWithApple(receiptData, productId, false);
  }

  if (appleStatus !== 0) {
    return {
      ok: true,
      status: 200,
      isValid: false,
      message: `Apple receipt invalid (status=${appleStatus})`,
      raw: payload,
    };
  }

  const latestReceiptInfo = Array.isArray(payload.latest_receipt_info) ?
    payload.latest_receipt_info : [];

  const candidates = latestReceiptInfo.filter((item) =>
    item && item.product_id === productId,
  );
  const pick = (candidates.length ? candidates : latestReceiptInfo)
      .sort(
          (a, b) =>
            Number(b.expires_date_ms || 0) - Number(a.expires_date_ms || 0),
      )[0];

  const expiresMs = pick ? Number(pick.expires_date_ms || 0) : 0;
  const isActive = expiresMs > Date.now();

  return {
    ok: true,
    status: 200,
    isValid: Boolean(isActive),
    expiryTimeMs: expiresMs || null,
    raw: payload,
  };
}

/**
 * Persist verified entitlement into Firestore.
 * Uses device-based userId passed from the app (not Firebase Auth UID).
 *
 * @param {Object} data
 * @return {Promise<void>}
 */
async function writeEntitlementToFirestore(data) {
  const userId = data.userId;
  if (!userId || typeof userId !== "string") return;

  const docRef = admin.firestore().collection("Users").doc(userId);
  const payload = {
    iap: {
      platform: data.platform || null,
      productId: data.productId || null,
      state: data.state || null,
      expiryTime: data.expiryTime || null,
      transactionId: data.transactionId || null,
      orderId: data.orderId || null,
      isRestore: Boolean(data.isRestore),
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    isPremium: Boolean(data.isPremium),
    premiumProductId: data.isPremium ? (data.productId || null) : null,
    lastSubscribeDate: data.isPremium ?
      admin.firestore.FieldValue.serverTimestamp() :
      admin.firestore.FieldValue.delete(),
  };

  if (data.fcmToken && typeof data.fcmToken === "string") {
    payload.fcmToken = data.fcmToken;
  }

  await docRef.set(payload, {merge: true});
}

exports.verifyIapPurchase = onRequest(
    {region: "us-central1"},
    async (request, response) => {
      if (handleCors(request, response)) return;
      if (request.method !== "POST") {
        response.status(405).json({
          isValid: false,
          message: "Method not allowed",
        });
        return;
      }

      try {
        const {
          productId,
          purchaseToken,
          receiptData,
          platform,
          userId,
          transactionId,
          orderId,
          isRestore,
          fcmToken,
        } = request.body || {};

        if (!productId || typeof productId !== "string") {
          response.status(400).json({
            isValid: false,
            message: "Missing productId",
          });
          return;
        }

        let result = null;
        if (platform === "android") {
          if (!purchaseToken || typeof purchaseToken !== "string") {
            response.status(400).json({
              isValid: false,
              message: "Missing purchaseToken for Android verification",
            });
            return;
          }

          const packageName = process.env.ANDROID_PACKAGE_NAME || "";
          const serviceAccountJson =
            process.env.GOOGLE_SERVICE_ACCOUNT_JSON || "";
          if (!packageName || !serviceAccountJson) {
            response.status(500).json({
              isValid: false,
              message:
                "Server not configured. Set ANDROID_PACKAGE_NAME and " +
                "GOOGLE_SERVICE_ACCOUNT_JSON",
            });
            return;
          }

          const credentials = parseServiceAccount(serviceAccountJson);
          const play = await verifySubscriptionWithPlay(
              packageName,
              productId,
              purchaseToken,
              credentials,
          );
          if (!play.ok) {
            response.status(200).json({
              isValid: false,
              message: "Purchase could not be validated by Google Play",
            });
            return;
          }
          result = {
            isValid: Boolean(play.isValid),
            state: play.state || null,
            expiryTime: play.expiryTime || null,
            raw: play.payload || null,
          };
        } else if (platform === "ios") {
          if (!receiptData || typeof receiptData !== "string") {
            response.status(400).json({
              isValid: false,
              message: "Missing receiptData for iOS verification",
            });
            return;
          }
          const apple = await verifySubscriptionWithApple(
              receiptData,
              productId,
              false,
          );
          if (!apple.ok) {
            response.status(200).json({
              isValid: false,
              message:
                apple.message || "Purchase could not be validated by Apple",
            });
            return;
          }
          result = {
            isValid: Boolean(apple.isValid),
            state: apple.isValid ? "APPLE_ACTIVE" : "APPLE_INACTIVE",
            expiryTime: apple.expiryTimeMs ?
              new Date(apple.expiryTimeMs).toISOString() :
              null,
            raw: apple.raw || null,
          };
        } else {
          response.status(400).json({
            isValid: false,
            message: "Unsupported platform",
          });
          return;
        }

        logger.info("IAP verification result", {
          userId: userId || null,
          productId,
          platform,
          transactionId: transactionId || null,
          orderId: orderId || null,
          isRestore: Boolean(isRestore),
          state: result.state,
          expiryTime: result.expiryTime,
          isValid: result.isValid,
        });

        await writeEntitlementToFirestore({
          userId,
          productId,
          platform,
          transactionId,
          orderId,
          isRestore,
          fcmToken,
          isPremium: result.isValid,
          state: result.state,
          expiryTime: result.expiryTime,
        });

        response.status(200).json({
          isValid: result.isValid,
          message: result.isValid ?
            "Purchase verified and active" :
            "Subscription is not active",
          state: result.state,
          expiryTime: result.expiryTime,
        });
      } catch (error) {
        logger.error("verifyIapPurchase error", error);
        response.status(500).json({
          isValid: false,
          message: "Internal verification error",
        });
      }
    },
);
