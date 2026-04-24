import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/controllers/tv_connection_controller.dart';
import 'package:smartapp/controllers/vibratiion_controller.dart';
import 'package:smartapp/features/device_discovery/device_discovery_controller.dart';
import 'package:smartapp/features/premium/premium_screen.dart';
import 'package:smartapp/features/Settings/faq_screen.dart';
import 'package:smartapp/features/Settings/sleeptimer.dart';
import 'package:smartapp/features/onboarding/onboarding_screen.dart';
import 'package:smartapp/models/tv_device.dart';
import 'package:smartapp/services/subscription_iap_service.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/haptic_action.dart';
import 'package:smartapp/utils/premium_navigation.dart';
import 'package:smartapp/services/tv_service_interface.dart';
import 'package:smartapp/widgets/top_banner_ad.dart';
import 'package:smartapp/widgets/premium_status_banner.dart';
import 'package:smartapp/widgets/remote_device_picker_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  static const String _supportEmail = 'admin@maxgamesproduction.com';
  static const String _defaultTermsConditionsUrl =
      'https://docs.google.com/document/d/12WTnUBG0hlYkg5fRPIwxP4VnNkUhv_gnC19ulCfgHic/edit?tab=t.0';

  // bool _isHapticEnabled = true;
  PremiumController get premiumController => Get.find<PremiumController>();
  VibrationController get vibrationController =>
      Get.find<VibrationController>();
  TvConnectionController get _tvConnectionController =>
      Get.find<TvConnectionController>();
  DeviceDiscoveryController get _discoveryController =>
      Get.find<DeviceDiscoveryController>();
  SubscriptionIAPService get _iapService => Get.find<SubscriptionIAPService>();

  Future<void> _openPrivacyPolicy() async {
    final String privacyUrl = dotenv.env['PRIVACY_POLICY_URL']!.trim();

    final uri = Uri.tryParse(privacyUrl);
    if (uri == null) {
      Get.snackbar('Error', 'Privacy policy URL is invalid.');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      Get.snackbar('Error', 'Unable to open privacy policy.');
    }
  }

  Future<void> _openTermsAndConditions() async {
    final String termsUrl = (dotenv.env['TERMS_CONDITIONS_URL'] ??
            dotenv.env['TERMS_AND_CONDITIONS_URL'] ??
            _defaultTermsConditionsUrl)
        .trim();

    final uri = Uri.tryParse(termsUrl);
    if (uri == null) {
      Get.snackbar('Error', 'Terms & Conditions URL is invalid.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      Get.snackbar('Error', 'Unable to open Terms & Conditions.');
    }
  }

  Future<void> _openFeedbackEmail(BuildContext context) async {
    final Uri gmailUri = Uri(
      scheme: 'googlegmail',
      host: 'co',
      queryParameters: {
        'to': _supportEmail,
        'subject': 'Feedback & Troubleshooting',
      },
    );

    final Uri mailtoUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Feedback & Troubleshooting',
      },
    );

    Future<bool> _safeLaunch(Uri uri, LaunchMode mode) async {
      try {
        return await launchUrl(uri, mode: mode);
      } catch (_) {
        return false;
      }
    }

    final launchedGmailApp = await _safeLaunch(
      gmailUri,
      LaunchMode.externalNonBrowserApplication,
    );
    if (launchedGmailApp) {
      return;
    }

    final launchedMailto = await _safeLaunch(
      mailtoUri,
      LaunchMode.externalNonBrowserApplication,
    );
    if (launchedMailto) {
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Gmail or any mail app on this device.'),
        ),
      );
    }
  }

  Future<bool> _openDeviceDiscoverySheet() async {
    final result = Completer<bool>();
    await Get.bottomSheet<void>(
      RemoteDevicePickerSheet(
        discoveryController: _discoveryController,
        onDeviceSelected: (TvDevice device) async {
          final connected = await _onDeviceSelected(device);
          if (!result.isCompleted) {
            result.complete(connected);
          }
          if (connected && (Get.isBottomSheetOpen ?? false)) {
            Get.back<void>();
          }
          return connected;
        },
        onDismiss: () {
          if (!result.isCompleted) {
            result.complete(false);
          }
        },
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
    if (!result.isCompleted) {
      result.complete(false);
    }
    return result.future;
  }

  Future<bool> _onDeviceSelected(TvDevice device) async {
    return _discoveryController.connectTo(
      device,
      navigateToRemote: false,
    );
  }

  Future<void> _openSleepTimerWithConnectionCheck() async {
    if (!isPremiumUnlocked()) {
      openPremiumPaywall();
      return;
    }
    if (_tvConnectionController.connectionState.value ==
        TvConnectionState.connected) {
      await Get.to(() => const SleepTimerUI());
      return;
    }

    final connected = await _openDeviceDiscoverySheet();
    if (connected) {
      await Get.to(() => const SleepTimerUI());
    }
  }

  Future<void> _restorePurchases() async {
    await _iapService.restorePurchases();
    if (_iapService.lastError.value != null) {
      Get.snackbar('Restore purchases', _iapService.lastError.value!);
      return;
    }
    Get.snackbar(
      'Restore purchases',
      'Restore started. We will unlock premium after verification.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              ImageRes.kGetStartedBackgroundAsset2,
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Center(
                child: TopBannerAd(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionTitle(title: 'REMOTE'),
                            GestureDetector(
                                onTap: () =>
                                    Get.to(() => const PremiumScreen()),
                                child: const PremiumStatusBanner()),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: SettingsIcon.switchdevice,
                          title: 'Switch device',
                          onTap: () {
                            _openDeviceDiscoverySheet();
                          },
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.remotestyle,
                          title: 'Remote style',
                          onTap: openRemoteStyleOrPaywall,
                          isPremiumFeature: true,
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
                          onTap: _openSleepTimerWithConnectionCheck,
                          isPremiumFeature: true,
                        ),
                        const SizedBox(height: 20),
                        const _SectionTitle(title: 'GENERAL'),
                        const SizedBox(height: 12),
                        _SettingsTile(
                          icon: SettingsIcon.faq,
                          title: 'FAQ',
                          onTap: () {
                            Get.to(() => const FaqScreen());
                          },
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.restore,
                          title: 'Restore purchases',
                          onTap: _restorePurchases,
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.privacy,
                          title: 'Privacy policy',
                          onTap: _openPrivacyPolicy,
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.howtouse,
                          title: 'How to use app',
                          onTap: () {
                            Get.to(() => const InstructionOnboardingScreen());
                          },
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.term,
                          title: 'Term & Conditions',
                          onTap: _openTermsAndConditions,
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.notebook,
                          title: 'Send us a note',
                          onTap: () {
                            _openFeedbackEmail(context);
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
        fontSize: 18,
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
    this.isPremiumFeature = false,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isPremiumFeature;

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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPremiumFeature) ...[
                        const SizedBox(width: 8),
                        Obx(
                          () => Get.find<PremiumController>().isPremium.value
                              ? const SizedBox.shrink()
                              : const Icon(
                                  Icons.diamond_outlined,
                                  size: 15,
                                  color: Color(0xFFFFD27A),
                                ),
                        ),
                      ],
                    ],
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
              size: 25,
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
                    fontSize: 18,
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
