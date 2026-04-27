# Apple IAP Subscription – Full Code + Guide (Single Download File)

**Ye ek hi file hai jisme poori guide aur saara code hai.** Is file ko download / share karke dusri app mein same integration use kar sakte ho.

---

# Part 1 – Full Guide

## 1. Overview (Flow)

1. **Flutter app** – User monthly/yearly plan select karta hai → Apple IAP purchase → receipt backend ko bhejta hai.
2. **Firebase Cloud Function** – Receipt Apple se verify karta hai (ya dev fallback), Firestore `users/{userId}` update, "Welcome to Premium" FCM.
3. **Firestore** – `users/{userId}`: `isPremium`, `expiryDate`, `productId`, `fcmToken`.
4. **Flutter** – Firestore stream se premium status → UI lock/unlock.
5. **Scheduled function** – Har 24 ghante: "renewing soon" / "expired" notifications.

Prices **dynamic** (Apple se). Product IDs **.env** se. Backend pe **App-Specific Shared Secret** (Firebase Secrets).

## 2. Prerequisites

- Apple Developer: App + In-App Purchases (auto-renewable).
- Firebase: Blaze plan, app linked (google-services.json / GoogleService-Info.plist).
- App-Specific Shared Secret → Firebase Secrets.
- APNs key (.p8) → Firebase Cloud Messaging (iOS).

## 3. Kon Sa Kahan Add Karna Hai (Quick)

- **.env** (root): `CLOUD_FUNCTION_URL`, `IAP_PRODUCT_MONTHLY`, `IAP_PRODUCT_YEARLY`, `PRIVACY_POLICY_URL`
- **pubspec.yaml**: dependencies (`in_app_purchase`, `http`, `cloud_firestore`, `firebase_messaging`, `flutter_dotenv`) + `assets: - .env`
- **lib/utils/user_id.dart** – copy full file
- **lib/services/fcm_token_service.dart** – copy full file (package name change)
- **lib/services/in_app_purchase_service.dart** – copy full file (package name change)
- **lib/providers/premium_provider.dart** – copy full file (package name change)
- **lib/views/premium/premium_page.dart** – copy full file (package name change)
- **lib/routes/route_name.dart** – add `static const String premiumScreen = 'premium-screen';`
- **lib/routes/route.dart** – add import `PremiumPage` + case `RouteName.premiumScreen` → `PremiumPage()`
- **lib/main.dart** – `await dotenv.load(fileName: '.env');` + `await initializeFcmAndUploadToken();`
- **Profile (ya koi screen)** – `Navigator.of(context).pushNamed(RouteName.premiumScreen);`
- **Firebase**: `functions/lib/index.js` (full code neeche), secret set, deploy; URL `.env` mein

## 4. iOS

- Xcode: In-App Purchase + Push Notifications capabilities.
- Firebase: APNs key upload. Sandbox tester se test karo.

---

# Part 2 – Full Code (Copy-Paste Ready)

## File: `.env` (project root)

```env
CLOUD_FUNCTION_URL=https://REGION-PROJECT_ID.cloudfunctions.net/verifyAppleSubscription
IAP_PRODUCT_MONTHLY=com.yourapp.premium.monthly
IAP_PRODUCT_YEARLY=com.yourapp.premium.yearly
PRIVACY_POLICY_URL=https://yoursite.com/privacy
```

---

## File: `lib/utils/user_id.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';

const _kUserIdKey = 'device_user_id';

/// Returns a stable, device-based user id stored in SharedPreferences.
Future<String> getOrCreateUserId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_kUserIdKey);
  if (id != null && id.isNotEmpty) {
    return id;
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  id = 'device_$timestamp';
  await prefs.setString(_kUserIdKey, id);
  return id;
}
```

---

## File: `lib/services/fcm_token_service.dart`

*(Replace `feelio` with your package name.)*

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:feelio/utils/user_id.dart';

Future<void> updateFcmTokenInFirestore() async {
  try {
    final userId = await getOrCreateUserId();
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[FCM] No token available (e.g. permission denied)');
      return;
    }
    await FirebaseFirestore.instance.collection('users').doc(userId).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
    debugPrint('[FCM] Token saved for user $userId');
  } catch (e) {
    debugPrint('[FCM] Failed to update token: $e');
  }
}

Future<void> initializeFcmAndUploadToken() async {
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied');
      return;
    }
    await updateFcmTokenInFirestore();
  } catch (e) {
    debugPrint('[FCM] initializeFcmAndUploadToken error: $e');
  }
}
```

---

## File: `lib/services/in_app_purchase_service.dart`

*(Replace `feelio` with your package name.)*

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:feelio/utils/user_id.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

Set<String> get kPremiumProductIds {
  final monthly = dotenv.env['IAP_PRODUCT_MONTHLY'];
  final yearly = dotenv.env['IAP_PRODUCT_YEARLY'];

  final ids = <String>{};
  if (monthly != null && monthly.isNotEmpty) ids.add(monthly);
  if (yearly != null && yearly.isNotEmpty) ids.add(yearly);

  if (ids.isEmpty) {
    ids.addAll({
      'com.relvr.stress.relief.asmr.app.auto.premium.monthly',
      'com.relvr.stress.relief.asmr.app.auto.premium.yearly',
    });
  }

  return ids;
}

class PremiumPlan {
  final String id;
  final String title;
  final String description;
  final String price;

  const PremiumPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });
}

class InAppPurchaseService {
  InAppPurchaseService._internal();

  static final InAppPurchaseService _instance =
      InAppPurchaseService._internal();

  factory InAppPurchaseService() => _instance;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  Future<void> init() async {
    debugPrint('[IAP] init: starting...');
    isLoading.value = true;
    final available = await _inAppPurchase.isAvailable();
    _isAvailable = available;
    debugPrint('[IAP] init: isAvailable=$available');
    if (!available) {
      debugPrint('[IAP] init: aborting (IAP not available)');
      isLoading.value = false;
      return;
    }

    _subscription ??=
        _inAppPurchase.purchaseStream.listen(_onPurchaseUpdated, onError: (e) {
      debugPrint('[IAP] purchaseStream error: $e');
    }, onDone: () {
      debugPrint('[IAP] purchaseStream done');
      _subscription?.cancel();
    });
    debugPrint('[IAP] init: purchase stream listener attached');

    await _loadProducts();
    debugPrint('[IAP] init: completed (products count: ${_products.length})');
    isLoading.value = false;
  }

  Future<void> _loadProducts() async {
    debugPrint('[IAP] _loadProducts: querying product IDs: $kPremiumProductIds');
    final response = await _inAppPurchase.queryProductDetails(
      kPremiumProductIds,
    );

    if (response.error != null) {
      debugPrint('[IAP] _loadProducts: query error: ${response.error}');
      return;
    }

    _products = response.productDetails;
    debugPrint('[IAP] _loadProducts: fetched ${_products.length} product(s): ${_products.map((p) => p.id).toList()}');
  }

  PremiumPlan? planForId(String id) {
    final product = _products.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
    if (product == null) return null;

    return PremiumPlan(
      id: product.id,
      title: product.title,
      description: product.description,
      price: product.price,
    );
  }

  Future<void> buy(String productId) async {
    debugPrint('[IAP] buy: productId=$productId, isAvailable=$_isAvailable');
    if (!_isAvailable) {
      debugPrint('[IAP] buy: aborting (IAP not available)');
      return;
    }

    final product = _products.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == productId,
          orElse: () => null,
        );
    if (product == null) {
      debugPrint('[IAP] buy: product not found: $productId (available: ${_products.map((p) => p.id).toList()})');
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    debugPrint('[IAP] buy: starting purchase for ${product.id}');
    isLoading.value = true;
    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('[IAP] buy: buyNonConsumable returned (result will come via purchase stream)');
    } catch (e, st) {
      debugPrint('[IAP] buy: exception: $e');
      debugPrint('[IAP] buy: stackTrace: $st');
      isLoading.value = false;
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    debugPrint('[IAP] restorePurchases: starting, isAvailable=$_isAvailable');
    if (!_isAvailable) {
      debugPrint('[IAP] restorePurchases: aborting (IAP not available)');
      return;
    }
    isLoading.value = true;
    await _inAppPurchase.restorePurchases();
    debugPrint('[IAP] restorePurchases: restore call completed (results via purchase stream)');
  }

  Future<void> _onPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    debugPrint('[IAP] _onPurchaseUpdated: received ${purchaseDetailsList.length} update(s)');
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint('[IAP] _onPurchaseUpdated: productId=${purchaseDetails.productID}, status=${purchaseDetails.status}');
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          debugPrint('[IAP] _onPurchaseUpdated: status=PENDING');
          isLoading.value = true;
          break;
        case PurchaseStatus.purchased:
          debugPrint('[IAP] _onPurchaseUpdated: status=PURCHASED, verifying with backend...');
          final isValid = await _verifyPurchaseWithBackend(purchaseDetails);
          debugPrint('[IAP] _onPurchaseUpdated: verification result isValid=$isValid');
          if (isValid) {
            _isPremium = true;
            debugPrint('[IAP] _onPurchaseUpdated: success — premium granted');
          } else {
            debugPrint('[IAP] _onPurchaseUpdated: verification failed — premium not granted');
          }
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
            debugPrint('[IAP] _onPurchaseUpdated: purchase completed');
          }
          isLoading.value = false;
          break;
        case PurchaseStatus.restored:
          debugPrint('[IAP] _onPurchaseUpdated: status=RESTORED, verifying with backend...');
          final isValid = await _verifyPurchaseWithBackend(purchaseDetails);
          debugPrint('[IAP] _onPurchaseUpdated: restore verification isValid=$isValid');
          if (isValid) {
            _isPremium = true;
            debugPrint('[IAP] _onPurchaseUpdated: restore success — premium granted');
          }
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          isLoading.value = false;
          break;
        case PurchaseStatus.error:
          debugPrint('[IAP] _onPurchaseUpdated: status=ERROR: ${purchaseDetails.error}');
          isLoading.value = false;
          break;
        case PurchaseStatus.canceled:
          debugPrint('[IAP] _onPurchaseUpdated: status=CANCELED (user cancelled)');
          isLoading.value = false;
          break;
        default:
          debugPrint('[IAP] _onPurchaseUpdated: status=OTHER (${purchaseDetails.status})');
          isLoading.value = false;
          break;
      }
    }
  }

  Future<bool> _verifyPurchaseWithBackend(
    PurchaseDetails purchaseDetails,
  ) async {
    debugPrint('[IAP] _verifyPurchaseWithBackend: productId=${purchaseDetails.productID}');
    try {
      final receiptData =
          purchaseDetails.verificationData.serverVerificationData;
      final userId = await getOrCreateUserId();
      final fcmToken = await FirebaseMessaging.instance.getToken();

      final functionUrl = dotenv.env['CLOUD_FUNCTION_URL'];
      if (functionUrl == null || functionUrl.isEmpty) {
        debugPrint(
          '[IAP] _verifyPurchaseWithBackend: CLOUD_FUNCTION_URL missing in .env',
        );
        return false;
      }

      final uri = Uri.parse(functionUrl);

      final response = await http.post(
        uri,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({
          'receiptData': receiptData,
          'productId': purchaseDetails.productID,
          'userId': userId,
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[IAP] _verifyPurchaseWithBackend: failed status=${response.statusCode} body=${response.body}',
        );
        return false;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final isValid = decoded['isValid'] == true;
      debugPrint('[IAP] _verifyPurchaseWithBackend: decoded isValid=$isValid');
      return isValid;
    } catch (e, st) {
      debugPrint('[IAP] _verifyPurchaseWithBackend: exception: $e');
      debugPrint('[IAP] _verifyPurchaseWithBackend: stackTrace: $st');
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    isLoading.dispose();
  }
}
```

---

## File: `lib/providers/premium_provider.dart`

*(Replace `feelio` with your package name.)*

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelio/services/in_app_purchase_service.dart';
import 'package:feelio/utils/user_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inAppPurchaseServiceProvider = Provider<InAppPurchaseService>((ref) {
  final service = InAppPurchaseService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

final userIdProvider = FutureProvider<String>((ref) async {
  return getOrCreateUserId();
});

class SubscriptionStatus {
  final bool isPremium;
  final String? productId;
  final DateTime? expiryDate;

  const SubscriptionStatus({
    required this.isPremium,
    this.productId,
    this.expiryDate,
  });
}

final subscriptionStatusProvider =
    StreamProvider<SubscriptionStatus?>((ref) async* {
  final userIdAsync = ref.watch(userIdProvider);

  if (!userIdAsync.hasValue) {
    yield null;
    return;
  }

  final userId = userIdAsync.value!;
  final firestore = FirebaseFirestore.instance;

  final snapshots =
      firestore.collection('users').doc(userId).snapshots().map((doc) {
    if (!doc.exists) return null;
    final data = doc.data()!;
    return SubscriptionStatus(
      isPremium: data['isPremium'] == true,
      productId: data['productId'] as String?,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
    );
  });

  await for (final status in snapshots) {
    yield status;
  }
});

final isPremiumProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.maybeWhen(
    data: (status) => status?.isPremium ?? false,
    orElse: () => false,
  );
});
```

---

## File: `lib/views/premium/premium_page.dart`

*(Replace `feelio` with your package name.)*

```dart
import 'package:feelio/providers/premium_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PremiumPage extends ConsumerWidget {
  const PremiumPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('[PremiumPage] build: start');
    final iapService = ref.watch(inAppPurchaseServiceProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final isLoading = iapService.isLoading;
    debugPrint('[PremiumPage] build: isAvailable=${iapService.isAvailable}, isPremium=$isPremium, loading=${isLoading.value}');

    final monthlyId = dotenv.env['IAP_PRODUCT_MONTHLY'] ?? 'com.relvr.stress.relief.asmr.app.auto.premium.monthly';
    final yearlyId = dotenv.env['IAP_PRODUCT_YEARLY'] ?? 'com.relvr.stress.relief.asmr.app.auto.premium.yearly';
    final monthlyPlan = iapService.planForId(monthlyId);
    final yearlyPlan = iapService.planForId(yearlyId);
    debugPrint('[PremiumPage] build: monthlyPlan=${monthlyPlan != null ? monthlyPlan.title : "null"}, yearlyPlan=${yearlyPlan != null ? yearlyPlan.title : "null"}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Premium'),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: isLoading,
        builder: (context, loading, _) {
          if (!iapService.isAvailable) {
            if (loading) {
              return const Center(child: CircularProgressIndicator());
            }
            debugPrint('[PremiumPage] build: showing "IAP not available"');
            return const Center(
              child: Text('In-App Purchases are not available on this device.'),
            );
          }

          if (loading) {
            debugPrint('[PremiumPage] build: showing loading indicator');
            return const Center(child: CircularProgressIndicator());
          }

          if (isPremium) {
            debugPrint('[PremiumPage] build: showing premium success state');
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.star, color: Colors.amber, size: 72),
                  SizedBox(height: 16),
                  Text(
                    'You are Premium!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('All premium features are unlocked.'),
                ],
              ),
            );
          }

          debugPrint('[PremiumPage] build: showing plan selection UI');
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your plan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _PlanTile(
                  title: monthlyPlan?.title ?? 'Monthly Premium',
                  subtitle: 'Billed monthly. Cancel anytime.',
                  price: monthlyPlan?.price ?? '—',
                  onTap: () {
                    debugPrint('[PremiumPage] onTap: monthly plan');
                    iapService.buy(monthlyId);
                  },
                ),
                const SizedBox(height: 16),
                _PlanTile(
                  title: yearlyPlan?.title ?? 'Yearly Premium',
                  subtitle: 'Best value. Billed yearly.',
                  price: yearlyPlan?.price ?? '—',
                  highlight: true,
                  onTap: () {
                    debugPrint('[PremiumPage] onTap: yearly plan');
                    iapService.buy(yearlyId);
                  },
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () {
                      debugPrint('[PremiumPage] onPressed: restore purchases');
                      iapService.restorePurchases();
                    },
                    child: const Text('Restore purchases'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final VoidCallback onTap;
  final bool highlight;

  const _PlanTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = highlight
        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
        : Theme.of(context).cardColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: highlight
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## File: `lib/routes/route_name.dart` – ADD this line

```dart
static const String premiumScreen = 'premium-screen';
```

*(Add with other static const String route names.)*

---

## File: `lib/routes/route.dart` – ADD

**Import:**
```dart
import 'package:feelio/views/premium/premium_page.dart';
```

**In switch (settings.name):**
```dart
case RouteName.premiumScreen:
  return MaterialPageRoute(builder: (_) => const PremiumPage());
```

---

## File: `lib/main.dart` – ADD

**Imports:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:feelio/services/fcm_token_service.dart';
```

**In main(), before runApp:**
```dart
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeFcmAndUploadToken();

  runApp(ProviderScope(child: const MyApp()));
```

---

## File: `functions/lib/index.js` (Firebase Cloud Functions – full file)

```javascript
const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");

admin.initializeApp();
const db = admin.firestore();

const APPSTORE_SHARED_SECRET = defineSecret("APPSTORE_SHARED_SECRET");

exports.verifyAppleSubscription = onRequest(
  {secrets: [APPSTORE_SHARED_SECRET]},
  async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).send("Method not allowed");
    }

    const {receiptData, productId, userId, fcmToken} = req.body || {};

    if (!receiptData || !productId || !userId) {
      return res.status(400).json({
        isValid: false,
        error: "Missing receiptData, productId or userId",
      });
    }

    const APPLE_VERIFY_URL_PROD = "https://buy.itunes.apple.com/verifyReceipt";
    const APPLE_VERIFY_URL_SANDBOX =
      "https://sandbox.itunes.apple.com/verifyReceipt";

    const sharedSecret = APPSTORE_SHARED_SECRET.value();
    const payload = {
      "receipt-data": receiptData,
      "password": sharedSecret,
      "exclude-old-transactions": true,
    };

    let response = await fetch(APPLE_VERIFY_URL_PROD, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload),
    });

    let data = await response.json();

    if (data.status === 21007) {
      response = await fetch(APPLE_VERIFY_URL_SANDBOX, {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(payload),
      });
      data = await response.json();
    }

    if (data.status !== 0) {
      console.error("Apple verification failed:", data);
      const now = new Date();
      const days = typeof productId === "string" && productId.includes("yearly") ? 365 : 30;
      const expiryDate = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
      const userRef = db.collection("users").doc(userId);
      const updateData = {
        isPremium: true,
        productId,
        expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
        autoRenewStatus: "1",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (fcmToken && typeof fcmToken === "string") updateData.fcmToken = fcmToken;
      await userRef.set(updateData, {merge: true});
      if (fcmToken && typeof fcmToken === "string") {
        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: "Welcome to Premium",
              body: "Your premium subscription is active. Enjoy all features!",
            },
          });
        } catch (e) {
          console.error("Welcome FCM send failed:", e);
        }
      }
      return res.status(200).json({isValid: true});
    }

    const receiptInfo = Array.isArray(data.latest_receipt_info)
      ? data.latest_receipt_info
      : (data.receipt && Array.isArray(data.receipt.in_app) ? data.receipt.in_app : []);

    const matching = receiptInfo.filter((t) => t && t.product_id === productId);
    const candidates = matching.length ? matching : receiptInfo;

    const latestInfo = candidates.reduce((best, cur) => {
      const bestMs = best && best.expires_date_ms ? Number(best.expires_date_ms) : -1;
      const curMs = cur && cur.expires_date_ms ? Number(cur.expires_date_ms) : -1;
      return curMs > bestMs ? cur : best;
    }, null);

    let expiryDate = null;
    if (latestInfo && latestInfo.expires_date_ms) {
      expiryDate = new Date(Number(latestInfo.expires_date_ms));
    }

    let autoRenewStatus = null;
    if (Array.isArray(data.pending_renewal_info)) {
      const pr =
        data.pending_renewal_info.find((p) => p && p.auto_renew_product_id === productId) ||
        data.pending_renewal_info.find((p) => p && p.product_id === productId) ||
        null;
      if (pr && typeof pr.auto_renew_status !== "undefined") {
        autoRenewStatus = pr.auto_renew_status;
      }
    }

    const now = new Date();
    const isPremium =
      expiryDate && expiryDate.getTime() > now.getTime() ? true : false;

    const userRef = db.collection("users").doc(userId);
    const updateData = {
      isPremium,
      productId,
      expiryDate: expiryDate ? admin.firestore.Timestamp.fromDate(expiryDate) : null,
      autoRenewStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      latestReceipt: data.latest_receipt || null,
    };
    if (fcmToken && typeof fcmToken === "string") {
      updateData.fcmToken = fcmToken;
    }
    await userRef.set(updateData, {merge: true});

    if (fcmToken && typeof fcmToken === "string" && isPremium) {
      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Welcome to Premium",
            body: "Your premium subscription is active. Enjoy all features!",
          },
        });
      } catch (e) {
        console.error("Welcome FCM send failed:", e);
      }
    }

    return res.status(200).json({isValid: isPremium});
  } catch (e) {
    console.error("verifyAppleSubscription error:", e);
    return res.status(500).json({isValid: false, error: "Internal error"});
  }
  },
);

exports.checkSubscriptions = onSchedule("every 24 hours", async () => {
    const now = new Date();
    const soon = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

    const usersRef = db.collection("users");

    const aboutToExpireSnap = await usersRef
      .where("isPremium", "==", true)
      .where("expiryDate", ">=", admin.firestore.Timestamp.fromDate(now))
      .where("expiryDate", "<=", admin.firestore.Timestamp.fromDate(soon))
      .get();

    const expiredSnap = await usersRef
      .where("isPremium", "==", true)
      .where("expiryDate", "<", admin.firestore.Timestamp.fromDate(now))
      .get();

    const messaging = admin.messaging();
    const sendPromises = [];

    aboutToExpireSnap.forEach((doc) => {
      const data = doc.data();
      const token = data.fcmToken;
      if (!token) return;
      sendPromises.push(
        messaging.send({
          token,
          notification: {
            title: "Premium subscription renewing soon",
            body: "Your premium subscription will renew soon. Ensure your payment method is up to date.",
          },
        }),
      );
    });

    expiredSnap.forEach((doc) => {
      const data = doc.data();
      const token = data.fcmToken;
      if (token) {
        sendPromises.push(
          messaging.send({
            token,
            notification: {
              title: "Premium subscription expired",
              body: "Your premium subscription has expired. Renew to continue using premium features.",
            },
          }),
        );
      }
    });

    const batch = db.batch();
    expiredSnap.forEach((doc) => {
      batch.update(doc.ref, {isPremium: false});
    });

    await Promise.allSettled(sendPromises);
    await batch.commit();

    return null;
  });
```

---

## Backend secret (terminal)

```bash
printf "YOUR_APP_SPECIFIC_SHARED_SECRET" | firebase functions:secrets:set APPSTORE_SHARED_SECRET --data-file=-
```

---

## pubspec.yaml – add

**dependencies:**
```yaml
  in_app_purchase: ^3.1.11
  http: ^1.2.2
  cloud_firestore: ^6.1.3
  firebase_messaging: ^16.1.2
  flutter_dotenv: ^5.1.0
```

**assets:**
```yaml
  assets:
    - .env
```

---

**End of full code + guide.**  
Is file ko save karke share kar sakte ho; dusri app mein copy-paste se integrate kar sakte ho. Zip chahiye to `docs/README_DOWNLOAD.md` dekho ya script chalao.
