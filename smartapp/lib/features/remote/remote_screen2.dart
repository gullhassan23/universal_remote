import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/controllers/voice_controller.dart';
import 'package:smartapp/utils/constant.dart';
import '../../services/analytics_service.dart';

import '../../controllers/keyboard_controller.dart';
import '../../controllers/remote_controller.dart';
import '../../services/tv_service_interface.dart';
import '../cast/cast_session_banner.dart';
import '../../widgets/top_banner_ad.dart';
import 'keyboard_debug_log_screen.dart';

// ignore: must_be_immutable
class RemoteScreen2 extends GetView<RemoteController> {
  RemoteScreen2({super.key});

  static const Color _fallbackBackgroundColor = Color(0xFF0B1B25);

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

  static const double _wallpaper1DpadSize = 228;

  /// D-pad / 123 mode images ([6.png] / [5.png]) — aligned with Remote-Skin-1.

  void _handleWallpaper1DpadTap(Offset local) {
    const size = Size(_wallpaper1DpadSize, _wallpaper1DpadSize);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dx = local.dx - cx;
    final dy = local.dy - cy;
    final r2 = dx * dx + dy * dy;
    const okRadius = 44.0;
    if (r2 <= okRadius * okRadius) {
      _sendKeyTap('KEY_ENTER')();
      return;
    }
    if (dx.abs() >= dy.abs()) {
      if (dx > 0) {
        _sendKeyTap('KEY_RIGHT')();
      } else {
        _sendKeyTap('KEY_LEFT')();
      }
    } else {
      if (dy > 0) {
        _sendKeyTap('KEY_DOWN')();
      } else {
        _sendKeyTap('KEY_UP')();
      }
    }
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

  VoidCallback _sendSearchTap() {
    return _loggedTap(
      'KEY_SEARCH',
      () async {
        if (Get.isRegistered<KeyboardController>()) {
          final kbController = Get.find<KeyboardController>();
          final hasBufferedText = kbController.buffer.value.trim().isNotEmpty;
          if (hasBufferedText) {
            final submitted = await kbController.enter();
            if (submitted) {
              return;
            }
          }
        }
        await controller.send('KEY_SEARCH');
        await Future<void>.delayed(const Duration(milliseconds: 140));
        await controller.send('KEY_IME_ENTER');
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await controller.send('KEY_ENTER');
      },
      action: 'search_or_submit',
    );
  }

  @override
  Widget build(BuildContext context) {
    const RemoteWallpaperButtonAssets activeButtonAssets =
        RemoteWallpaper2ButtonAssets.set;
    return Scaffold(
      backgroundColor: _fallbackBackgroundColor,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          color: _fallbackBackgroundColor,
          image: DecorationImage(
            image: AssetImage(RemoteWallpaperAssets.wallpaper2),
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
                final mainToToggleGap = isCompactHeight ? 2.0 : 5.0;
                final toggleToPadGap = isCompactHeight ? 10.0 : 16.0;
                final bottomGap = isCompactHeight ? 4.0 : 8.0;

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
                    _buildMainButtons(activeButtonAssets, context),
                    SizedBox(height: mainToToggleGap),
                    _buildModeToggle(activeButtonAssets),
                    SizedBox(height: toggleToPadGap),
                    Expanded(
                      child: Obx(
                        () => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: controller.selectedTab.value == 0
                              ? _buildDpad(activeButtonAssets)
                              : _buildNumberTab(),
                        ),
                      ),
                    ),
                    _buildBottomButtons(context, activeButtonAssets),
                    SizedBox(height: bottomGap),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundedActionButton({
    IconData? icon,
    String? imageAsset,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    double width = 199,
    double height = 180,
    bool showPremiumBadge = false,
  }) {
    assert(icon != null || imageAsset != null);
    final useImage = imageAsset != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width,
        height: height,
        decoration: useImage
            ? null
            : BoxDecoration(
                color: const Color.fromARGB(33, 11, 27, 37),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 0.3),
              ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: useImage
                  ? Padding(
                      padding: const EdgeInsets.all(2),
                      child: Image.asset(
                        // height: 100,
                        // width: 100,
                        imageAsset,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: min(width, height) * 0.35,
                        ),
                      ),
                    )
                  : Icon(icon!, color: iconColor, size: 30),
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

  /// Light grey vertical rail with three white capsule buttons (+, mute, −).
  Widget _buildVolumeColumn(RemoteWallpaperButtonAssets? buttonAssets) {
    if (buttonAssets == null) {
      return SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _roundedActionButton(
              icon: Icons.volume_up,
              onTap: _sendKeyTap('KEY_VOLUP'),
              width: 82,
              height: 58,
            ),
            const SizedBox(height: 6),
            _roundedActionButton(
              icon: Icons.volume_off,
              onTap: _sendKeyTap('KEY_MUTE'),
              width: 82,
              height: 58,
            ),
            const SizedBox(height: 6),
            _roundedActionButton(
              icon: Icons.volume_down,
              onTap: _sendKeyTap('KEY_VOLDOWN'),
              width: 82,
              height: 58,
            ),
          ],
        ),
      );
    }

    // Keep the rail width tight to avoid extra blank space in the Row.
    const railW = 90.0;
    const railH = 222.0;

    return SizedBox(
      width: railW,
      height: railH,
      child: Stack(
        children: [
          // Volume Up (Top Center)
          Positioned(
            top: 2.8,
            left: 6,
            child: Container(
              // decoration:
              //     BoxDecoration(border: Border.all(color: Colors.white)),
              child: GestureDetector(
                onTap: _sendKeyTap('KEY_VOLUP'),
                child: SizedBox(
                  // height: 81.5,
                  // width: 70,
                  child: Image.asset(
                    width: 72,
                    buttonAssets.volUp,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 77,
            left: 6,
            child: Container(
              // decoration: BoxDecoration(border: Border.all(color: Colors.blue)),
              child: GestureDetector(
                onTap: _sendKeyTap('KEY_MUTE'),
                child: SizedBox(
                  // width: 75,
                  // height: 63.9,
                  child: Image.asset(
                    width: 72,
                    buttonAssets.mute,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          // Volume Down (Bottom Center)
          Positioned(
            top: 147.8,
            bottom: 0,
            right: 7,
            child: Container(
              child: GestureDetector(
                onTap: _sendKeyTap('KEY_VOLDOWN'),
                child: SizedBox(
                  child: Image.asset(
                    width: 83,
                    buttonAssets.volDown,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _micButtton(
    RemoteWallpaperButtonAssets? buttonAssets,
    BuildContext context,
  ) {
    final voiceController = Get.find<VoiceController>();
    return Obx(() {
      final isListening = voiceController.isListening.value;

      return _roundedActionButton(
        icon: buttonAssets != null ? null : Icons.power_settings_new,
        imageAsset: buttonAssets?.mic,
        iconColor: const Color(0xFFFF3D3D),
        onTap: () {
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
        width: MediaQuery.of(context).size.width * 0.18,
        height: MediaQuery.of(context).size.width * 0.18,
      );
    });
  }

  Widget _buildMainButtons(
    RemoteWallpaperButtonAssets? buttonAssets,
    BuildContext context,
  ) {
    final Widget volumeColumn = _buildVolumeColumn(buttonAssets);

    final Widget utilityStack = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _roundedActionButton(
          icon: buttonAssets != null ? null : Icons.power_settings_new,
          imageAsset: buttonAssets?.power,
          iconColor: const Color(0xFFFF3D3D),
          onTap: _sendPowerTap(),
          width: MediaQuery.of(context).size.width * 0.18,
          height: MediaQuery.of(context).size.width * 0.18,
        ),
        const SizedBox(height: 5),
        _roundedActionButton(
          icon: buttonAssets != null ? null : Icons.search,
          imageAsset: buttonAssets?.search,
          onTap: _sendSearchTap(),
          width: MediaQuery.of(context).size.width * 0.18,
          height: MediaQuery.of(context).size.width * 0.18,
        ),
        const SizedBox(height: 5),
        _keyboardActionButton(buttonAssets, context),
        const SizedBox(height: 5),
        // _roundedActionButton(
        //   icon: useWallpaper1Assets ? null : Icons.settings_input_component,fz
        //   imageAsset: useWallpaper1Assets
        //       ? RemoteWallpaper1ButtonAssets.keyboard
        //       : null,
        //   onTap: _sendKeyTap('KEY_TV_INPUT'),
        //   width: 88,
        //   height: 50,
        // ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Center(child: volumeColumn),
        Center(child: _micButtton(buttonAssets, context)),
        utilityStack,
      ],
    );
  }

  Widget _buildModeToggle(RemoteWallpaperButtonAssets? buttonAssets) {
    if (buttonAssets != null) {
      // Wallpaper-2 uses a single togglebar background image.
      // We overlay the 2 tap targets (gamepad + "123") on top of it.
      return SizedBox(
        height: 62,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/remote_wallpapers/wallpaper2/togglebar.png',
                fit: BoxFit.contain,
              ),
            ),
            Positioned.fill(
              child: Obx(
                () => Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
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
                        child: Center(
                          child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 140),
                              opacity: controller.selectedTab.value == 0
                                  ? 1.0
                                  : 0.65,
                              child: Image.asset(
                                  height: 30, width: 30, buttonAssets.gamepad)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
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
                        child: Center(
                          child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 140),
                              opacity: controller.selectedTab.value == 1
                                  ? 1.0
                                  : 0.65,
                              child: Image.asset(
                                  height: 30, width: 60, buttonAssets.number)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final BoxDecoration decoration = BoxDecoration(
      color: const Color.fromARGB(33, 32, 52, 66),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white, width: 0.3),
    );

    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: [
        Container(
          decoration: decoration,
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
        ),
      ],
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

  Widget _buildDpad(RemoteWallpaperButtonAssets? buttonAssets) {
    if (buttonAssets != null) {
      return Center(
        key: const ValueKey('dpad_wp1'),
        child: SizedBox(
          width: _wallpaper1DpadSize,
          height: _wallpaper1DpadSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) =>
                _handleWallpaper1DpadTap(details.localPosition),
            child: ClipOval(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    buttonAssets.dpadcircle,
                    width: _wallpaper1DpadSize,
                    height: _wallpaper1DpadSize,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 14,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _sendKeyTap('KEY_UP'),
                      child: Image.asset(
                        buttonAssets.dpadUp,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _sendKeyTap('KEY_DOWN'),
                      child: Image.asset(
                        buttonAssets.dpadDown,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _sendKeyTap('KEY_LEFT'),
                      child: Image.asset(
                        buttonAssets.dpadLeft,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _sendKeyTap('KEY_RIGHT'),
                      child: Image.asset(
                        buttonAssets.dpadRight,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _sendKeyTap('KEY_ENTER'),
                      child: Image.asset(
                        buttonAssets.dpadOk,
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
          // TOP
          Positioned(
            top: 6, // pehle 14 tha → ab outer ring pe
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_up,
                  color: Colors.white, size: 42),
              onPressed: _sendKeyTap('KEY_UP'),
            ),
          ),

// LEFT
          Positioned(
            left: 6, // 👈 IMPORTANT (14 → 6)
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_left,
                  color: Colors.white, size: 42),
              onPressed: _sendKeyTap('KEY_LEFT'),
            ),
          ),

// RIGHT
          Positioned(
            right: 6, // 👈 IMPORTANT (14 → 6)
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_right,
                  color: Colors.white, size: 42),
              onPressed: _sendKeyTap('KEY_RIGHT'),
            ),
          ),

          _buildArrow(Icons.keyboard_arrow_up, -pi / 2, _sendKeyTap('KEY_UP')),
          _buildArrow(
              Icons.keyboard_arrow_down, pi / 2, _sendKeyTap('KEY_DOWN')),
          _buildArrow(Icons.keyboard_arrow_left, pi, _sendKeyTap('KEY_LEFT')),
          _buildArrow(Icons.keyboard_arrow_right, 0, _sendKeyTap('KEY_RIGHT')),
          // Container(
          //   width: 92,
          //   height: 92,
          //   decoration: BoxDecoration(
          //     shape: BoxShape.circle,
          //     color: const Color(0xFF3777B7),
          //     border: Border.all(color: const Color(0x8A1A2E4A), width: 0.3),
          //   ),
          //   child: TextButton(
          //     onPressed: _sendKeyTap('KEY_ENTER'),
          //     child: const Text(
          //       'OK',
          //       style: TextStyle(
          //         fontSize: 20,
          //         color: Colors.white,
          //         fontWeight: FontWeight.w500,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  double radius = 90; // circle ke andar arrows ka distance

  Widget _buildArrow(IconData icon, double angle, VoidCallback onTap) {
    return Transform.rotate(
      angle: 0,
      child: Transform.translate(
        offset: Offset(
          radius * cos(angle),
          radius * sin(angle),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(icon, color: Colors.white, size: 36),
          onPressed: onTap,
        ),
      ),
    );
  }

  Widget _buildBottomButtons(
    BuildContext context,
    RemoteWallpaperButtonAssets? buttonAssets,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _roundedActionButton(
          icon: buttonAssets != null ? null : Icons.arrow_back,
          imageAsset: buttonAssets?.back,
          onTap: _sendKeyTap('KEY_RETURN'),
          width: MediaQuery.of(context).size.width * 0.20,
          height: MediaQuery.of(context).size.width * 0.20,
        ),
        _roundedActionButton(
          icon: buttonAssets != null ? null : Icons.home,
          imageAsset: buttonAssets?.home,
          onTap: _sendKeyTap('KEY_HOME'),
          width: MediaQuery.of(context).size.width * 0.20,
          height: MediaQuery.of(context).size.width * 0.20,
        ),
        // _roundedActionButton(
        //   icon: Icons.menu,
        //   onTap: _sendKeyTap('KEY_MENU'),
        //   width: 78,
        //   height: 50,
        // ),
      ],
    );
  }

  Widget _keyboardActionButton(
    RemoteWallpaperButtonAssets? buttonAssets,
    BuildContext context,
  ) {
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
        icon: buttonAssets != null ? null : Icons.keyboard_alt_outlined,
        imageAsset: buttonAssets?.keyboard,
        onTap: onTap,
        width: MediaQuery.of(context).size.width * 0.18,
        height: MediaQuery.of(context).size.width * 0.18,
      ),
    );
  }
}
