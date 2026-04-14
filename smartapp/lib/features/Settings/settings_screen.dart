import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/features/onboarding/onboarding_screen.dart';
import 'package:smartapp/utils/constant.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kGradientTop,
              kGradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Colors.white.withValues(alpha: 0.12),
                  leading: const Icon(Icons.menu_book, color: Colors.white),
                  title: const Text(
                    'How to use app',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Open setup instructions',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white),
                  onTap: () {
                    Get.to(() => const InstructionOnboardingScreen());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
