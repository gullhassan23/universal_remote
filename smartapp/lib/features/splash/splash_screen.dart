import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/config/admob_config.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/utils/constant.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _progressDuration = Duration(milliseconds: 3000);
  static const double _adTriggerProgress = 0.5;
  late final AnimationController _progressController;
  AppOpenAd? _appOpenAd;
  bool _hasTriedAdLoad = false;
  bool _hasTriggeredAdAtHalf = false;
  bool _isAdShowing = false;
  bool _isProgressComplete = false;
  bool _isAdFlowComplete = false;
  late final bool _isPremiumUser;
  late final AnalyticsService _analyticsService;

  @override
  void initState() {
    super.initState();
    _analyticsService = Get.find<AnalyticsService>();
    unawaited(
      _analyticsService.logScreen(
        screenName: 'SplashScreen',
        screenClass: 'SplashScreen',
      ),
    );
    _isPremiumUser = Get.find<PremiumController>().isPremium.value;
    _isAdFlowComplete = _isPremiumUser;
    _progressController = AnimationController(vsync: this, duration: _progressDuration)
      ..addListener(_handleProgressUpdate)
      ..addStatusListener(_handleProgressStatus);
    _loadAppOpenAdIfNeeded();
    _progressController.forward();
  }

  void _handleProgressUpdate() {
    if (!_hasTriggeredAdAtHalf && _progressController.value >= _adTriggerProgress) {
      _hasTriggeredAdAtHalf = true;
      _showAppOpenAdIfNeeded();
    }
  }

  void _handleProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _isProgressComplete = true;
    _goToGetStartedWhenReady();
  }

  void _loadAppOpenAdIfNeeded() {
    if (_isPremiumUser || _hasTriedAdLoad) return;
    final String adUnitId = AdMobConfig.appOpenAdUnitId;
    if (adUnitId.isEmpty) {
      _isAdFlowComplete = true;
      return;
    }

    _hasTriedAdLoad = true;
    unawaited(
      _analyticsService.logEvent(
        'click_SplashAppOpenAdLoad',
        params: {
          'screen_name': 'SplashScreen',
          'button_name': 'SplashAppOpenAdLoad',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    );
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          if (!mounted || _isPremiumUser) {
            ad.dispose();
            return;
          }
          unawaited(
            _analyticsService.logEvent(
              'admob_appopen_loaded',
              params: {
                'screen_name': 'SplashScreen',
                'ad_unit': 'app_open',
              },
            ),
          );
          _appOpenAd?.dispose();
          _appOpenAd = ad;
          if (_hasTriggeredAdAtHalf && !_isAdShowing) {
            _showLoadedAppOpenAd();
          }
        },
        onAdFailedToLoad: (error) {
          unawaited(
            _analyticsService.logEvent(
              'admob_appopen_failed_load',
              params: {
                'screen_name': 'SplashScreen',
                'ad_unit': 'app_open',
                'error_code': error.code,
                'error_domain': error.domain,
              },
            ),
          );
          _isAdFlowComplete = true;
          _goToGetStartedWhenReady();
        },
      ),
    );
  }

  void _showAppOpenAdIfNeeded() {
    if (_isPremiumUser) {
      _isAdFlowComplete = true;
      unawaited(
        _analyticsService.logEvent(
          'click_SplashAdFlowSkipped',
          params: {
            'screen_name': 'SplashScreen',
            'button_name': 'SplashAdFlowSkipped',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        ),
      );
      _goToGetStartedWhenReady();
      return;
    }
    if (_appOpenAd == null) {
      _isAdFlowComplete = true;
      _goToGetStartedWhenReady();
      return;
    }
    _showLoadedAppOpenAd();
  }

  void _showLoadedAppOpenAd() {
    final AppOpenAd? ad = _appOpenAd;
    if (ad == null || _isAdShowing) return;
    _isAdShowing = true;
    unawaited(
      _analyticsService.logEvent(
        'click_SplashAdShown',
        params: {
          'screen_name': 'SplashScreen',
          'button_name': 'SplashAdShown',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    );
    _appOpenAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd shownAd) {
        unawaited(
          _analyticsService.logEvent(
            'admob_appopen_shown',
            params: {
              'screen_name': 'SplashScreen',
              'ad_unit': 'app_open',
            },
          ),
        );
      },
      onAdDismissedFullScreenContent: (AppOpenAd shownAd) {
        shownAd.dispose();
        _isAdShowing = false;
        _isAdFlowComplete = true;
        unawaited(
          _analyticsService.logEvent(
            'admob_appopen_dismissed',
            params: {
              'screen_name': 'SplashScreen',
              'ad_unit': 'app_open',
            },
          ),
        );
        _goToGetStartedWhenReady();
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd shownAd, AdError error) {
        shownAd.dispose();
        _isAdShowing = false;
        _isAdFlowComplete = true;
        unawaited(
          _analyticsService.logEvent(
            'admob_appopen_failed_show',
            params: {
              'screen_name': 'SplashScreen',
              'ad_unit': 'app_open',
              'error_code': error.code,
            },
          ),
        );
        _goToGetStartedWhenReady();
      },
      onAdImpression: (AppOpenAd shownAd) {
        unawaited(
          _analyticsService.logEvent(
            'admob_appopen_impression',
            params: {
              'screen_name': 'SplashScreen',
              'ad_unit': 'app_open',
            },
          ),
        );
      },
      onAdClicked: (AppOpenAd shownAd) {
        unawaited(
          _analyticsService.logEvent(
            'admob_appopen_clicked',
            params: {
              'screen_name': 'SplashScreen',
              'ad_unit': 'app_open',
            },
          ),
        );
      },
    );
    ad.show();
  }

  void _goToGetStartedWhenReady() {
    if (!_isProgressComplete || !_isAdFlowComplete) return;
    if (!mounted) return;
    Get.offAllNamed('/get-started');
  }

  @override
  void dispose() {
    _progressController
      ..removeListener(_handleProgressUpdate)
      ..removeStatusListener(_handleProgressStatus)
      ..dispose();
    _appOpenAd?.dispose();
    super.dispose();
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
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      final double value = _progressController.value;
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
