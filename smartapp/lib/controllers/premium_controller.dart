import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:smartapp/services/fcm_token_service.dart';
import 'package:smartapp/utils/premium_firestore_payload.dart';
import 'package:smartapp/utils/userId.dart';

class PremiumController extends GetxController {
  final RxBool isPremium = false.obs;
  final RxnString activeProductId = RxnString();
  final Rxn<DateTime> expiryDate = Rxn<DateTime>();
  final RxBool isSyncingPremium = false.obs;
  final RxnString premiumSyncError = RxnString();
  bool _isCacheRestored = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _premiumDocSub;

  @override
  void onInit() {
    super.onInit();
    unawaited(_bootstrapPremiumState());
  }

  Future<void> _bootstrapPremiumState() async {
    await _restoreCache();
    await syncPremiumFromFirestore();
    await _startRealtimePremiumSync();
    unawaited(_syncUserProfileToFirestore());
  }

  Future<void> _restoreCache() async {
    // Local premium cache disabled by request; Firestore remains source of truth.
    _isCacheRestored = true;
  }

  Future<void> syncPremiumFromFirestore() async {
    if (!_isCacheRestored) {
      await _restoreCache();
    }
    isSyncingPremium.value = true;
    premiumSyncError.value = null;
    try {
      final String deviceId = await getOrCreateUserId();
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(deviceId)
              .get();
      final Map<String, dynamic>? data = snapshot.data();

      print("🔥 Firestore Raw Data: $data");

      if (data == null) {
        print("❌ No data found in Firestore");
        return;
      }
      print("isPremium: ${data['isPremium']}");
      print("expiryDate: ${data['expiryDate']}");
      print("productId: ${data['premiumProductId']}");
      final bool remotePremium = data['isPremium'] == true;
      final DateTime? remoteExpiryDate =
          _parseDate(data['expiryDate']) ?? _parseDate(data['premiumExpiry']);
      final bool notExpired = remoteExpiryDate == null ||
          remoteExpiryDate.isAfter(DateTime.now().toUtc());
      final bool resolvedPremium = remotePremium && notExpired;
      final String? remoteProductId = data['premiumProductId']?.toString();
      await _persistLocalState(
        enabled: resolvedPremium,
        productId: resolvedPremium ? remoteProductId : null,
        expiryDate: remoteExpiryDate,
      );
    } catch (error) {
      premiumSyncError.value = error.toString();
      debugPrint('[PREMIUM] Firestore sync failed: $error');
    } finally {
      isSyncingPremium.value = false;
    }
  }

  Future<void> _startRealtimePremiumSync() async {
    try {
      final String deviceId = await getOrCreateUserId();
      await _premiumDocSub?.cancel();
      _premiumDocSub = FirebaseFirestore.instance
          .collection('Users')
          .doc(deviceId)
          .snapshots()
          .listen((snapshot) async {
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) return;

        final bool remotePremium = data['isPremium'] == true;
        final DateTime? remoteExpiryDate =
            _parseDate(data['expiryDate']) ?? _parseDate(data['premiumExpiry']);
        final bool notExpired = remoteExpiryDate == null ||
            remoteExpiryDate.isAfter(DateTime.now().toUtc());
        final bool resolvedPremium = remotePremium && notExpired;
        final String? remoteProductId = data['premiumProductId']?.toString();

        final bool changed = isPremium.value != resolvedPremium ||
            activeProductId.value !=
                (resolvedPremium ? remoteProductId : null) ||
            expiryDate.value?.toUtc() !=
                (resolvedPremium ? remoteExpiryDate?.toUtc() : null);
        if (!changed) return;

        await _persistLocalState(
          enabled: resolvedPremium,
          productId: resolvedPremium ? remoteProductId : null,
          expiryDate: remoteExpiryDate,
        );
      });
    } catch (error) {
      premiumSyncError.value = error.toString();
      debugPrint('[PREMIUM] Realtime sync setup failed: $error');
    }
  }

  Future<void> setPremium({
    required bool enabled,
    String? productId,
    bool? autoRenew,
    DateTime? expiryDate,
    DateTime? purchaseDate,
    String? fcmToken,
  }) async {
    await _persistLocalState(
      enabled: enabled,
      productId: enabled ? productId : null,
      expiryDate: enabled ? expiryDate : null,
    );
    await _syncUserProfileToFirestore(
      autoRenew: autoRenew,
      expiryDate: expiryDate,
      purchaseDate: purchaseDate,
      fcmToken: fcmToken,
    );
  }

  Future<void> _persistLocalState({
    required bool enabled,
    String? productId,
    DateTime? expiryDate,
  }) async {
    isPremium.value = enabled;
    activeProductId.value = enabled ? productId : null;
    this.expiryDate.value = enabled ? expiryDate?.toUtc() : null;
  }

  Future<void> _syncUserProfileToFirestore({
    bool? autoRenew,
    DateTime? expiryDate,
    DateTime? purchaseDate,
    String? fcmToken,
  }) async {
    try {
      final String deviceId = await getOrCreateUserId();
      final bool premiumEnabled = isPremium.value;
      final String? resolvedFcmToken = fcmToken ?? await getFcmTokenWithRetry();

      final Map<String, dynamic> payload = buildPremiumFirestorePayload(
        userId: deviceId,
        isPremium: premiumEnabled,
        source: 'premium_controller',
        productId: activeProductId.value,
        autoRenew: autoRenew,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        fcmToken: resolvedFcmToken,
      );

      await FirebaseFirestore.instance.collection('Users').doc(deviceId).set(
            payload,
            SetOptions(merge: true),
          );
    } catch (error) {
      // Firestore sync should never break local premium state updates.
      debugPrint('[PREMIUM] Firestore profile sync failed: $error');
    }
  }

  DateTime? _parseDate(dynamic rawDate) {
    if (rawDate == null) return null;
    if (rawDate is Timestamp) return rawDate.toDate().toUtc();
    if (rawDate is DateTime) return rawDate.toUtc();
    if (rawDate is String) return DateTime.tryParse(rawDate)?.toUtc();
    return null;
  }

  @override
  void onClose() {
    _premiumDocSub?.cancel();
    super.onClose();
  }
}
