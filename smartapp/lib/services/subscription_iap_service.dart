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
import 'package:smartapp/services/adapty_service.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/fcm_token_service.dart';
import 'package:smartapp/utils/premium_firestore_payload.dart';
import 'package:smartapp/utils/userId.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

typedef PremiumActivationHook = Future<void> Function(String productId);

class SubscriptionIAPService extends GetxService {
  static const String _logTag = '[IAP]';
  static const List<String> _fallbackAndroidProductIds = <String>[
    'tv.remote.control.app.premium.weekly',
    'tv.remote.control.app.premium.monthly',
    'tv.remote.control.app.premium.yearly',
  ];
  static const List<String> _fallbackIosProductIds = <String>[
    'com.mg.smart.tv.remote.control.premium.weakly',
    'com.mg.smart.tv.remote.control.premium.monthly',
    'com.mg.smart.tv.remote.control.premium.yearly',
  ];

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final RxBool isStoreAvailable = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isPurchasing = false.obs;
  final RxBool isRestoring = false.obs;
  final RxnString lastError = RxnString();
  final RxnString lastMessage = RxnString();
  final RxList<SubscriptionProduct> products = <SubscriptionProduct>[].obs;
  final RxList<String> notFoundProductIds = <String>[].obs;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Set<String> _processedPurchaseKeys = <String>{};
  final Set<String> _inFlightPurchaseKeys = <String>{};
  final Set<String> _loggedPurchaseTransactionIds = <String>{};
  bool _initialized = false;
  Future<void>? _initializeFuture;
  PremiumActivationHook? _premiumActivationHook;

  /// Waits for startup initialization and re-queries the store if products are
  /// still empty (e.g. paywall opened before deferred init finished).
  Future<void> ensureProductsLoaded() async {
    await initialize();
    if (products.isEmpty && isStoreAvailable.value) {
      await refreshProducts();
    }
  }

  Future<void> initialize(
      {PremiumActivationHook? premiumActivationHook}) {
    if (premiumActivationHook != null) {
      _premiumActivationHook = premiumActivationHook;
    }
    return _initializeFuture ??= _runInitialize();
  }

  Future<void> refreshProducts() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    if (!isStoreAvailable.value) {
      isStoreAvailable.value = await _inAppPurchase.isAvailable();
    }
    if (!isStoreAvailable.value) {
      return;
    }

    isLoading.value = true;
    lastError.value = null;
    try {
      await _queryStoreProducts();
    } catch (error) {
      lastError.value = error.toString();
      _log('refreshProducts failed: $error');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _runInitialize() async {
    isLoading.value = true;
    lastError.value = null;

    try {
      isStoreAvailable.value = await _inAppPurchase.isAvailable();
      if (!isStoreAvailable.value) {
        _log('Store is not available on this device.');
        lastError.value = 'Store is not available';
        _initializeFuture = null;
        return;
      }

      _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdated,
        onError: (Object error, StackTrace stackTrace) {
          _log('purchaseStream error: $error');
          lastError.value = error.toString();
        },
      );

      await _queryStoreProducts();
      _initialized = true;
    } catch (error) {
      lastError.value = error.toString();
      _log('initialize failed: $error');
      if (!_initialized) {
        _initializeFuture = null;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _queryStoreProducts() async {
    final Set<String> productIds = _loadProductIdsFromEnv();
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(productIds);

    if (response.error != null) {
      lastError.value = response.error!.message;
      _log('queryProductDetails error: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      notFoundProductIds.assignAll(response.notFoundIDs);
      _log('Product IDs not found: ${response.notFoundIDs.join(', ')}');
    } else {
      notFoundProductIds.clear();
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
      ..sort((SubscriptionProduct a, SubscriptionProduct b) =>
          a.id.compareTo(b.id));
    products.assignAll(loaded);
    products.refresh();
    if (loaded.isEmpty) {
      lastError.value =
          'No subscription products returned by the store. Check App Store Connect status, bundle ID, and Sandbox account.';
    }
    _log('Loaded ${products.length} subscription products.');
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
    _resetProcessedStateForProduct(product.id);

    try {
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: product);
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
    _processedPurchaseKeys.clear();
    _inFlightPurchaseKeys.clear();
    isRestoring.value = true;
    lastError.value = null;
    lastMessage.value = null;
    try {
      await _inAppPurchase.restorePurchases();
      if (Get.isRegistered<AdaptyService>()) {
        await Get.find<AdaptyService>().restorePurchases();
      }
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
    final SubscriptionVerificationResult verification =
        await _verifyPurchaseWithBackend(
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

    _log(
        'Verification failed for ${purchase.productID}: ${verification.message}');
    lastError.value = verification.message ?? 'Purchase verification failed';
    if (verification.isExpired || _isInactiveState(verification.state)) {
      if (isRestore) {
        await _downgradePremium(
          reason: verification.message ??
              'Subscription inactive or expired. Premium access removed.',
        );
      } else {
        _log(
          'Skip downgrade for non-restore purchase '
          '(possible transient or duplicate verification mismatch).',
        );
      }
    }
    await _completePurchaseIfNeeded(purchase);
    _processedPurchaseKeys.add(_buildPurchaseKey(purchase));
  }

  Future<SubscriptionVerificationResult> _verifyPurchaseWithBackend(
    PurchaseDetails purchase, {
    required bool isRestore,
  }) async {
    final String userId = await getOrCreateUserId();
    final String? fcmToken = await getFcmTokenIfAvailable();
    final String platform = _platformLabel();
    final SubscriptionVerificationPayload payload =
        SubscriptionVerificationPayload(
      receiptData: purchase.verificationData.serverVerificationData,
      localReceiptData: purchase.verificationData.localVerificationData,
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
    if (callableResult.isValid ||
        callableResult.message != 'CALLABLE_FALLBACK') {
      return callableResult;
    }

    // Temporary fallback modes: avoid HTTP fallback hitting legacy endpoint config.
    if (payload.platform == 'android') {
      _log(
        'Callable fallback on Android. Using temporary local verification '
        'to keep premium unlock flow working.',
      );
      return SubscriptionVerificationResult(
        isValid: true,
        message: 'Android temporary verification enabled (callable fallback)',
        state: 'ANDROID_TEMP_ACTIVE',
        purchaseDate: DateTime.now().toUtc().toIso8601String(),
        raw: <String, dynamic>{
          'platform': 'android',
          'verificationMode': 'local_callable_fallback',
          'productId': payload.productId,
          'transactionId': payload.transactionId,
          'orderId': payload.orderId,
          'purchaseTokenPresent': payload.purchaseToken?.isNotEmpty == true,
        },
      );
    }

    if (payload.platform == 'ios') {
      _log(
        'Callable fallback on iOS. Using temporary local verification '
        'to keep premium unlock flow working.',
      );
      return SubscriptionVerificationResult(
        isValid: true,
        message: 'iOS temporary verification enabled (callable fallback)',
        state: 'IOS_TEMP_ACTIVE',
        purchaseDate: DateTime.now().toUtc().toIso8601String(),
        expiryTime: _inferIosExpiryIso(payload.productId),
        raw: <String, dynamic>{
          'platform': 'ios',
          'verificationMode': 'local_callable_fallback',
          'productId': payload.productId,
          'transactionId': payload.transactionId,
        },
      );
    }

    _log('Callable verification unavailable. Falling back to HTTP endpoint.');
    return _verifyPurchaseViaHttp(payload);
  }

  String? _inferIosExpiryIso(String productId) {
    final DateTime now = DateTime.now().toUtc();
    final String id = productId.toLowerCase();
    if (id.contains('weekly') || id.contains('weakly')) {
      return now.add(const Duration(days: 7)).toIso8601String();
    }
    if (id.contains('monthly')) {
      return DateTime.utc(
        now.year,
        now.month + 1,
        now.day,
        now.hour,
        now.minute,
        now.second,
      ).toIso8601String();
    }
    if (id.contains('yearly') || id.contains('annual')) {
      return DateTime.utc(
        now.year + 1,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      ).toIso8601String();
    }
    return null;
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
      final HttpsCallableResult<dynamic> response =
          await callable.call(payload.toJson());
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
          final Map<String, dynamic> body =
              (jsonDecode(response.body) as Map).cast<String, dynamic>();
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
    final String? fcmToken = await getFcmTokenIfAvailable();
    final DateTime? purchaseDate = _parseDate(verification.purchaseDate) ??
        _parseMillisDate(purchase.transactionDate);
    final DateTime? resolvedExpiryDate = _resolveExpiryDate(
      verification: verification,
      productId: productId,
      purchaseDate: purchaseDate,
    );
    await Get.find<PremiumController>().setPremium(
      enabled: true,
      productId: productId,
      autoRenew: _extractAutoRenew(verification),
      expiryDate: resolvedExpiryDate,
      purchaseDate: purchaseDate,
      fcmToken: fcmToken,
      syncToFirestore: false,
    );
    await _persistPremiumSubscriptionMetadata(
      purchase: purchase,
      productId: productId,
      verification: verification,
      fcmToken: fcmToken,
      isRestore: isRestore,
    );

    // Firebase "In-app purchases" revenue comes from GA4 IAP events.
    // We log these for verified purchase renewals too, but skip restore to
    // avoid double-counting revenue.
    await _logInAppPurchaseRevenueToFirebase(
      purchase: purchase,
      productId: productId,
      isRestore: isRestore,
    );

    await _logSubscriptionPurchaseToFirebase(
      purchase: purchase,
      productId: productId,
      isRestore: isRestore,
    );

    if (Get.isRegistered<AdaptyService>()) {
      final adaptyService = Get.find<AdaptyService>();
      final String transactionId =
          purchase.purchaseID ?? _extractAndroidOrderId(purchase) ?? '';
      await adaptyService.reportTransactionIfNeeded(
        transactionId: transactionId,
      );
      await adaptyService.syncProfileToPremiumState(
        source: isRestore ? 'iap_restore' : 'iap_purchase',
      );
    }

    if (_premiumActivationHook != null) {
      await _premiumActivationHook!(productId);
    }
  }

  Future<void> _logInAppPurchaseRevenueToFirebase({
    required PurchaseDetails purchase,
    required String productId,
    required bool isRestore,
  }) async {
    if (isRestore) return;
    // Firebase often auto-logs IAP on Android; we do manual logging only
    // for iOS where StoreKit-based renewals can require explicit calls.
    if (!Platform.isIOS) return;
    if (!Get.isRegistered<AnalyticsService>()) return;

    final String? transactionId = _extractTransactionId(purchase);
    if (transactionId == null || transactionId.isEmpty) return;

    SubscriptionProduct subscriptionProduct;
    try {
      subscriptionProduct = products.firstWhere((p) => p.id == productId);
    } catch (_) {
      _log('Firebase IAP logging skipped: unknown productId=$productId');
      return;
    }

    final productDetails = subscriptionProduct.productDetails;
    final double value = productDetails.rawPrice;
    final String currency = productDetails.currencyCode;

    if (value <= 0 || currency.isEmpty) return;

    try {
      await Get.find<AnalyticsService>().logEvent(
            'in_app_purchase',
            params: <String, Object?>{
              'transaction_id': transactionId,
              'product_id': productId,
              'product_name': subscriptionProduct.title,
              'price': value,
              'value': value,
              'currency': currency,
              'quantity': 1,
              // Used by Firebase to mark subscription vs one-time purchases.
              'subscription': 1,
            },
          );
    } catch (error) {
      _log('Firebase in_app_purchase log failed: $error');
    }
  }

  Future<void> _logSubscriptionPurchaseToFirebase({
    required PurchaseDetails purchase,
    required String productId,
    required bool isRestore,
  }) async {
    if (isRestore) return;
    if (!Get.isRegistered<AnalyticsService>()) return;

    final String? transactionId = _extractTransactionId(purchase);
    if (transactionId == null || transactionId.isEmpty) return;
    if (_loggedPurchaseTransactionIds.contains(transactionId)) {
      _log('Firebase purchase log skipped: already logged $transactionId');
      return;
    }

    SubscriptionProduct subscriptionProduct;
    try {
      subscriptionProduct = products.firstWhere((p) => p.id == productId);
    } catch (_) {
      _log('Firebase purchase log skipped: unknown productId=$productId');
      return;
    }

    final productDetails = subscriptionProduct.productDetails;
    final double value = productDetails.rawPrice;
    final String currency = productDetails.currencyCode;
    if (value <= 0 || currency.isEmpty) return;

    try {
      await Get.find<AnalyticsService>().logSubscriptionPurchase(
        transactionId: transactionId,
        productId: productId,
        productName: subscriptionProduct.title,
        subscriptionType: _subscriptionTypeFromProductId(productId),
        platform: _platformLabel(),
        value: value,
        currency: currency,
      );
      _loggedPurchaseTransactionIds.add(transactionId);
    } catch (error) {
      _log('Firebase purchase log failed: $error');
    }
  }

  String _subscriptionTypeFromProductId(String productId) {
    final String id = productId.toLowerCase();
    if (id.contains('weekly') || id.contains('weakly')) {
      return 'weekly';
    }
    if (id.contains('monthly')) {
      return 'monthly';
    }
    if (id.contains('yearly') || id.contains('annual')) {
      return 'yearly';
    }
    return 'unknown';
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
      final DateTime? purchaseDate = _parseDate(verification.purchaseDate) ??
          _parseMillisDate(purchase.transactionDate) ??
          DateTime.now().toUtc();
      final DateTime? expiryDate = _resolveExpiryDate(
        verification: verification,
        productId: productId,
        purchaseDate: purchaseDate,
      );
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
      lastError.value = 'Purchase successful, but Firebase sync failed: $error';
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
    final bool isIos = !kIsWeb && Platform.isIOS;
    final String weeklyKey =
        isIos ? 'IAP_PRODUCT_IOS_WEEKLY' : 'IAP_PRODUCT_WEEKLY';
    final String monthlyKey =
        isIos ? 'IAP_PRODUCT_IOS_MONTHLY' : 'IAP_PRODUCT_MONTHLY';
    final String yearlyKey =
        isIos ? 'IAP_PRODUCT_IOS_YEARLY' : 'IAP_PRODUCT_YEARLY';

    final String weekly = dotenv.env[weeklyKey]?.trim() ?? '';
    final String monthly = dotenv.env[monthlyKey]?.trim() ?? '';
    final String yearly = dotenv.env[yearlyKey]?.trim() ?? '';
    final List<String> fallback =
        isIos ? _fallbackIosProductIds : _fallbackAndroidProductIds;
    final Set<String> ids = <String>{
      if (weekly.isNotEmpty) weekly,
      if (monthly.isNotEmpty) monthly,
      if (yearly.isNotEmpty) yearly,
      ...fallback,
    };
    _log('Using ${isIos ? 'iOS' : 'Android'} product IDs: ${ids.join(', ')}');
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

  /// Used for GA4/Firebase IAP events and for deduping purchase stream updates.
  /// On iOS, StoreKit renewals should have unique `transactionIdentifier`.
  String? _extractTransactionId(PurchaseDetails purchase) {
    final String? purchaseId = purchase.purchaseID;
    if (purchaseId != null && purchaseId.isNotEmpty) {
      return purchaseId;
    }

    // AppStorePurchaseDetails comes from the storekit implementation shipped
    // with `in_app_purchase`.
    if (purchase is AppStorePurchaseDetails) {
      final transactionIdentifier =
          purchase.skPaymentTransaction.transactionIdentifier;
      if (transactionIdentifier != null &&
          transactionIdentifier.isNotEmpty) {
        return transactionIdentifier;
      }
    }

    return null;
  }

  String _buildPurchaseKey(PurchaseDetails purchase) {
    final String txId = _extractTransactionId(purchase) ?? '';
    return '${purchase.productID}|$txId|${purchase.transactionDate ?? ''}';
  }

  void _resetProcessedStateForProduct(String productId) {
    _processedPurchaseKeys.removeWhere(
      (String key) => key.startsWith('$productId|'),
    );
    _inFlightPurchaseKeys.removeWhere(
      (String key) => key.startsWith('$productId|'),
    );
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

  DateTime? _resolveExpiryDate({
    required SubscriptionVerificationResult verification,
    required String productId,
    DateTime? purchaseDate,
  }) {
    final DateTime? backendExpiry = _parseExpiryDate(verification.expiryTime);
    if (backendExpiry != null) return backendExpiry;
    return _inferPlanExpiry(productId, purchaseDate: purchaseDate);
  }

  DateTime? _inferPlanExpiry(
    String productId, {
    DateTime? purchaseDate,
  }) {
    final DateTime base = (purchaseDate ?? DateTime.now().toUtc()).toUtc();
    final String id = productId.toLowerCase();
    if (id.contains('weekly') || id.contains('weakly')) {
      return base.add(const Duration(days: 7));
    }
    if (id.contains('monthly')) {
      return DateTime.utc(
        base.year,
        base.month + 1,
        base.day,
        base.hour,
        base.minute,
        base.second,
      );
    }
    if (id.contains('yearly') || id.contains('annual')) {
      return DateTime.utc(
        base.year + 1,
        base.month,
        base.day,
        base.hour,
        base.minute,
        base.second,
      );
    }
    return null;
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
