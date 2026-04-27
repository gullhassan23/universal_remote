import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/utils/constant.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _progressDuration = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _goToGetStartedAfterDelay();
  }

  Future<void> _goToGetStartedAfterDelay() async {
    await Future<void>.delayed(_progressDuration);
    if (!mounted) return;
    Get.offAllNamed('/get-started');
  }

  @override
  Widget build(BuildContext context) {
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Column(
                children: [
                  SizedBox(height: 130),
                  const Text(
                    'Universal Remote',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final side =
                            math.min(constraints.maxWidth * 0.72, 280.0);
                        return Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  top: side * 0.06,
                                  left: side * 0.02,
                                  child: Image.asset(
                                    'assets/images/Mobile.png',
                                    width: side * 0.22,
                                  ),
                                ),
                                Positioned(
                                  top: side * 0.09,
                                  right: side * 0.01,
                                  child: Image.asset(
                                    'assets/images/LCD.png',
                                    width: side * 0.39,
                                  ),
                                ),
                                Positioned(
                                  bottom: side * 0.02,
                                  child: Image.asset(
                                    'assets/images/Wifi.png',
                                    width: side * 0.28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    duration: _progressDuration,
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 10,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(value * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
