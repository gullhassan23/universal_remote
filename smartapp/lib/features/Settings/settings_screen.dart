import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/vibratiion_controller.dart';
import 'package:smartapp/features/device_discovery/device_discovery_controller.dart';
import 'package:smartapp/features/premium/premium_screen.dart';
import 'package:smartapp/features/Settings/sleeptimer.dart';
import 'package:smartapp/features/onboarding/onboarding_screen.dart';
import 'package:smartapp/models/tv_device.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/haptic_action.dart';
import 'package:smartapp/widgets/top_banner_ad.dart';
import 'package:smartapp/widgets/premium_status_banner.dart';
import 'package:smartapp/widgets/remote_device_picker_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // bool _isHapticEnabled = true;
  final vibrationController = Get.find<VibrationController>();
  final _discoveryController = Get.find<DeviceDiscoveryController>();

  Future<void> _openDeviceDiscoverySheet() async {
    await Get.bottomSheet<void>(
      RemoteDevicePickerSheet(
        discoveryController: _discoveryController,
        onDeviceSelected: _onDeviceSelected,
        onDismiss: () {},
        onHandleTap: ({
          required String buttonKey,
          required FutureOr<void> Function() onTap,
          String action = 'tap',
        }) async {
          await onTap();
        },
      ),
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  Future<void> _onDeviceSelected(TvDevice device) async {
    await _discoveryController.connectTo(
      device,
      navigateToRemote: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00B0B6), Color(0xFF005AFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  ImageRes.kGetStartedBackgroundAsset2,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Center(
                    child: TopBannerAd(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PremiumStatusBanner(),
                            const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => Get.to(() => const PremiumScreen()),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Manage Premium',
                            style: TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const _SectionTitle(title: 'REMOTE'),
                      const SizedBox(height: 10),
                      _SettingsTile(
                        icon: SettingsIcon.switchdevice,
                        title: 'Switch device',
                        onTap: _openDeviceDiscoverySheet,
                      ),
                      _SettingsTile(
                        icon: SettingsIcon.remotestyle,
                        title: 'Remote style',
                        onTap: () {},
                      ),
                      Obx(
                        () => _SwitchSettingsTile(
                          icon: SettingsIcon.haptic,
                          title: 'Haptic feedback',
                          subtitle: 'Enables haptics on remote',
                          value: vibrationController.isHapticEnabled.value,
                          onChanged: (value) {
                            vibrationController.toggleHaptic(value);
                          },
                        ),
                      ),
                      _SettingsTile(
                        icon: SettingsIcon.sleep,
                        title: 'Sleep timer',
                        subtitle: 'Turns off your TV automatically',
                        onTap: () => Get.to(() => const SleepTimerUI()),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(title: 'GENERAL'),
                      const SizedBox(height: 12),
                      _SettingsTile(
                        icon: SettingsIcon.faq,
                        title: 'FAQ',
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: SettingsIcon.restore,
                        title: 'Restore purchases',
                        onTap: () => Get.to(() => const PremiumScreen()),
                      ),
                      _SettingsTile(
                        icon: SettingsIcon.privacy,
                        title: 'Privacy policy',
                        onTap: () {},
                      ),
                            _SettingsTile(
                              icon: SettingsIcon.term,
                              title: 'How to use app',
                              onTap: () {
                                Get.to(() => const InstructionOnboardingScreen());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.64),
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: HapticAction.wrap(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            Image.asset(icon, width: 25, height: 25),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 30,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchSettingsTile extends StatelessWidget {
  const _SwitchSettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Image.asset(icon, width: 27, height: 27),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (next) {
              HapticAction.vibrate();
              onChanged(next);
            },
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF2FCC6A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}
