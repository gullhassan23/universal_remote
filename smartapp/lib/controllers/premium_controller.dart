import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartapp/services/fcm_token_service.dart';
import 'package:smartapp/utils/userId.dart';

class PremiumController extends GetxController {
  static const String _kPremiumEnabledKey = 'premium_enabled';
  static const String _kPremiumProductIdKey = 'premium_product_id';
  static const String _kPremiumUpdatedAtKey = 'premium_updated_at_ms';

  final RxBool isPremium = false.obs;
  final RxnString activeProductId = RxnString();

  @override
  void onInit() {
    super.onInit();
    _restoreCache();
  }

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool(_kPremiumEnabledKey) ?? false;
    activeProductId.value = prefs.getString(_kPremiumProductIdKey);
    unawaited(_syncUserProfileToFirestore());
  }

  Future<void> setPremium({
    required bool enabled,
    String? productId,
    bool? autoRenew,
    DateTime? expiryDate,
    String? fcmToken,
  }) async {
    isPremium.value = enabled;
    activeProductId.value = enabled ? productId : null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPremiumEnabledKey, enabled);
    if (enabled && productId != null) {
      await prefs.setString(_kPremiumProductIdKey, productId);
    } else {
      await prefs.remove(_kPremiumProductIdKey);
    }
    await prefs.setInt(
      _kPremiumUpdatedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _syncUserProfileToFirestore(
      autoRenew: autoRenew,
      expiryDate: expiryDate,
      fcmToken: fcmToken,
    );
  }

  Future<void> _syncUserProfileToFirestore({
    bool? autoRenew,
    DateTime? expiryDate,
    String? fcmToken,
  }) async {
    try {
      final String deviceId = await getOrCreateUserId();
      final bool premiumEnabled = isPremium.value;
      final String? resolvedFcmToken = fcmToken ?? await getFcmTokenWithRetry();

      final Map<String, dynamic> payload = <String, dynamic>{
        'deviceId': deviceId,
        'isPremium': premiumEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'mode': premiumEnabled ? 'premium' : 'free',
      };
      if (resolvedFcmToken != null && resolvedFcmToken.isNotEmpty) {
        payload['fcmToken'] = resolvedFcmToken;
      }

      if (premiumEnabled) {
        payload['autoRenew'] = autoRenew ?? false;
        if (expiryDate != null) {
          payload['expiryDate'] = Timestamp.fromDate(expiryDate.toUtc());
        }
      } else {
        payload['autoRenew'] = false;
        payload['expiryDate'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance.collection('Users').doc(deviceId).set(
            payload,
            SetOptions(merge: true),
          );
    } catch (_) {
      // Firestore sync should never break local premium state updates.
    }
  }
}
