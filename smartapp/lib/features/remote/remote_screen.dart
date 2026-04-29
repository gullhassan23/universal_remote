import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/utils/premium_navigation.dart';

import '../../services/analytics_service.dart';

import '../../controllers/keyboard_controller.dart';
import '../../controllers/remote_controller.dart';
import '../../controllers/remote_style_controller.dart';
import '../../controllers/voice_controller.dart';
import '../../services/tv_service_interface.dart';
import '../cast/cast_session_banner.dart';
import '../../widgets/top_banner_ad.dart';
import 'keyboard_debug_log_screen.dart';

class RemoteScreen extends GetView<RemoteController> {
  const RemoteScreen({super.key});

  static const Color _fallbackBackgroundColor = Color(0xFF0B1B25);

  RemoteStyleController get _remoteStyleController =>
      Get.find<RemoteStyleController>();
  AnalyticsService get _analyticsService => Get.find<AnalyticsService>();

  VoidCallback _loggedTap(
    String buttonKey,
    VoidCallback onTap, {
    String action = 'tap',
  }) {
    return () {
      unawaited(
        controller.handleButtonTap(
          buttonKey: buttonKey,
          onTap: onTap,
          action: action,
        ),
      );
    };
  }

  VoidCallback _sendKeyTap(String keyCode) {
    return _loggedTap(
      keyCode,
      () async {
        await controller.send(keyCode);
      },
      action: 'send_key',
    );
  }

  VoidCallback _sendPowerTap() {
    return _loggedTap(
      'KEY_POWER',
      () async {
        await controller.sendPowerReliably(openPickerOnFailure: true);
      },
      action: 'send_power_key',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fallbackBackgroundColor,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      body: Obx(
        () => Container(
          decoration: BoxDecoration(
            color: _fallbackBackgroundColor,
            image: DecorationImage(
              image: AssetImage(_remoteStyleController.appliedWallpaper.value),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompactHeight = constraints.maxHeight < 520;
                  final topGap = isCompactHeight ? 4.0 : 8.0;
                  final bannerToMainGap = isCompactHeight ? 18.0 : 26.0;
                  final mainToToggleGap = isCompactHeight ? 12.0 : 20.0;
                  final toggleToPadGap = isCompactHeight ? 10.0 : 16.0;
                  final bottomGap = isCompactHeight ? 4.0 : 10.0;

                  return Column(
                    children: [
                      SizedBox(height: topGap),
                      const Center(
                        child: TopBannerAd(),
                      ),
                      Obx(() {
                        final isConnected = controller
                                .connectionController.connectionState.value ==
                            TvConnectionState.connected;
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                isConnected
                                    ? 'Connected Device'
                                    : 'Connect a device',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // if (!isPremium)
                            //   IconButton(
                            //     onPressed: openRemoteStyleOrPaywall,
                            //     tooltip: 'Premium remote styles',
                            //     icon: const Icon(
                            //       Icons.diamond_outlined,
                            //       color: Color(0xFFFFD27A),
                            //     ),
                            //   ),
                            if (isConnected) const SizedBox(width: 10),
                            if (isConnected)
                              TextButton.icon(
                                onPressed: _loggedTap(
                                  'DISCONNECT_TV',
                                  () {
                                    unawaited(
                                      controller.connectionController
                                          .disconnect(),
                                    );
                                  },
                                  action: 'disconnect_tv',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                      Colors.red.withValues(alpha: 0.28),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.link_off, size: 16),
                                label: const Text('Disconnect'),
                              ),
                          ],
                        );
                      }),
                      Obx(() {
                        final label = controller
                            .connectionController.castConnectionLabel.value;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: CastSessionBanner(label: label),
                        );
                      }),
                      SizedBox(height: bannerToMainGap),
                      _buildMainButtons(),
                      SizedBox(height: mainToToggleGap),
                      _buildModeToggle(),
                      SizedBox(height: toggleToPadGap),
                      Expanded(
                        child: Obx(
                          () => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: controller.selectedTab.value == 0
                                ? _buildDpad()
                                : _buildNumberTab(),
                          ),
                        ),
                      ),
                      _buildBottomButtons(context),
                      SizedBox(height: bottomGap),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundedActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    double width = 89,
    double height = 50,
    bool showPremiumBadge = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color.fromARGB(33, 11, 27, 37),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 0.3),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(icon, color: iconColor, size: 30),
            ),
            if (showPremiumBadge)
              const Positioned(
                top: 6,
                right: 8,
                child: Icon(
                  Icons.diamond_outlined,
                  size: 14,
                  color: Color(0xFFFFD27A),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButtons() {
    final voiceController = Get.find<VoiceController>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 66,
          height: 194,
          decoration: BoxDecoration(
            color: const Color.fromARGB(33, 11, 27, 37),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 0.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 40),
                onPressed: _sendKeyTap('KEY_VOLUP'),
              ),
              IconButton(
                icon:
                    const Icon(Icons.volume_off, color: Colors.white, size: 30),
                onPressed: _sendKeyTap('KEY_MUTE'),
              ),
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white, size: 40),
                onPressed: _sendKeyTap('KEY_VOLDOWN'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 194,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // _roundedActionButton(
              //   icon: Icons.search,
              //   onTap: openRemoteStyleOrPaywall,
              //   width: 88,
              //   height: 50,
              // ),
              SizedBox(height: 19),
              _roundedActionButton(
                icon: Icons.search,
                onTap: _sendKeyTap('KEY_SEARCH'),
                width: 88,
                height: 50,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 204,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _roundedActionButton(
                icon: Icons.power_settings_new,
                iconColor: const Color(0xFFFF3D3D),
                onTap: _sendPowerTap(),
              ),
              // _roundedActionButton(
              //   icon: Icons.exit_to_app,
              //   onTap: _sendKeyTap('KEY_RETURN'),
              // ),
              _keyboardActionButton(),

              Obx(() {
                final isListening = voiceController.isListening.value;
                final isPremium = isPremiumUnlocked();
                return _roundedActionButton(
                  icon: isListening ? Icons.mic : Icons.mic_none,
                  iconColor:
                      isListening ? const Color(0xFFFFE082) : Colors.white,
                  showPremiumBadge: !isPremium,
                  onTap: () {
                    if (!isPremium) {
                      openPremiumPaywall();
                      return;
                    }
                    unawaited(
                      controller.handleButtonTap(
                        buttonKey: 'KEY_MIC',
                        action: isListening ? 'stop_voice' : 'start_voice',
                        onTap: () async {
                          if (isListening) {
                            await voiceController.stopListening();
                          } else {
                            await voiceController.startListening();
                          }
                        },
                      ),
                    );
                  },
                  width: 88,
                  height: 48,
                );
              }),
              // const SizedBox(height: 1),
              // Obx(() {
              //   final state = voiceController.sessionState.value;
              //   final status = voiceController.statusText.value;
              //   if (state == VoiceSessionState.idle || status.isEmpty) {
              //     return const SizedBox.shrink();
              //   }
              //   final color = switch (state) {
              //     VoiceSessionState.error => const Color(0xFFFFAB91),
              //     VoiceSessionState.sent => const Color(0xFFA5D6A7),
              //     _ => const Color(0xFFE3F2FD),
              //   };
              //   return SizedBox(
              //     width: 140,
              //     child: Text(
              //       status,
              //       textAlign: TextAlign.center,
              //       style: TextStyle(
              //         color: color,
              //         fontSize: 11,
              //         fontWeight: FontWeight.w500,
              //       ),
              //     ),
              //   );
              // }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(33, 32, 52, 66),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 0.3),
      ),
      child: Obx(
        () => Row(
          children: [
            Expanded(
              child: _buildModeSegment(
                isActive: controller.selectedTab.value == 0,
                icon: Icons.gamepad,
                onTap: () {
                  if (controller.selectedTab.value == 0) return;
                  controller.selectedTab.value = 0;
                  unawaited(
                    _analyticsService.trackTab(
                      'Dpad',
                      screenName: 'Remote_Screen',
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _buildModeSegment(
                isActive: controller.selectedTab.value == 1,
                text: '123',
                onTap: () {
                  if (controller.selectedTab.value == 1) return;
                  controller.selectedTab.value = 1;
                  unawaited(
                    _analyticsService.trackTab(
                      'NumberPad',
                      screenName: 'Remote_Screen',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSegment({
    required bool isActive,
    IconData? icon,
    String text = '',
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(4),
        height: 54,
        decoration: BoxDecoration(
          color: isActive ? const Color(0x4FFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 30)
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNumberTab() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [
        '0',
      ],
    ];

    return SingleChildScrollView(
      key: const ValueKey('number_pad'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((label) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _numberPadButton(label),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _numberPadButton(String label) {
    late final String keyCode;
    final bool isUtilityButton = label == 'GUIDE' || label == 'TOOLS';

    if (label == 'GUIDE') {
      keyCode = 'KEY_GUIDE';
    } else if (label == 'TOOLS') {
      keyCode = 'KEY_TOOLS';
    } else {
      keyCode = 'KEY_$label';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _sendKeyTap(keyCode),
      child: Container(
        width: isUtilityButton ? 96 : 78,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x2A5AA9D9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x8A1A2E4A), width: 0.3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isUtilityButton ? 11 : 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDpad() {
    return SizedBox(
      key: const ValueKey('dpad'),
      width: 228,
      height: 228,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 228,
            height: 228,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF59B6FA), Color(0xFF2A90E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 226,
            height: 226,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x8A1A2E4A), width: 0.3),
            ),
          ),
          Positioned(
            top: 14,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_up,
                  color: Colors.white, size: 44),
              onPressed: _sendKeyTap('KEY_UP'),
            ),
          ),
          Positioned(
            bottom: 14,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 44),
              onPressed: _sendKeyTap('KEY_DOWN'),
            ),
          ),
          Positioned(
            left: 14,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_left,
                  color: Colors.white, size: 44),
              onPressed: _sendKeyTap('KEY_LEFT'),
            ),
          ),
          Positioned(
            right: 14,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_right,
                  color: Colors.white, size: 44),
              onPressed: _sendKeyTap('KEY_RIGHT'),
            ),
          ),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3777B7),
              border: Border.all(color: const Color(0x8A1A2E4A), width: 0.3),
            ),
            child: TextButton(
              onPressed: _sendKeyTap('KEY_ENTER'),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _roundedActionButton(
          icon: Icons.arrow_back,
          onTap: _sendKeyTap('KEY_RETURN'),
          width: 78,
          height: 50,
        ),
        _roundedActionButton(
          icon: Icons.home,
          onTap: _sendKeyTap('KEY_HOME'),
          width: 78,
          height: 50,
        ),
      ],
    );
  }

  Widget _keyboardActionButton() {
    final onTap = _loggedTap(
      'KEY_KEYBOARD',
      () async {
        await controller.openKeyboard();
      },
      action: 'open_keyboard',
    );
    return GestureDetector(
      onLongPress: kDebugMode
          ? () {
              KeyboardController kbController;
              if (Get.isRegistered<KeyboardController>()) {
                kbController = Get.find<KeyboardController>();
              } else {
                Get.lazyPut<KeyboardController>(
                  () => KeyboardController(
                    connectionController: controller.connectionController,
                  ),
                  fenix: true,
                );
                kbController = Get.find<KeyboardController>();
              }
              Get.to(
                () => KeyboardDebugLogScreen(
                  keyboardController: kbController,
                ),
              );
            }
          : null,
      child: _roundedActionButton(
        icon: Icons.keyboard_alt_outlined,
        onTap: onTap,
        width: 78,
        height: 50,
      ),
    );
  }
}
