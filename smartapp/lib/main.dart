import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/controllers/rewarded_wallpaper_controller.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';
import 'package:smartapp/controllers/temporary_wallpaper_timer_controller.dart';
import 'package:smartapp/firebase_options.dart';
import 'package:smartapp/services/adapty_service.dart';
import 'package:smartapp/services/fcm_token_service.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/local_storage_service.dart';
import 'package:smartapp/services/rewarded_ad_service.dart';
import 'package:smartapp/services/subscription_iap_service.dart';

import 'app.dart';
import 'services/android_tv/android_tv_remote_platform.dart';
import 'services/network_context_service.dart';
import 'features/device_discovery/device_discovery_controller.dart';
import 'services/tv_service_interface.dart';
import 'services/unified_tv_service.dart';
import 'controllers/tv_connection_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnvironment();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb && Platform.isAndroid) {
    AndroidTvRemotePlatform.instance.ensureInitialized();
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  _registerCoreDependencies();

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeDeferredStartupServices();
  });
}

/// Global services + TV session layer (connection, discovery). Shell UI controllers are in
/// [HomeBinding] on the `/home` route.
void _registerCoreDependencies() {
  Get.put(AnalyticsService(), permanent: true);
  final tvService = UnifiedTvService();
  Get.put(NetworkContextService(), permanent: true);
  Get.put<ITvService>(tvService, permanent: true);

  Get.put(PremiumController(), permanent: true);
  // Keep remote style state accessible during paywall -> activation flow.
  Get.put(RemoteStyleController(), permanent: true);
  Get.put(LocalStorageService(), permanent: true);
  Get.put(RewardedAdService(), permanent: true);
  Get.put(TemporaryWallpaperTimerController(), permanent: true);
  Get.put(RewardedWallpaperController(), permanent: true);
  Get.put(AdaptyService(), permanent: true);
  Get.put(SubscriptionIAPService(), permanent: true);

  Get.lazyPut<TvConnectionController>(
    () => TvConnectionController(
      tvService: tvService,
      networkContextService: Get.find<NetworkContextService>(),
    ),
    fenix: false,
  );
  Get.lazyPut<DeviceDiscoveryController>(
    () => DeviceDiscoveryController(
      tvService: tvService,
      connectionController: Get.find<TvConnectionController>(),
    ),
    fenix: false,
  );
}

Future<void> _loadEnvironment() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('[ENV] Failed to load .env: $error');
  }
}

void _initializeDeferredStartupServices() {
  unawaited(_initializeMobileAds());
  unawaited(_initializeAnalytics());
  unawaited(_initializePremiumState());
  unawaited(_initializeFcm());
  unawaited(_initializeCommerceServices());
}

Future<void> _initializeMobileAds() async {
  try {
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        // iOS Simulator test device id (Google Mobile Ads docs).
        testDeviceIds: <String>['SIMULATOR'],
      ),
    );
  } catch (error) {
    debugPrint('[ADS] Deferred MobileAds initialization failed: $error');
  }
}

Future<void> _initializeAnalytics() async {
  try {
    await Get.find<AnalyticsService>().initialize();
  } catch (error) {
    debugPrint('[ANALYTICS] Deferred initialization failed: $error');
  }
}

Future<void> _initializePremiumState() async {
  try {
    await Get.find<PremiumController>().startPremiumBootstrap();
  } catch (error) {
    debugPrint('[PREMIUM] Deferred bootstrap failed: $error');
  }
}

Future<void> _initializeFcm() async {
  try {
    await initializeFcmAndUploadToken();
  } catch (error) {
    debugPrint('[FCM] Deferred initialization failed: $error');
  }
}

Future<void> _initializeCommerceServices() async {
  try {
    final adaptyService = Get.find<AdaptyService>();
    final iapService = Get.find<SubscriptionIAPService>();

    await adaptyService.initialize();
    await iapService.initialize(
      premiumActivationHook: (String productId) async {
        debugPrint('[IAP] Premium activated for product=$productId');
        await adaptyService.syncProfileToPremiumState(
          source: 'iap_activation_hook',
        );
        if (Get.isRegistered<RemoteStyleController>()) {
          await Get.find<RemoteStyleController>()
              .applyPendingPremiumWallpaperIfAny();
        }
      },
    );
  } catch (error) {
    debugPrint('[IAP] Deferred commerce initialization failed: $error');
  }
}
