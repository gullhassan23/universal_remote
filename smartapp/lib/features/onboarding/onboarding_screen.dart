import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncPageIndex(int index) {
    if (mounted) setState(() => _pageIndex = index);
  }

  void _goBack() {
    if (_pageIndex == 0) {
      Get.offAllNamed('/');
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _completeAndGoHome() async {
    await markInstructionOnboardingCompleted();
    if (!mounted) return;
    Get.offAllNamed('/home');
  }

  void _goNext() {
    if (_pageIndex >= _pageCount - 1) {
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
            kGetStartedBackgroundAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kGradientTop.withValues(alpha: 0.58),
                  kGradientBottom.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _goBack,
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 22,
                        ),
                      ),
                      Text(
                        'Instructions',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.98),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                            'Before anything, verify that your phone and your '
                            'Android TV are connected to the exact same Wi‑Fi '
                            'network. This is crucial for a fast handshake.',
                        heroAsset: 'assets/images/instruction_connect.png',
                      ),
                      _InstructionStepPage(
                        title: 'Start Discovery.',
                        body:
                            'Tap below to search for available Android TVs on '
                            'your local network.',
                        heroAsset: 'assets/images/instruction_discovery.png',
                        extra: _DiscoverTvsButton(onPressed: _onDiscoverTvs),
                      ),
                      _InstructionStepPage(
                        title: 'Get Ready for Your Code.',
                        body:
                            'After selecting your TV from the list on the next '
                            'screen, a unique 4-digit code will appear on your '
                            'TV. Enter it precisely as seen.',
                        heroAsset: 'assets/images/instruction_pairing.png',
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
    required this.heroAsset,
    this.extra,
  });

  final String title;
  final String body;
  final String heroAsset;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Image.asset(
                      "assets/images/onboarding/Mobile.png",
                    ),
                    // Image.asset(
                    //   "assets/images/onboarding/Wifi.png",
                    // ),
                    // Image.asset(
                    //   "assets/images/onboarding/LCD.png",
                    // ),
                  ],
                ),
                // Image.asset(
                //   heroAsset,
                //   fit: BoxFit.contain,
                //   filterQuality: FilterQuality.high,
                //   height: math.min(constraints.maxHeight * 0.38, 260),
                // ),
                if (extra != null) ...[
                  const SizedBox(height: 20),
                  extra!,
                ],
                const SizedBox(height: 24),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiscoverTvsButton extends StatelessWidget {
  const _DiscoverTvsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.2,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: const Text(
          'DISCOVER TVS',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
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
