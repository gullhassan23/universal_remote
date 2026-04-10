import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/features/get_started.dart';
import 'package:smartapp/features/home/home_screen.dart';
import 'package:smartapp/features/onboarding/onboarding_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Universal TV Remote',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const GetStarted()),
        GetPage(
          name: '/instructions',
          page: () => const InstructionOnboardingScreen(),
        ),
        GetPage(name: '/home', page: () => const HomeScreen()),
      ],
    );
  }
}
