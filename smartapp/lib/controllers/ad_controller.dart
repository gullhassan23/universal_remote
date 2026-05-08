import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/controllers/tv_connection_controller.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/tv_service_interface.dart';

class AdController extends GetxController {
  AdController({
    required this.adUnitId,
    required this.interstitialAdUnitId,
    this.adSize = AdSize.banner,
    this.adRequest = const AdRequest(),
  });

  final String adUnitId;
  final String interstitialAdUnitId;
  final AdSize adSize;
  final AdRequest adRequest;
  static const Duration _retryDelay = Duration(seconds: 30);
  static const Duration _interstitialInterval = Duration(minutes: 2);
  static const String _logTag = '[ADS]';

  final RxBool isAdLoaded = false.obs;
  final RxBool isAdLoading = false.obs;
  final Rxn<BannerAd> bannerAd = Rxn<BannerAd>();
  final RxBool isInterstitialReady = false.obs;

  late final PremiumController _premiumController;
  late final TvConnectionController _connectionController;
  late final AnalyticsService _analyticsService;
  Worker? _premiumWorker;
  Worker? _connectionWorker;
  bool _isLoading = false;
  bool _isInterstitialLoading = false;
  bool _isInterstitialShowing = false;
  bool _isControllerClosed = false;
  bool _wasConnected = false;
  Timer? _retryTimer;
  Timer? _interstitialTimer;
  InterstitialAd? _interstitialAd;

  @override
  void onInit() {
    super.onInit();
    _premiumController = Get.find<PremiumController>();
    _connectionController = Get.find<TvConnectionController>();
    _analyticsService = Get.find<AnalyticsService>();
    _premiumWorker = ever<bool>(
      _premiumController.isPremium,
      (_) => syncWithPremiumStatus(),
    );
    _connectionWorker = ever<TvConnectionState>(
      _connectionController.connectionState,
      _handleConnectionStateChanged,
    );
    _wasConnected =
        _connectionController.connectionState.value == TvConnectionState.connected;
    syncWithPremiumStatus();
    _handleConnectionStateChanged(_connectionController.connectionState.value);
  }

  void syncWithPremiumStatus() {
    if (_premiumController.isPremium.value) {
      _log(
        'Premium user detected; disposing ads and canceling retries.',
      );
      disposeBannerAd();
      _stopInterstitialTimer();
      _disposeInterstitial();
      return;
    }
    unawaited(loadBannerAd());
    unawaited(loadInterstitialAd());
    if (_connectionController.connectionState.value ==
        TvConnectionState.connected) {
      _startInterstitialTimer();
    }
  }

  Future<void> loadBannerAd() async {
    if (_isControllerClosed || _premiumController.isPremium.value) {
      _log('Load skipped: controller closed or premium active.');
      return;
    }
    if (adUnitId.isEmpty) {
      _log('Load skipped: adUnitId is empty.');
      return;
    }

    if (_isLoading || bannerAd.value != null) {
      _log('Load skipped: already loading or ad already loaded.');
      return;
    }

    _log('Load requested.');
    _setLoading(true);
    isAdLoaded.value = false;

    final bool hasInternet = await _hasInternetConnection();
    if (_isControllerClosed || _premiumController.isPremium.value) {
      _setLoading(false);
      _log('Load aborted after connectivity check.');
      return;
    }
    if (!hasInternet) {
      _setLoading(false);
      _log('No internet reachability; scheduling retry.');
      _scheduleRetry(reason: 'offline');
      return;
    }

    late final BannerAd pendingAd;
    pendingAd = BannerAd(
      adUnitId: adUnitId,
      request: adRequest,
      size: adSize,
      listener: BannerAdListener(
        onAdLoaded: (Ad loadedAd) {
          if (_isControllerClosed) {
            loadedAd.dispose();
            return;
          }
          _setLoading(false);
          if (loadedAd is! BannerAd) {
            loadedAd.dispose();
            return;
          }
          if (!identical(loadedAd, pendingAd)) {
            loadedAd.dispose();
            return;
          }
          bannerAd.value?.dispose();
          bannerAd.value = loadedAd;
          isAdLoaded.value = true;
          _cancelRetry();
          _trackAdEvent('admob_banner_loaded');
          _log('Banner loaded successfully.');
        },
        onAdFailedToLoad: (Ad failedAd, LoadAdError error) {
          if (_isControllerClosed) {
            failedAd.dispose();
            return;
          }
          _setLoading(false);
          failedAd.dispose();
          if (!identical(failedAd, pendingAd)) {
            return;
          }
          bannerAd.value = null;
          isAdLoaded.value = false;
          _trackAdEvent(
            'admob_banner_failed_load',
            extra: <String, Object?>{
              'error_code': error.code,
              'error_domain': error.domain,
            },
          );
          _log(
            'Banner failed to load: code=${error.code}, domain=${error.domain}, message=${error.message}',
          );
          _scheduleRetry(reason: 'load_failed');
        },
        onAdOpened: (_) => _trackAdEvent('admob_banner_opened'),
        onAdClosed: (_) => _trackAdEvent('admob_banner_closed'),
        onAdImpression: (_) => _trackAdEvent('admob_banner_impression'),
        onAdClicked: (_) => _trackAdEvent('admob_banner_clicked'),
      ),
    );

    _log('Calling BannerAd.load().');
    pendingAd.load();
  }

  void disposeBannerAd() {
    final currentAd = bannerAd.value;
    bannerAd.value = null;
    currentAd?.dispose();
    isAdLoaded.value = false;
    _setLoading(false);
    _cancelRetry();
  }

  Future<void> loadInterstitialAd() async {
    if (_isControllerClosed || _premiumController.isPremium.value) {
      return;
    }
    if (interstitialAdUnitId.isEmpty ||
        _isInterstitialLoading ||
        _interstitialAd != null) {
      return;
    }

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _isInterstitialLoading = false;
          if (_isControllerClosed || _premiumController.isPremium.value) {
            ad.dispose();
            return;
          }
          _interstitialAd?.dispose();
          _interstitialAd = ad;
          isInterstitialReady.value = true;
          _trackAdEvent('admob_interstitial_loaded');
          _log('Interstitial loaded successfully.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isInterstitialLoading = false;
          isInterstitialReady.value = false;
          _trackAdEvent(
            'admob_interstitial_failed_load',
            extra: <String, Object?>{
              'error_code': error.code,
              'error_domain': error.domain,
            },
          );
          _log(
            'Interstitial failed to load: code=${error.code}, domain=${error.domain}, message=${error.message}',
          );
        },
      ),
    );
  }

  void showConnectionInterstitial({VoidCallback? onCompleted}) {
    if (_premiumController.isPremium.value || interstitialAdUnitId.isEmpty) {
      onCompleted?.call();
      return;
    }
    if (_isInterstitialShowing) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      unawaited(loadInterstitialAd());
      onCompleted?.call();
      return;
    }

    _isInterstitialShowing = true;
    _interstitialAd = null;
    isInterstitialReady.value = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd shownAd) {
        _trackAdEvent('admob_interstitial_shown');
      },
      onAdDismissedFullScreenContent: (InterstitialAd shownAd) {
        shownAd.dispose();
        _isInterstitialShowing = false;
        _trackAdEvent('admob_interstitial_dismissed');
        onCompleted?.call();
        unawaited(loadInterstitialAd());
      },
      onAdFailedToShowFullScreenContent: (
        InterstitialAd shownAd,
        AdError error,
      ) {
        shownAd.dispose();
        _trackAdEvent(
          'admob_interstitial_failed_show',
          extra: <String, Object?>{
            'error_code': error.code,
          },
        );
        _log('Interstitial failed to show: ${error.message}');
        _isInterstitialShowing = false;
        onCompleted?.call();
        unawaited(loadInterstitialAd());
      },
      onAdImpression: (InterstitialAd shownAd) {
        _trackAdEvent('admob_interstitial_impression');
      },
      onAdClicked: (InterstitialAd shownAd) {
        _trackAdEvent('admob_interstitial_clicked');
      },
    );
    ad.show();
  }

  void _handleConnectionStateChanged(TvConnectionState state) {
    final bool isConnected = state == TvConnectionState.connected;
    if (_premiumController.isPremium.value || interstitialAdUnitId.isEmpty) {
      _wasConnected = isConnected;
      _stopInterstitialTimer();
      return;
    }
    if (!isConnected) {
      _stopInterstitialTimer();
      _wasConnected = false;
      return;
    }
    if (!_wasConnected) {
      showConnectionInterstitial();
    }
    _startInterstitialTimer();
    _wasConnected = true;
  }

  void _startInterstitialTimer() {
    if (_interstitialTimer?.isActive ?? false) {
      return;
    }
    _interstitialTimer = Timer.periodic(_interstitialInterval, (_) {
      if (_isControllerClosed ||
          _premiumController.isPremium.value ||
          _connectionController.connectionState.value !=
              TvConnectionState.connected) {
        _stopInterstitialTimer();
        return;
      }
      showConnectionInterstitial();
    });
    _log(
      'Started interstitial timer for every ${_interstitialInterval.inMinutes} minutes.',
    );
  }

  void _stopInterstitialTimer() {
    if (_interstitialTimer?.isActive ?? false) {
      _log('Stopping interstitial timer.');
    }
    _interstitialTimer?.cancel();
    _interstitialTimer = null;
  }

  void _disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialLoading = false;
    _isInterstitialShowing = false;
    isInterstitialReady.value = false;
  }

  @override
  void onClose() {
    _isControllerClosed = true;
    _premiumWorker?.dispose();
    _connectionWorker?.dispose();
    disposeBannerAd();
    _stopInterstitialTimer();
    _disposeInterstitial();
    super.onClose();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    isAdLoading.value = value;
  }

  void _scheduleRetry({required String reason}) {
    if (_isControllerClosed || _premiumController.isPremium.value) {
      return;
    }
    if (_retryTimer?.isActive ?? false) {
      _log('Retry already scheduled; keeping existing timer.');
      return;
    }
    _log('Scheduling retry in ${_retryDelay.inSeconds}s (reason: $reason).');
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      if (_isControllerClosed || _premiumController.isPremium.value) {
        return;
      }
      _log('Retry timer fired; requesting load.');
      unawaited(loadBannerAd());
    });
  }

  void _cancelRetry() {
    if (_retryTimer?.isActive ?? false) {
      _log('Canceling scheduled retry.');
    }
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final List<InternetAddress> result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      final bool reachable =
          result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      _log('Connectivity check result: $reachable.');
      return reachable;
    } on TimeoutException {
      _log('Connectivity check timed out.');
      return false;
    } on SocketException catch (error) {
      _log('Connectivity socket error: $error');
      return false;
    } catch (error) {
      _log('Connectivity check unexpected error: $error');
      return false;
    }
  }

  void _log(String message) {
    debugPrint('$_logTag $message');
  }

  void _trackAdEvent(String name, {Map<String, Object?>? extra}) {
    unawaited(
      _analyticsService.logAdEvent(
        action: _toAdAction(name),
        adType: _toAdType(name),
        adSdkName: 'admob',
        adPlacement: 'banner_or_interstitial',
        params: <String, Object?>{
          'screen_name': 'AdController',
          'event_name': name,
          ...?extra,
        },
      ),
    );
  }

  String _toAdType(String name) {
    final v = name.toLowerCase();
    if (v.contains('banner')) return 'banner';
    if (v.contains('interstitial')) return 'interstitial';
    if (v.contains('rewarded')) return 'rewarded';
    return 'unknown';
  }

  String _toAdAction(String name) {
    final v = name.toLowerCase();
    if (v.contains('loaded')) return 'loaded';
    if (v.contains('failed_load')) return 'failed_load';
    if (v.contains('failed_show')) return 'failed_show';
    if (v.contains('shown')) return 'shown';
    if (v.contains('impression')) return 'impression';
    if (v.contains('clicked')) return 'clicked';
    if (v.contains('dismissed')) return 'dismissed';
    if (v.contains('opened')) return 'shown';
    if (v.contains('closed')) return 'dismissed';
    return 'unknown';
  }
}
