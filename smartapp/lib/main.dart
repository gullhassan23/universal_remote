import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app.dart';
import 'features/home/home_controller.dart';
import 'features/device_discovery/device_discovery_controller.dart';
import 'features/remote/remote_controller.dart';
import 'services/tv_service_interface.dart';
import 'services/unified_tv_service.dart';
import 'controllers/tv_connection_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  _registerDependencies();

  runApp(const MyApp());
}


void _registerDependencies() {
  // Services
  Get.put<ITvService>(UnifiedTvService(), permanent: true);

  // Controllers
  Get.put(TvConnectionController(), permanent: true); // ✅ first

  Get.put(HomeController(), permanent: true);
  Get.put(DeviceDiscoveryController(), permanent: true);
  Get.put(RemoteController(), permanent: true);
}
