import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/models/subscription_product.dart';
import 'package:smartapp/models/subscription_verification_models.dart';
import 'package:smartapp/services/fcm_token_service.dart';
import 'package:smartapp/utils/premium_firestore_payload.dart';
import 'package:smartapp/utils/userId.dart';

typedef PremiumActivationHook = Future<void> Function(String productId);

class SubscriptionIAPService extends GetxService {
  static const String _logTag = '[IAP]';
  static const List<String> _fallbackProductIds = <String>[
    'tv.remote.control.app.premium.weekly',
    'tv.remote.control.app.premium.monthly',
    'tv.remote.control.app.premium.yearly',
  ];

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final RxBool isStoreAvailable = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isPurchasing = false.obs;
  final RxBool isRestoring = false.obs;
  final RxnString lastError = RxnString();
  final RxnString lastMessage = RxnString();
  final RxList<SubscriptionProduct> products = <SubscriptionProduct>[].obs;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Set<String> _processedPurchaseKeys = <String>{};
  final Set<String> _inFlightPurchaseKeys = <String>{};
  bool _initialized = false;
  PremiumActivationHook? _premiumActivationHook;

  Future<void> initialize({PremiumActivationHook? premiumActivationHook}) async {
    if (_initialized) return;
    _premiumActivationHook = premiumActivationHook;
    _initialized = true;
    isLoading.value = true;
    lastError.value = null;

    try {
      isStoreAvailable.value = await _inAppPurchase.isAvailable();
      if (!isStoreAvailable.value) {
        _log('Store is not available on this device.');
        lastError.value = 'Store is not available';
        return;
      }

      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdated,
        onError: (Object error, StackTrace stackTrace) {
          _log('purchaseStream error: $error');
          lastError.value = error.toString();
        },
      );

      final Set<String> productIds = _loadProductIdsFromEnv();
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(productIds);

      if (response.error != null) {
        lastError.value = response.error!.message;
        _log('queryProductDetails error: ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        _log('Product IDs not found: ${response.notFoundIDs.join(', ')}');
      }

      final List<SubscriptionProduct> loaded = response.productDetails
          .map(
            (ProductDetails p) => SubscriptionProduct(
              id: p.id,
              title: p.title,
              description: p.description,
              priceLabel: p.price,
              productDetails: p,
            ),
          )
          .toList()
        ..sort((SubscriptionProduct a, SubscriptionProduct b) => a.id.compareTo(b.id));
      products.assignAll(loaded);
      _log('Loaded ${products.length} subscription products.');
    } catch (error) {
      lastError.value = error.toString();
      _log('initialize failed: $error');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> buy(ProductDetails product) async {
    if (!isStoreAvailable.value) {
      lastError.value = 'Store is not available';
      return false;
    }
    if (isPurchasing.value) {
      _log('Ignoring buy() while another purchase is in progress.');
      return false;
    }

    isPurchasing.value = true;
    lastError.value = null;
    lastMessage.value = null;

    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      _log('Starting purchase flow for ${product.id}');
      final bool launched = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!launched) {
        lastError.value = 'Purchase flow did not start';
      } else {
        lastMessage.value = 'Complete your purchase in the store dialog.';
      }
      return launched;
    } catch (error) {
      lastError.value = error.toString();
      _log('buy() failed: $error');
      return false;
    } finally {
      isPurchasing.value = false;
    }
  }

  Future<void> restorePurchases() async {
    if (!isStoreAvailable.value) {
      lastError.value = 'Store is not available';
      return;
    }
    _log('restorePurchases requested.');
    isRestoring.value = true;
    lastError.value = null;
    lastMessage.value = null;
    try {
      await _inAppPurchase.restorePurchases();
      lastMessage.value = 'Restore request sent. Verifying purchases...';
    } catch (error) {
      lastError.value = error.toString();
      _log('restorePurchases failed: $error');
    } finally {
      isRestoring.value = false;
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      final String purchaseKey = _buildPurchaseKey(purchase);
      if (_processedPurchaseKeys.contains(purchaseKey)) {
        _log('Duplicate purchase event skipped: $purchaseKey');
        continue;
      }
      if (_inFlightPurchaseKeys.contains(purchaseKey)) {
        _log('Purchase already in-flight: $purchaseKey');
        continue;
      }

      _inFlightPurchaseKeys.add(purchaseKey);
      try {
        _log(
          'Purchase update received status=${purchase.status.name} '
          'productId=${purchase.productID} purchaseID=${purchase.purchaseID}',
        );
        switch (purchase.status) {
          case PurchaseStatus.pending:
            lastMessage.value = 'Purchase is pending approval.';
            break;
          case PurchaseStatus.purchased:
            await _handleVerifiedFlow(purchase: purchase, isRestore: false);
            break;
          case PurchaseStatus.restored:
            await _handleVerifiedFlow(purchase: purchase, isRestore: true);
            break;
          case PurchaseStatus.error:
            lastError.value = purchase.error?.message ?? 'Purchase error';
            _log('Purchase error: ${purchase.error}');
            await _completePurchaseIfNeeded(purchase);
            _processedPurchaseKeys.add(purchaseKey);
            break;
          case PurchaseStatus.canceled:
            lastError.value = 'Purchase canceled';
            _log('Purchase canceled by user.');
            await _completePurchaseIfNeeded(purchase);
            _processedPurchaseKeys.add(purchaseKey);
            break;
        }
      } catch (error) {
        _log('_onPurchaseUpdated failure: $error');
        lastError.value = error.toString();
      } finally {
        _inFlightPurchaseKeys.remove(purchaseKey);
      }
    }
  }

  Future<void> _handleVerifiedFlow({
    required PurchaseDetails purchase,
    required bool isRestore,
  }) async {
    final SubscriptionVerificationResult verification = await _verifyPurchaseWithBackend(
      purchase,
      isRestore: isRestore,
    );
    if (verification.isValid) {
      _log('Verification succeeded for ${purchase.productID}');
      await _unlockPremium(
        purchase: purchase,
        productId: purchase.productID,
        verification: verification,
        isRestore: isRestore,
      );
      _processedPurchaseKeys.add(_buildPurchaseKey(purchase));
      await _completePurchaseIfNeeded(purchase);
      lastMessage.value = isRestore
          ? 'Premium restored successfully.'
          : 'Premium unlocked successfully.';
      return;
    }

    _log('Verification failed for ${purchase.productID}: ${verification.message}');
    lastError.value = verification.message ?? 'Purchase verification failed';
    if (verification.isExpired || _isInactiveState(verification.state)) {
      await _downgradePremium(
        reason: verification.message ??
            'Subscription inactive or expired. Premium access removed.',
      );
    }
    await _completePurchaseIfNeeded(purchase);
    _processedPurchaseKeys.add(_buildPurchaseKey(purchase));
  }

  Future<SubscriptionVerificationResult> _verifyPurchaseWithBackend(
    PurchaseDetails purchase, {
    required bool isRestore,
  }) async {
    final String userId = await getOrCreateUserId();
    final String? fcmToken = await getFcmTokenWithRetry();
    final String platform = _platformLabel();
    final SubscriptionVerificationPayload payload = SubscriptionVerificationPayload(
      receiptData: purchase.verificationData.serverVerificationData,
      productId: purchase.productID,
      userId: userId,
      platform: platform,
      purchaseToken: _extractAndroidPurchaseToken(purchase),
      isRestore: isRestore,
      fcmToken: fcmToken,
      transactionId: purchase.purchaseID,
      orderId: _extractAndroidOrderId(purchase),
    );

    _log(
      'Verifying purchase with backend '
      'productId=${payload.productId} platform=${payload.platform} isRestore=$isRestore',
    );
    if (payload.platform == 'android') {
      _log(
        'Android payload includes purchaseToken for backend verification. '
        'If backend currently validates Apple only, Android purchases will remain locked until backend support is added.',
      );
    }

    final SubscriptionVerificationResult callableResult =
        await _verifyPurchaseViaCallable(payload);
    if (callableResult.isValid || callableResult.message != 'CALLABLE_FALLBACK') {
      return callableResult;
    }

    _log('Callable verification unavailable. Falling back to HTTP endpoint.');
    return _verifyPurchaseViaHttp(payload);
  }

  Future<SubscriptionVerificationResult> _verifyPurchaseViaCallable(
    SubscriptionVerificationPayload payload,
  ) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable(
        'verifyIapPurchaseCallable',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final HttpsCallableResult<dynamic> response = await callable.call(payload.toJson());
      final dynamic data = response.data;
      if (data is! Map) {
        return SubscriptionVerificationResult(
          isValid: false,
          message: 'Unexpected callable response format',
        );
      }
      final Map<String, dynamic> body = data.cast<String, dynamic>();
      return SubscriptionVerificationResult.fromJson(body);
    } on FirebaseFunctionsException catch (error) {
      _log('Callable verification error (${error.code}): ${error.message}');
      final bool shouldFallback = <String>{
        'unavailable',
        'not-found',
        'unimplemented',
        'deadline-exceeded',
        'cancelled',
        // Same backend over HTTP can succeed if callable misconfigured / wrong region.
        'internal',
      }.contains(error.code);
      if (!shouldFallback) {
        return SubscriptionVerificationResult(
          isValid: false,
          message: error.message ?? 'Callable verification failed',
        );
      }
      return SubscriptionVerificationResult(
        isValid: false,
        message: 'CALLABLE_FALLBACK',
      );
    } catch (error) {
      _log('Callable verification failed: $error');
      return SubscriptionVerificationResult(
        isValid: false,
        message: 'CALLABLE_FALLBACK',
      );
    }
  }

  Future<SubscriptionVerificationResult> _verifyPurchaseViaHttp(
    SubscriptionVerificationPayload payload,
  ) async {
    final String endpoint = dotenv.env['IAP_VERIFY_FUNCTION_URL']?.trim() ?? '';
    if (endpoint.isEmpty) {
      return SubscriptionVerificationResult(
        isValid: false,
        message: 'IAP verification endpoint is missing',
      );
    }

    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final http.Response response = await http
            .post(
              Uri.parse(endpoint),
              headers: <String, String>{'Content-Type': 'application/json'},
              body: jsonEncode(payload.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          _log('Verification HTTP ${response.statusCode}: ${response.body}');
          if (attempt == maxAttempts) {
            return SubscriptionVerificationResult(
              isValid: false,
              message: 'Verification request failed (${response.statusCode})',
            );
          }
        } else {
          final Map<String, dynamic> body = (jsonDecode(response.body) as Map).cast<String, dynamic>();
          final SubscriptionVerificationResult result =
              SubscriptionVerificationResult.fromJson(body);
          _log('Verification response isValid=${result.isValid}');
          return result;
        }
      } catch (error) {
        _log('Verification attempt $attempt failed: $error');
        if (attempt == maxAttempts) {
          return SubscriptionVerificationResult(
            isValid: false,
            message: 'Verification failed after retries',
          );
        }
      }

      await Future<void>.delayed(Duration(milliseconds: attempt * 700));
    }

    return SubscriptionVerificationResult(
      isValid: false,
      message: 'Unknown verification failure',
    );
  }

  Future<void> _unlockPremium({
    required PurchaseDetails purchase,
    required String productId,
    required SubscriptionVerificationResult verification,
    required bool isRestore,
  }) async {
    if (!Get.isRegistered<PremiumController>()) {
      _log('PremiumController not registered. Skipping premium unlock.');
      return;
    }
    final String? fcmToken = await getFcmTokenWithRetry();
    await Get.find<PremiumController>().setPremium(
      enabled: true,
      productId: productId,
      autoRenew: _extractAutoRenew(verification),
      expiryDate: _parseExpiryDate(verification.expiryTime),
      purchaseDate:
          _parseDate(verification.purchaseDate) ??
          _parseMillisDate(purchase.transactionDate),
      fcmToken: fcmToken,
    );
    await _persistPremiumSubscriptionMetadata(
      purchase: purchase,
      productId: productId,
      verification: verification,
      fcmToken: fcmToken,
      isRestore: isRestore,
    );
    await showLocalSubscriptionNotification(
      title: 'Premium Activated',
      body: 'Your subscription is active. Remote Style is unlocked.',
    );

    if (_premiumActivationHook != null) {
      await _premiumActivationHook!(productId);
    }
  }

  Future<void> _persistPremiumSubscriptionMetadata({
    required PurchaseDetails purchase,
    required String productId,
    required SubscriptionVerificationResult verification,
    String? fcmToken,
    required bool isRestore,
  }) async {
    try {
      final String userId = await getOrCreateUserId();
      final String platform = _platformLabel();
      final DateTime? expiryDate = _parseExpiryDate(verification.expiryTime);
      final DateTime? purchaseDate =
          _parseDate(verification.purchaseDate) ??
          _parseMillisDate(purchase.transactionDate) ??
          DateTime.now().toUtc();
      final Map<String, dynamic> payload = buildPremiumFirestorePayload(
        userId: userId,
        isPremium: true,
        source: 'subscription_iap_service',
        productId: productId,
        autoRenew: _extractAutoRenew(verification),
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        platform: platform,
        state: verification.state,
        transactionId: purchase.purchaseID,
        orderId: _extractAndroidOrderId(purchase),
        isRestore: isRestore,
        fcmToken: fcmToken,
        includeIapMetadata: true,
      );

      await FirebaseFirestore.instance.collection('Users').doc(userId).set(
            payload,
            SetOptions(merge: true),
          );
      _log('Premium subscription metadata saved for user=$userId');
    } catch (error) {
      _log('Failed to persist premium subscription metadata: $error');
    }
  }

  Future<void> _completePurchaseIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _inAppPurchase.completePurchase(purchase);
      _log('completePurchase called for ${purchase.productID}');
    } catch (error) {
      _log('completePurchase failed for ${purchase.productID}: $error');
    }
  }

  Set<String> _loadProductIdsFromEnv() {
    final String weekly = dotenv.env['IAP_PRODUCT_WEEKLY']?.trim() ?? '';
    final String monthly = dotenv.env['IAP_PRODUCT_MONTHLY']?.trim() ?? '';
    final String yearly = dotenv.env['IAP_PRODUCT_YEARLY']?.trim() ?? '';
    final Set<String> ids = <String>{
      if (weekly.isNotEmpty) weekly,
      if (monthly.isNotEmpty) monthly,
      if (yearly.isNotEmpty) yearly,
      ..._fallbackProductIds,
    };
    return ids;
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return defaultTargetPlatform.name;
  }

  String? _extractAndroidPurchaseToken(PurchaseDetails purchase) {
    if (purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.purchaseToken;
    }
    return null;
  }

  String? _extractAndroidOrderId(PurchaseDetails purchase) {
    if (purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.orderId;
    }
    return null;
  }

  String _buildPurchaseKey(PurchaseDetails purchase) {
    return '${purchase.productID}|${purchase.purchaseID ?? ''}|${purchase.transactionDate ?? ''}';
  }

  bool _extractAutoRenew(SubscriptionVerificationResult verification) {
    final raw = verification.raw;
    if (raw == null) return false;
    final dynamic direct = raw['autoRenew'] ?? raw['auto_renew'];
    if (direct is bool) return direct;

    final dynamic nested = raw['subscription'] is Map<String, dynamic>
        ? (raw['subscription'] as Map<String, dynamic>)['autoRenew']
        : null;
    if (nested is bool) return nested;
    return false;
  }

  DateTime? _parseExpiryDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  DateTime? _parseMillisDate(String? millis) {
    if (millis == null || millis.isEmpty) return null;
    final int? parsed = int.tryParse(millis);
    if (parsed == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(parsed, isUtc: true);
  }

  bool _isInactiveState(String? state) {
    if (state == null) return false;
    const Set<String> inactive = <String>{
      'APPLE_INACTIVE',
      'SUBSCRIPTION_STATE_EXPIRED',
      'SUBSCRIPTION_STATE_CANCELED',
      'SUBSCRIPTION_STATE_REVOKED',
      'SUBSCRIPTION_STATE_PAUSED',
    };
    return inactive.contains(state);
  }

  Future<void> _downgradePremium({required String reason}) async {
    if (!Get.isRegistered<PremiumController>()) return;
    await Get.find<PremiumController>().setPremium(enabled: false);
    lastMessage.value = reason;
  }

  void _log(String message) {
    debugPrint('$_logTag $message');
  }

  @override
  void onClose() {
    _purchaseSubscription?.cancel();
    super.onClose();
  }
}
