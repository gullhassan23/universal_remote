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
          platform,
          userId,
          transactionId,
          orderId,
          isRestore,
        } = request.body || {};

        if (!productId || typeof productId !== "string") {
          response.status(400).json({
            isValid: false,
            message: "Missing productId",
          });
          return;
        }

        if (platform !== "android") {
          response.status(400).json({
            isValid: false,
            message: "Only android verification is currently supported",
          });
          return;
        }

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
        const result = await verifySubscriptionWithPlay(
            packageName,
            productId,
            purchaseToken,
            credentials,
        );

        if (!result.ok) {
          response.status(200).json({
            isValid: false,
            message: "Purchase could not be validated by Google Play",
          });
          return;
        }

        logger.info("IAP verification result", {
          userId: userId || null,
          productId,
          transactionId: transactionId || null,
          orderId: orderId || null,
          isRestore: Boolean(isRestore),
          state: result.state,
          expiryTime: result.expiryTime,
          isValid: result.isValid,
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
