import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';
import 'package:smartapp/features/get_started.dart';
import 'package:smartapp/features/splash/splash_screen.dart';
import 'package:smartapp/widgets/bottom_nav.dart';
import 'package:smartapp/features/onboarding/onboarding_screen.dart';
import 'package:smartapp/services/analytics_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final analyticsService = Get.find<AnalyticsService>();
    return GetMaterialApp(
      title: 'Universal TV Remote',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analyticsService.analytics),
      ],
      routingCallback: analyticsService.trackRouteFromGetX,
      getPages: [
        GetPage(name: '/', page: () => const SplashScreen()),
        GetPage(name: '/get-started', page: () => const GetStarted()),
        GetPage(
          name: '/instructions',
          page: () => const InstructionOnboardingScreen(),
        ),
        GetPage(name: '/home', page: () => const BottomNav()),
      ],
    );
  }
}
