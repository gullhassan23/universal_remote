import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/config/admob_config.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/mobile_ads_service.dart';

/// App open ads only in two cases:
/// 1. Cold start (splash calls [showColdStartAd] once).
/// 2. User left the app ([AppLifecycleState.paused]) and returned.
class AppOpenAdService extends GetxService with WidgetsBindingObserver {
  static const Duration _maxCacheDuration = Duration(hours: 4);
  static const Duration _loadMaxWait = Duration(seconds: 5);
  /// Ignore brief paused/inactive bursts (e.g. our own fullscreen ad).
  static const Duration _minBackgroundDuration = Duration(seconds: 1);
  /// Prevents duplicate show from the same resume burst (not a user-facing cooldown).
  static const Duration _minIntervalBetweenShows = Duration(seconds: 3);

  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadTime;
  AppLifecycleState? _lastLifecycleState;

  bool _coldStartFlowFinished = false;
  bool _userLeftAppToBackground = false;
  DateTime? _backgroundEnteredAt;
  DateTime? _lastShownAt;

  bool _isLoading = false;
  bool _isShowing = false;
  bool _ignorePauseWhileShowingOwnAd = false;

  late final PremiumController _premiumController;
  late final AnalyticsService _analyticsService;
  Worker? _premiumWorker;

  @override
  void onInit() {
    super.onInit();
    _premiumController = Get.find<PremiumController>();
    _analyticsService = Get.find<AnalyticsService>();
    WidgetsBinding.instance.addObserver(this);
    _premiumWorker = ever<bool>(
      _premiumController.isPremium,
      (_) => _syncWithPremiumStatus(),
    );
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _premiumWorker?.dispose();
    _disposeLoadedAd();
    super.onClose();
  }

  /// Call when splash/onboarding is done so resume ads do not overlap cold start.
  void markColdStartFlowFinished() {
    _coldStartFlowFinished = true;
    if (!_premiumController.isPremium.value) {
      unawaited(_preloadIfNeeded());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (!_ignorePauseWhileShowingOwnAd) {
        _userLeftAppToBackground = true;
        _backgroundEnteredAt = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed &&
        _lastLifecycleState == AppLifecycleState.paused &&
        _userLeftAppToBackground) {
      unawaited(_showOnReturnFromBackground());
    }
    _lastLifecycleState = state;
  }

  /// First launch only — invoked from splash once at ~50% progress.
  Future<bool> showColdStartAd({required String screenName}) async {
    if (_premiumController.isPremium.value) return false;
    final adUnitId = AdMobConfig.appOpenAdUnitId.trim();
    if (adUnitId.isEmpty) return false;

    try {
      await MobileAdsService.ensureInitialized();
    } catch (_) {
      return false;
    }

    unawaited(
      _analyticsService.logEvent(
        'click_SplashAppOpenAdLoad',
        params: <String, Object?>{
          'screen_name': screenName,
          'button_name': 'SplashAppOpenAdLoad',
        },
      ),
    );

    await _ensureAdLoaded(adUnitId);
    if (!_isAdAvailable) return false;

    return _showLoadedAd(
      screenName: screenName,
      trigger: 'cold_start',
    );
  }

  Future<void> _showOnReturnFromBackground() async {
    _userLeftAppToBackground = false;

    if (!_coldStartFlowFinished) return;
    if (_premiumController.isPremium.value) return;
    if (_isShowing || _isLoading) return;

    final backgroundAt = _backgroundEnteredAt;
    _backgroundEnteredAt = null;
    if (backgroundAt != null &&
        DateTime.now().difference(backgroundAt) < _minBackgroundDuration) {
      return;
    }

    final lastShown = _lastShownAt;
    if (lastShown != null &&
        DateTime.now().difference(lastShown) < _minIntervalBetweenShows) {
      return;
    }

    final adUnitId = AdMobConfig.appOpenAdUnitId.trim();
    if (adUnitId.isEmpty) return;

    await _ensureAdLoaded(adUnitId);
    if (!_isAdAvailable) return;

    await _showLoadedAd(
      screenName: 'AppOpenAdService',
      trigger: 'return_from_background',
    );
  }

  Future<void> _ensureAdLoaded(String adUnitId) async {
    if (_isAdAvailable) return;
    await _preloadIfNeeded(adUnitId: adUnitId);
    final deadline = DateTime.now().add(_loadMaxWait);
    while (!_isAdAvailable && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _preloadIfNeeded({String? adUnitId}) async {
    if (_premiumController.isPremium.value) return;
    if (_isLoading || _isAdAvailable) return;

    final unitId = (adUnitId ?? AdMobConfig.appOpenAdUnitId).trim();
    if (unitId.isEmpty) return;

    try {
      await MobileAdsService.ensureInitialized();
    } catch (_) {
      return;
    }

    _isLoading = true;
    final completer = Completer<void>();

    AppOpenAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          MobileAdsService.logMediationAdapter(ad, format: 'app_open');
          _isLoading = false;
          _disposeLoadedAd();
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isLoading = false;
          debugPrint(
            '[AppOpenAdService] Load failed: ${error.code} ${error.message}',
          );
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    await completer.future.timeout(_loadMaxWait, onTimeout: () {});
  }

  Future<bool> _showLoadedAd({
    required String screenName,
    required String trigger,
  }) async {
    final ad = _appOpenAd;
    if (ad == null || !_isAdAvailable || _isShowing) return false;

    final completer = Completer<bool>();
    _isShowing = true;
    _ignorePauseWhileShowingOwnAd = true;
    _appOpenAd = null;
    _appOpenLoadTime = null;
    _lastShownAt = DateTime.now();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd shownAd) {
        unawaited(
          _analyticsService.logEvent(
            'admob_appopen_shown',
            params: <String, Object?>{
              'screen_name': screenName,
              'ad_unit': 'app_open',
              'trigger': trigger,
            },
          ),
        );
      },
      onAdDismissedFullScreenContent: (AppOpenAd shownAd) {
        shownAd.dispose();
        _finishShow(completer, shown: true);
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd shownAd, AdError error) {
        shownAd.dispose();
        _finishShow(completer, shown: false);
      },
    );

    ad.show();
    return completer.future;
  }

  void _finishShow(Completer<bool> completer, {required bool shown}) {
    _isShowing = false;
    _ignorePauseWhileShowingOwnAd = false;
    _userLeftAppToBackground = false;
    if (!completer.isCompleted) completer.complete(shown);
    if (!_premiumController.isPremium.value && _coldStartFlowFinished) {
      unawaited(_preloadIfNeeded());
    }
  }

  bool get _isAdAvailable {
    final ad = _appOpenAd;
    final loadedAt = _appOpenLoadTime;
    if (ad == null || loadedAt == null) return false;
    return DateTime.now().difference(loadedAt) < _maxCacheDuration;
  }

  void _syncWithPremiumStatus() {
    if (_premiumController.isPremium.value) {
      _disposeLoadedAd();
    } else if (_coldStartFlowFinished) {
      unawaited(_preloadIfNeeded());
    }
  }

  void _disposeLoadedAd() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenLoadTime = null;
    _isLoading = false;
  }
}
