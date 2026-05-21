import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/services/ad_mediation.dart';

/// Ensures Google Mobile Ads SDK is initialized once before any ad load/show.
class MobileAdsService {
  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    _initialization ??= _initialize();
    return _initialization!;
  }

  static Future<void> _initialize() async {
    try {
      ensureMediationAdaptersLinked();

      final InitializationStatus initializationStatus =
          await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: <String>['SIMULATOR'],
        ),
      );

      initializationStatus.adapterStatuses.forEach((String adapter, AdapterStatus status) {
        debugPrint(
          '[ADS] Mediation adapter $adapter: ${status.description} '
          '(state=${status.state}, latency=${status.latency}ms)',
        );
      });

      debugPrint('[ADS] MobileAds SDK initialized with mediation adapters.');
    } catch (error) {
      debugPrint('[ADS] MobileAds initialization failed: $error');
      rethrow;
    }
  }

  /// Logs which mediation network served an ad (debug builds only).
  static void logMediationAdapter(Ad ad, {required String format}) {
    if (!kDebugMode) return;
    final adapter = ad.responseInfo?.mediationAdapterClassName;
    if (adapter == null || adapter.isEmpty) return;
    debugPrint('[ADS] $format served by mediation adapter: $adapter');
  }
}
