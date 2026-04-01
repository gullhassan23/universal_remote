class SubscriptionVerificationPayload {
  SubscriptionVerificationPayload({
    required this.receiptData,
    required this.productId,
    required this.userId,
    required this.platform,
    required this.purchaseToken,
    required this.isRestore,
    required this.fcmToken,
    required this.transactionId,
    required this.orderId,
  });

  final String receiptData;
  final String productId;
  final String userId;
  final String platform;
  final String? purchaseToken;
  final bool isRestore;
  final String? fcmToken;
  final String? transactionId;
  final String? orderId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'receiptData': receiptData,
      'productId': productId,
      'userId': userId,
      'platform': platform,
      'purchaseToken': purchaseToken,
      'isRestore': isRestore,
      'fcmToken': fcmToken,
      'transactionId': transactionId,
      'orderId': orderId,
    };
  }
}

class SubscriptionVerificationResult {
  SubscriptionVerificationResult({
    required this.isValid,
    this.message,
    this.raw,
  });

  final bool isValid;
  final String? message;
  final Map<String, dynamic>? raw;

  factory SubscriptionVerificationResult.fromJson(Map<String, dynamic> json) {
    final dynamic validity = json['isValid'];
    return SubscriptionVerificationResult(
      isValid: validity == true,
      message: json['message']?.toString(),
      raw: json,
    );
  }
}
