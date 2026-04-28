class SubscriptionVerificationPayload {
  SubscriptionVerificationPayload({
    required this.receiptData,
    required this.localReceiptData,
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
  final String? localReceiptData;
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
      'localReceiptData': localReceiptData,
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
    this.state,
    this.expiryTime,
    this.purchaseDate,
    this.isExpired = false,
    this.raw,
  });

  final bool isValid;
  final String? message;
  final String? state;
  final String? expiryTime;
  final String? purchaseDate;
  final bool isExpired;
  final Map<String, dynamic>? raw;

  factory SubscriptionVerificationResult.fromJson(Map<String, dynamic> json) {
    final dynamic validity = json['isValid'];
    return SubscriptionVerificationResult(
      isValid: validity == true,
      message: json['message']?.toString(),
      state: json['state']?.toString(),
      expiryTime: json['expiryTime']?.toString(),
      purchaseDate: json['purchaseDate']?.toString(),
      isExpired: json['isExpired'] == true,
      raw: json,
    );
  }
}
