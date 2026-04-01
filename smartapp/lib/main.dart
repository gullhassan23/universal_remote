import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/firebase_options.dart';
import 'package:smartapp/services/fcm_token_service.dart';
import 'package:smartapp/services/subscription_iap_service.dart';

import 'app.dart';
import 'services/android_tv/android_tv_remote_platform.dart';
import 'features/home/home_controller.dart';
import 'features/device_discovery/device_discovery_controller.dart';
import 'features/remote/remote_controller.dart';
import 'services/tv_service_interface.dart';
import 'services/unified_tv_service.dart';
import 'controllers/tv_connection_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('[ENV] Failed to load .env: $error');
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeFcmAndUploadToken();
  if (!kIsWeb && Platform.isAndroid) {
    AndroidTvRemotePlatform.instance.ensureInitialized();
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  _registerDependencies();

  runApp(const MyApp());
}

void _registerDependencies() {
  // Services
  final tvService = UnifiedTvService();
  Get.put<ITvService>(tvService, permanent: true);
  Get.put(PremiumController(), permanent: true);
  final iapService = Get.put(SubscriptionIAPService(), permanent: true);

  // Controllers
  final tvConnectionController = Get.put(
    TvConnectionController(tvService: tvService),
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
    HomeController(discoveryController: discoveryController),
    permanent: true,
  );
  Get.put(
    RemoteController(
      connectionController: tvConnectionController,
      discoveryController: discoveryController,
    ),
    permanent: true,
  );

  iapService.initialize(
    premiumActivationHook: (String productId) async {
      debugPrint('[IAP] Premium activated for product=$productId');
      // Adapty sync hook can be plugged in here when Adapty is integrated.
    },
  );
}
