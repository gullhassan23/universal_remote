import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:smartapp/utils/constant.dart';

import 'onboarding/onboarding_screen.dart';

/// Bundled background art (Waves_Design).

/// Onboarding screen — Android TV “Universal Remote” intro.
class GetStarted extends StatelessWidget {
  const GetStarted({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: kGradientBottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Texture / shapes from asset (opaque areas stay visible).
          Image.asset(
            kGetStartedBackgroundAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          // Your two colors on top — semi-transparent so image + gradient dono mix.
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
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'R',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    height: 0.95,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2,
                    fontFamily: 'serif',
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 16,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = math.min(constraints.maxWidth * 0.72, 280.0);
                      return Center(
                        child: SizedBox(
                          width: side,
                          height: side,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                size: Size.square(side),
                                painter: _DottedDeviceRingPainter(side: side),
                              ),
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
                Padding(
                  padding: EdgeInsets.fromLTRB(28, 0, 28, 24 + bottomInset),
                  child: Column(
                    children: [
                      const Text(
                        'Welcome to Universal Remote.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Effortless control for your Android TV is just moments away.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: buttonText,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () async {
                            final completed =
                                await isInstructionOnboardingCompleted();
                            if (completed) {
                              Get.offAllNamed('/home');
                            } else {
                              Get.offAllNamed('/instructions');
                            }
                          },
                          child: const Text(
                            'GET STARTED',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
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
        ],
      ),
    );
  }
}

/// Single dotted oval around phone, TV, and router (matches reference screenshot).
class _DottedDeviceRingPainter extends CustomPainter {
  _DottedDeviceRingPainter({required this.side});

  final double side;

  /// Match [Image.asset] layout; heights are estimates for icon centering.
  static const double _phoneAspect = 1.55;
  static const double _tvAspect = 0.68;
  static const double _wifiAspect = 0.72;

  @override
  void paint(Canvas canvas, Size size) {
    final mobileW = side * 0.22;
    final mobileH = mobileW * _phoneAspect;
    final mobileC =
        Offset(side * 0.02 + mobileW / 2, side * 0.06 + mobileH / 2);

    final tvW = side * 0.39;
    final tvH = tvW * _tvAspect;
    final tvC = Offset(side - side * 0.01 - tvW / 2, side * 0.09 + tvH / 2);

    final wifiW = side * 0.28;
    final wifiH = wifiW * _wifiAspect;
    final wifiC = Offset(side / 2, side - side * 0.02 - wifiH / 2);

    final centroid = Offset(
      (mobileC.dx + tvC.dx + wifiC.dx) / 3,
      (mobileC.dy + tvC.dy + wifiC.dy) / 3,
    );

    var maxDist = 0.0;
    for (final p in <Offset>[mobileC, tvC, wifiC]) {
      maxDist = math.max(maxDist, (p - centroid).distance);
    }
    final baseR = maxDist + side * 0.09;

    // Slightly taller oval like the marketing screenshot (not a perfect circle).
    final oval = Path()
      ..addOval(
        Rect.fromCenter(
          center: centroid,
          width: baseR * 2 * 1.02,
          height: baseR * 2 * 1.08,
        ),
      );

    final stroke = (side * 0.0065).clamp(1.2, 2.2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const dashLen = 5.5;
    const gapLen = 5.0;
    for (final metric in oval.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashLen, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, len), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedDeviceRingPainter oldDelegate) =>
      oldDelegate.side != side;
}
