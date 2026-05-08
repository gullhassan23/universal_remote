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
  await MobileAds.instance.initialize();
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      // iOS Simulator test device id (Google Mobile Ads docs).
      testDeviceIds: <String>['SIMULATOR'],
    ),
  );
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('[ENV] Failed to load .env: $error');
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb && Platform.isAndroid) {
    AndroidTvRemotePlatform.instance.ensureInitialized();
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await _registerCoreDependencies();
  await initializeFcmAndUploadToken();

  runApp(const MyApp());
}

/// Global services + TV session layer (connection, discovery). Shell UI controllers are in
/// [HomeBinding] on the `/home` route.
Future<void> _registerCoreDependencies() async {
  Get.put(AnalyticsService(), permanent: true);
  await Get.find<AnalyticsService>().initialize();
  final tvService = UnifiedTvService();
  Get.put(NetworkContextService(), permanent: true);
  Get.put<ITvService>(tvService, permanent: true);

  final premiumController = Get.put(PremiumController(), permanent: true);
  // Keep remote style state accessible during paywall -> activation flow.
  Get.put(RemoteStyleController(), permanent: true);
  Get.put(LocalStorageService(), permanent: true);
  Get.put(RewardedAdService(), permanent: true);
  Get.put(TemporaryWallpaperTimerController(), permanent: true);
  Get.put(RewardedWallpaperController(), permanent: true);
  final adaptyService = Get.put(AdaptyService(), permanent: true);
  final iapService = Get.put(SubscriptionIAPService(), permanent: true);

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

  await premiumController.syncPremiumFromFirestore();
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
}
