import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ensures Google Mobile Ads SDK is initialized once before any ad load/show.
class MobileAdsService {
  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    _initialization ??= _initialize();
    return _initialization!;
  }

  static Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: <String>['SIMULATOR'],
        ),
      );
      debugPrint('[ADS] MobileAds SDK initialized.');
    } catch (error) {
      debugPrint('[ADS] MobileAds initialization failed: $error');
      rethrow;
    }
  }
}
