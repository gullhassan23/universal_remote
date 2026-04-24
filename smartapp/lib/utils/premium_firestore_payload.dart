import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic> buildPremiumFirestorePayload({
  required String userId,
  required bool isPremium,
  required String source,
  String? productId,
  bool? autoRenew,
  DateTime? purchaseDate,
  DateTime? expiryDate,
  String? platform,
  String? state,
  String? transactionId,
  String? orderId,
  bool? isRestore,
  String? fcmToken,
  bool includeIapMetadata = false,
}) {
  final Map<String, dynamic> payload = <String, dynamic>{
    'deviceId': userId,
    'isPremium': isPremium,
    'mode': isPremium ? 'premium' : 'free',
    'updatedAt': FieldValue.serverTimestamp(),
    'premiumSource': source,
    'premiumVerifiedAt': FieldValue.serverTimestamp(),
    'premiumProductId': isPremium ? productId : null,
    'autoRenew': isPremium ? (autoRenew ?? false) : false,
  };

  if (isPremium) {
    payload['purchaseDate'] = purchaseDate == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(purchaseDate.toUtc());
    payload['expiryDate'] =
        expiryDate == null ? null : Timestamp.fromDate(expiryDate.toUtc());
    payload['lastSubscribeDate'] = FieldValue.serverTimestamp();
  } else {
    payload['purchaseDate'] = FieldValue.delete();
    payload['expiryDate'] = FieldValue.delete();
    payload['lastSubscribeDate'] = FieldValue.delete();
  }

  if (fcmToken != null && fcmToken.isNotEmpty) {
    payload['fcmToken'] = fcmToken;
  }

  if (includeIapMetadata) {
    payload['iap'] = <String, dynamic>{
      'platform': platform,
      'productId': productId,
      'state': state,
      'expiryTime': expiryDate?.toUtc().toIso8601String(),
      'transactionId': transactionId,
      'orderId': orderId,
      'isRestore': isRestore ?? false,
      'verifiedAt': FieldValue.serverTimestamp(),
    };
  }

  return payload;
}
