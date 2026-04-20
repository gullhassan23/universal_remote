import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:smartapp/controllers/premium_controller.dart';

class AdController extends GetxController {
  AdController({
    required this.adUnitId,
    this.adSize = AdSize.banner,
    this.adRequest = const AdRequest(),
  });

  final String adUnitId;
  final AdSize adSize;
  final AdRequest adRequest;
  static const Duration _retryDelay = Duration(seconds: 30);
  static const String _logTag = '[ADS]';

  final RxBool isAdLoaded = false.obs;
  final RxBool isAdLoading = false.obs;
  final Rxn<BannerAd> bannerAd = Rxn<BannerAd>();

  late final PremiumController _premiumController;
  Worker? _premiumWorker;
  bool _isLoading = false;
  bool _isControllerClosed = false;
  Timer? _retryTimer;

  @override
  void onInit() {
    super.onInit();
    _premiumController = Get.find<PremiumController>();
    _premiumWorker = ever<bool>(
      _premiumController.isPremium,
      (_) => syncWithPremiumStatus(),
    );
    syncWithPremiumStatus();
  }

  void syncWithPremiumStatus() {
    if (_premiumController.isPremium.value) {
      _log('Premium user detected; disposing banner and canceling retries.');
      disposeBannerAd();
      return;
    }
    unawaited(loadBannerAd());
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
          _log(
            'Banner failed to load: code=${error.code}, domain=${error.domain}, message=${error.message}',
          );
          _scheduleRetry(reason: 'load_failed');
        },
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

  @override
  void onClose() {
    _isControllerClosed = true;
    _premiumWorker?.dispose();
    disposeBannerAd();
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
}
