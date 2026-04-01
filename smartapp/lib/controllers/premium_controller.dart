import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }

  Future<void> setPremium({
    required bool enabled,
    String? productId,
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
    await prefs.setInt(_kPremiumUpdatedAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
