import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionProduct {
  SubscriptionProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.productDetails,
  });

  final String id;
  final String title;
  final String description;
  final String priceLabel;
  final ProductDetails productDetails;
}
