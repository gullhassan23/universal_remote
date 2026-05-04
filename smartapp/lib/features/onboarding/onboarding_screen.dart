import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartapp/features/device_discovery/device_discovery_controller.dart';
import 'package:smartapp/models/tv_brand.dart';
import 'package:smartapp/utils/constant.dart';

const String kInstructionOnboardingCompletedKey =
    'instruction_onboarding_completed';

Future<bool> isInstructionOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kInstructionOnboardingCompletedKey) ?? false;
}

Future<void> markInstructionOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kInstructionOnboardingCompletedKey, true);
}

/// Three-step “Instructions” flow (same Wi‑Fi, discovery, pairing code).
class InstructionOnboardingScreen extends StatefulWidget {
  const InstructionOnboardingScreen({super.key});

  @override
  State<InstructionOnboardingScreen> createState() =>
      _InstructionOnboardingScreenState();
}

class _InstructionOnboardingScreenState
    extends State<InstructionOnboardingScreen> {
  static const int _pageCount = 3;

  final PageController _pageController = PageController();
  final RxInt _pageIndex = 0.obs;
  bool _localNetworkPromptTriggered = false;

  @override
  void dispose() {
    _pageController.dispose();
    _pageIndex.close();
    super.dispose();
  }

  void _syncPageIndex(int index) {
    if (mounted) _pageIndex.value = index;
  }

  Future<void> _triggerLocalNetworkPermissionOnSameNetworkStep() async {
    if (_localNetworkPromptTriggered) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _localNetworkPromptTriggered = true;

    final mdns = MDnsClient();
    try {
      await mdns.start();
      await for (final _ in mdns
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(
              '_androidtvremote._tcp.local',
            ),
          )
          .timeout(const Duration(seconds: 2))) {
        break;
      }
    } catch (_) {
      // Best-effort permission trigger only.
    } finally {
      mdns.stop();
    }
  }

  void _goBack() {
    if (_pageIndex.value == 0) {
      Get.offAllNamed('/');
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _completeAndGoHome() async {
    Get.offAllNamed('/home');
    unawaited(markInstructionOnboardingCompleted());
  }

  void _goNext() {
    if (_pageIndex.value >= _pageCount - 1) {
      unawaited(_completeAndGoHome());
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onDiscoverTvs() {
    final discovery = Get.find<DeviceDiscoveryController>();
    discovery.setPreferredBrand(TvBrand.androidTv);
    unawaited(discovery.discoverDevices());
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: kGradientBottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            ImageRes.kGetStartedBackgroundAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1CB5E0),
                  Color(0xFF000046),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  child: Center(
                    child: Text(
                      'Instructions',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.98),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _syncPageIndex,
                    children: [
                      _InstructionStepPage(
                        title: 'Connect to the Same Network.',
                        body:
                            'Before anything, verify that your phone and your Android TV are connected to the exact same Wi-Fi network. This is crucial for a fast handshake.',
                        onPageShown:
                            _triggerLocalNetworkPermissionOnSameNetworkStep,
                      ),
                      _InstructionStepPage(
                        title: 'Start Discovery.',
                        body:
                            'Tap below to search for available Android TVs on your local network.',
                        showButton: true,
                        isDiscoveryStep: true,
                        onButtonTap: _onDiscoverTvs,
                      ),
                      _InstructionStepPage(
                        title: 'Get Ready for Your Code',
                        body:
                            'After selecting your TV from the list on the next screen, a unique 4-digit code will appear on your TV. Enter it precisely as seen.',
                        isCodeStep: true,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomPad),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleNavButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: _goBack,
                      ),
                      _CircleNavButton(
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _goNext,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStepPage extends StatelessWidget {
  const _InstructionStepPage({
    required this.title,
    required this.body,
    this.showButton = false,
    this.isDiscoveryStep = false,
    this.isCodeStep = false,
    this.onButtonTap,
    this.onPageShown,
  });

  final String title;
  final String body;
  final bool showButton;
  final bool isDiscoveryStep;
  final bool isCodeStep;
  final VoidCallback? onButtonTap;
  final Future<void> Function()? onPageShown;

  @override
  Widget build(BuildContext context) {
    if (onPageShown != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(onPageShown!());
      });
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🔥 TITLE
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 50),

          // 🎯 HERO SECTION

          SizedBox(
            height: 290,
            child: isDiscoveryStep
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final lineWidth = width * 0.86;
                      final mobileHeight = width * 0.28;
                      final timeHeight = width * 0.38;
                      final tvHeight = width * 0.18;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 18,
                            child: Image.asset(
                              "assets/images/onboarding/Line.png",
                              width: lineWidth,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            left: width * 0.02,
                            top: 92,
                            child: Image.asset(
                              "assets/images/onboarding/Mobile1.png",
                              height: mobileHeight,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            right: 120,
                            top: 108,
                            child: Image.asset(
                              "assets/images/onboarding/Time.png",
                              height: timeHeight,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            right: width * 0.02,
                            top: 110,
                            child: Image.asset(
                              "assets/images/onboarding/LCD1.png",
                              height: tvHeight,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : isCodeStep
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final phoneWidth = width * 0.39;
                          final tvWidth = width * 0.58;
                          final barWidth = width * 0.33;
                          final digitWidth = width * 0.07;

                          Widget digit(String value) {
                            return Image.asset(
                              'assets/images/onboarding/$value.png',
                              width: digitWidth,
                              fit: BoxFit.contain,
                            );
                          }

                          return Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 24,
                                child: Container(
                                  width: phoneWidth,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      width: 1.5,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.18),
                                        Colors.white.withValues(alpha: 0.05),
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 20,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: List.generate(
                                            4,
                                            (_) => Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 2,
                                                ),
                                                child: Container(
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.55),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: width * 0.17,
                                top: 128,
                                child: SizedBox(
                                  width: barWidth,
                                  child: Stack(
                                    children: [
                                      Image.asset(
                                        'assets/images/onboarding/Mobile Type Bar.png',
                                        fit: BoxFit.contain,
                                      ),
                                      Positioned.fill(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            10,
                                            32,
                                            10,
                                            14,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  digit('1'),
                                                  digit('2'),
                                                  digit('3'),
                                                ],
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  digit('4'),
                                                  digit('5'),
                                                  digit('6'),
                                                ],
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  digit('7'),
                                                  digit('8'),
                                                  digit('9'),
                                                ],
                                              ),
                                              Center(child: digit('0')),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 72,
                                child: Image.asset(
                                  'assets/images/onboarding/LCD2.png',
                                  width: tvWidth,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final centerRingSize = width * 0.64;
                          final sideRingSize = width * 0.30;
                          final centerWifiWidth = width * 0.56;
                          final sideDeviceWidth = width * 0.28;

                          Widget frostedRing(double size, Widget child) {
                            return Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                              child: Center(child: child),
                            );
                          }

                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 30,
                                left: width * 0.08,
                                child: frostedRing(
                                  sideRingSize,
                                  Image.asset(
                                    "assets/images/onboarding/Mobile.png",
                                    width: sideDeviceWidth,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 30,
                                right: width * 0.08,
                                child: frostedRing(
                                  sideRingSize,
                                  Image.asset(
                                    "assets/images/onboarding/LCD.png",
                                    width: sideDeviceWidth * 1.5,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 88,
                                child: frostedRing(
                                  centerRingSize,
                                  Image.asset(
                                    "assets/images/onboarding/Wifi.png",
                                    width: centerWifiWidth,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          const SizedBox(height: 30),

          // 🔘 BUTTON (only for 2nd screen)
          if (showButton)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onButtonTap,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "DISCOVER TVS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

          if (showButton) const SizedBox(height: 26),

          // 📝 DESCRIPTION
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleNavButton extends StatelessWidget {
  const _CircleNavButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.95),
            size: 24,
          ),
        ),
      ),
    );
  }
}
