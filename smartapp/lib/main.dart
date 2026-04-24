import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/config/admob_config.dart';
import 'package:smartapp/controllers/ad_controller.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';
import 'package:smartapp/controllers/sleep_timer_controller.dart';
import 'package:smartapp/controllers/vibratiion_controller.dart';
import 'package:smartapp/firebase_options.dart';
import 'package:smartapp/services/fcm_token_service.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/subscription_iap_service.dart';

import 'app.dart';
import 'services/android_tv/android_tv_remote_platform.dart';
import 'services/network_context_service.dart';
import 'controllers/streaming_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/media_cast_controller.dart';
import 'controllers/voice_controller.dart';
import 'features/device_discovery/device_discovery_controller.dart';
import 'controllers/remote_controller.dart';
import 'services/tv_service_interface.dart';
import 'services/unified_tv_service.dart';
import 'controllers/tv_connection_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
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
  await _registerDependencies();
  await initializeFcmAndUploadToken();

  runApp(const MyApp());
}

Future<void> _registerDependencies() async {
  // Servicescd 
  Get.put(AnalyticsService(), permanent: true);
  final tvService = UnifiedTvService();
  final networkContextService = Get.put(NetworkContextService(), permanent: true);
  Get.put<ITvService>(tvService, permanent: true);
  final premiumController = Get.put(PremiumController(), permanent: true);
  final iapService = Get.put(SubscriptionIAPService(), permanent: true);
  Get.put(VibrationController(), permanent: true);
  Get.put(RemoteStyleController(), permanent: true);
  // Controllers
  final tvConnectionController = Get.put(
    TvConnectionController(
      tvService: tvService,
      networkContextService: networkContextService,
    ),
    permanent: true,
  ); // ✅ first
  final discoveryController = Get.put(
    DeviceDiscoveryController(
      tvService: tvService,
      connectionController: tvConnectionController,
    ),
    permanent: true,
  );
  Get.put(
    AdController(
      adUnitId: AdMobConfig.bannerAdUnitId,
      interstitialAdUnitId: AdMobConfig.interstitialAdUnitId,
    ),
    permanent: true,
  );

  Get.put(
    HomeController(discoveryController: discoveryController),
    permanent: true,
  );
  Get.put(
    MediaCastController(connectionController: tvConnectionController),
    permanent: true,
  );
  Get.put(
    RemoteController(
      connectionController: tvConnectionController,
      discoveryController: discoveryController,
      mediaCastController: Get.find<MediaCastController>(),
    ),
    permanent: true,
  );
  Get.put(
    VoiceController(connectionController: tvConnectionController),
    permanent: true,
  );
  Get.put(
    StreamingController(connectionController: tvConnectionController),
    permanent: true,
  );
  Get.put(
    SleepTimerController(connectionController: tvConnectionController),
    permanent: true,
  );

  await premiumController.syncPremiumFromFirestore();
  await iapService.initialize(
    premiumActivationHook: (String productId) async {
      debugPrint('[IAP] Premium activated for product=$productId');
      // Adapty sync hook can be plugged in here when Adapty is integrated.
    },
  );
}
