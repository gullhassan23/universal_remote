import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/controllers/tv_connection_controller.dart';
import 'package:smartapp/controllers/vibratiion_controller.dart';
import 'package:smartapp/features/device_discovery/device_discovery_controller.dart';
import 'package:smartapp/features/Settings/faq_screen.dart';
import 'package:smartapp/features/Settings/sleeptimer.dart';

import 'package:smartapp/models/tv_device.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/subscription_iap_service.dart';
import 'package:smartapp/utils/constant.dart';
import 'package:smartapp/utils/haptic_action.dart';
import 'package:smartapp/utils/settings_actions.dart';
import 'package:smartapp/utils/premium_navigation.dart';
import 'package:smartapp/services/tv_service_interface.dart';
import 'package:smartapp/widgets/top_banner_ad.dart';
import 'package:smartapp/widgets/premium_status_banner.dart';
import 'package:smartapp/widgets/remote_device_picker_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  static const String _defaultSupportEmail = 'admin@maxgamesproduction.com';

  // bool _isHapticEnabled = true;
  PremiumController get premiumController => Get.find<PremiumController>();
  VibrationController get vibrationController =>
      Get.find<VibrationController>();
  TvConnectionController get _tvConnectionController =>
      Get.find<TvConnectionController>();
  DeviceDiscoveryController get _discoveryController =>
      Get.find<DeviceDiscoveryController>();
  SubscriptionIAPService get _iapService => Get.find<SubscriptionIAPService>();
  AnalyticsService get _analyticsService => Get.find<AnalyticsService>();
  String get _supportEmail =>
      (dotenv.env['SUPPORT_EMAIL'] ?? _defaultSupportEmail).trim();

  Future<void> _openFeedbackEmail(BuildContext context) async {
    unawaited(
      _analyticsService.trackClick(
        'SendUsANote',
        screenName: 'SettingsScreen',
      ),
    );
    final Uri mailtoUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Feedback & Troubleshooting',
      },
    );

    final List<Uri> gmailUris = <Uri>[
      Uri.parse(
        'googlegmail://co?to=$_supportEmail&subject=Feedback%20%26%20Troubleshooting',
      ),
      Uri.parse(
        'googlegmail:///co?to=$_supportEmail&subject=Feedback%20%26%20Troubleshooting',
      ),
    ];

    Future<bool> _safeLaunch(Uri uri, {LaunchMode mode = LaunchMode.externalApplication}) async {
      try {
        final canLaunch = await canLaunchUrl(uri);
        if (!canLaunch) {
          return false;
        }
        return await launchUrl(uri, mode: mode);
      } catch (_) {
        return false;
      }
    }

    for (final uri in gmailUris) {
      final launchedGmailApp = await _safeLaunch(uri);
      if (launchedGmailApp) {
        return;
      }
    }

    final launchedMailto = await _safeLaunch(
      mailtoUri,
      mode: LaunchMode.platformDefault,
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
    unawaited(
      _analyticsService.trackClick(
        'SwitchDevice',
        screenName: 'SettingsScreen',
      ),
    );
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
    unawaited(
      _analyticsService.trackClick(
        'SleepTimer',
        screenName: 'SettingsScreen',
      ),
    );
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
    await SettingsActions.restorePurchases(
      iapService: _iapService,
      screenName: 'SettingsScreen',
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
                                onTap: () {
                                  unawaited(
                                    _analyticsService.trackClick(
                                      'PremiumStatusBanner',
                                      screenName: 'SettingsScreen',
                                    ),
                                  );
                                  openPremiumStatusScreen();
                                },
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
                          onTap: () {
                            unawaited(
                              _analyticsService.trackClick(
                                'RemoteStyle',
                                screenName: 'SettingsScreen',
                              ),
                            );
                            openRemoteStyleOrPaywall();
                          },
                          isPremiumFeature: true,
                        ),
                        Obx(
                          () => _SwitchSettingsTile(
                            icon: SettingsIcon.haptic,
                            title: 'Haptic feedback',
                            subtitle: 'Enables haptics on remote',
                            value: vibrationController.isHapticEnabled.value,
                            onChanged: (value) {
                              unawaited(
                                _analyticsService.trackClick(
                                  'HapticFeedbackToggle',
                                  screenName: 'SettingsScreen',
                                ),
                              );
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
                            unawaited(
                              _analyticsService.trackClick(
                                'FAQ',
                                screenName: 'SettingsScreen',
                              ),
                            );
                            Get.to(() => const FaqScreen());
                          },
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.restore,
                          title: 'Restore purchases',
                          onTap: _restorePurchases,
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.notebook,
                          title: 'Send us a note',
                          onTap: () {
                            _openFeedbackEmail(context);
                          },
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.term,
                          title: 'Term & Conditions',
                          onTap: () => SettingsActions.openTermsAndConditions(
                            screenName: 'SettingsScreen',
                          ),
                        ),
                        _SettingsTile(
                          icon: SettingsIcon.privacy,
                          title: 'Privacy policy',
                          onTap: () => SettingsActions.openPrivacyPolicy(
                            screenName: 'SettingsScreen',
                          ),
                        ),

                        // _SettingsTile(
                        //   icon: SettingsIcon.howtouse,
                        //   title: 'How to use app',
                        //   onTap: () {
                        //     unawaited(
                        //       _analyticsService.trackClick(
                        //         'HowToUseApp',
                        //         screenName: 'SettingsScreen',
                        //       ),
                        //     );
                        //     Get.to(() => const InstructionOnboardingScreen());
                        //   },
                        // ),
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
            // activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF2FCC6A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}
