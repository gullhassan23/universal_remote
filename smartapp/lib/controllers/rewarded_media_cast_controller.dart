import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartapp/config/admob_config.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/widgets/rewarded_media_cast_sheet.dart';

enum _FreeMediaCastState {
  none(0),
  granted(1),
  consumed(2);

  const _FreeMediaCastState(this.value);
  final int value;

  static _FreeMediaCastState fromInt(int raw) {
    for (final s in _FreeMediaCastState.values) {
      if (s.value == raw) return s;
    }
    return _FreeMediaCastState.none;
  }
}

class RewardedMediaCastController extends GetxController {
  static const String _prefsKey = 'free_media_cast_state_v1';
  static const String _logScreen = 'RewardedMediaCastController';

  final RxInt _stateRaw = _FreeMediaCastState.none.value.obs;
  final RxBool isRewardedLoading = false.obs;

  late final AnalyticsService _analyticsService;

  _FreeMediaCastState get _state => _FreeMediaCastState.fromInt(_stateRaw.value);
  bool get hasConsumed => _state == _FreeMediaCastState.consumed;
  bool get hasEntitlement => _state == _FreeMediaCastState.granted;

  @override
  void onInit() {
    super.onInit();
    _analyticsService = Get.find<AnalyticsService>();
    unawaited(_restore());
  }

  Future<void> requestOneTimeFreeMediaCast({
    required VoidCallback openPaywall,
    required Future<bool> Function() ensureTvConnected,
    required Future<bool> Function() startCasting,
  }) async {
    await _restore();

    if (hasConsumed) {
      _track('media_cast_rewarded_consumed_blocked');
      openPaywall();
      return;
    }

    final action = await Get.bottomSheet<RewardedMediaCastSheetAction>(
      const RewardedMediaCastSheet(),
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
    _track(
      'media_cast_rewarded_sheet_dismissed',
      extra: <String, Object?>{'action': action?.name ?? 'null'},
    );

    if (action == null || action == RewardedMediaCastSheetAction.cancel) {
      return;
    }

    if (action == RewardedMediaCastSheetAction.goPremium) {
      _track('media_cast_rewarded_go_premium_clicked');
      openPaywall();
      return;
    }

    _track('media_cast_rewarded_watch_ad_clicked');
    final allowed = await _ensureEntitledOrWatchAd();
    if (!allowed) return;

    final connected = await ensureTvConnected();
    if (!connected) return;

    final success = await startCasting();
    if (!success) return;

    await _setState(_FreeMediaCastState.consumed);
    _track('media_cast_rewarded_consumed');
  }

  Future<bool> _ensureEntitledOrWatchAd() async {
    await _restore();
    if (hasEntitlement) {
      _track('media_cast_rewarded_entitlement_reused');
      return true;
    }

    final adUnitId = AdMobConfig.rewardedAdUnitId;
    if (adUnitId.isEmpty) {
      Get.snackbar(
        'Ad unavailable',
        'Rewarded ads are not available right now.',
        colorText: Colors.white,
      );
      _track('media_cast_rewarded_ad_unit_missing');
      return false;
    }

    isRewardedLoading.value = true;
    try {
      final earned = await _showRewardedAd(adUnitId);
      if (!earned) {
        Get.snackbar(
          'Ad not completed',
          'Please finish the ad to unlock 1 free media cast.',
          colorText: Colors.white,
        );
        _track('media_cast_rewarded_not_earned');
        return false;
      }
      await _setState(_FreeMediaCastState.granted);
      _track('media_cast_rewarded_earned');
      return true;
    } finally {
      isRewardedLoading.value = false;
    }
  }

  Future<bool> _showRewardedAd(String adUnitId) async {
    final completer = Completer<bool>();
    var earned = false;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _track('admob_rewarded_shown');
            },
            onAdDismissedFullScreenContent: (RewardedAd shownAd) {
              shownAd.dispose();
              if (!completer.isCompleted) {
                completer.complete(earned);
              }
              _track(
                'admob_rewarded_dismissed',
                extra: <String, Object?>{'earned': earned},
              );
            },
            onAdFailedToShowFullScreenContent: (RewardedAd shownAd, AdError e) {
              shownAd.dispose();
              _track(
                'admob_rewarded_failed_show',
                extra: <String, Object?>{'error_code': e.code, 'message': e.message},
              );
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
            onAdImpression: (_) => _track('admob_rewarded_impression'),
            onAdClicked: (_) => _track('admob_rewarded_clicked'),
          );

          ad.show(
            onUserEarnedReward: (_, reward) {
              earned = true;
              _track(
                'admob_rewarded_earned',
                extra: <String, Object?>{
                  'reward_type': reward.type,
                  'reward_amount': reward.amount,
                },
              );
            },
          );
        },
        onAdFailedToLoad: (LoadAdError e) {
          _track(
            'admob_rewarded_failed_load',
            extra: <String, Object?>{'error_code': e.code, 'message': e.message},
          );
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _track('admob_rewarded_timeout');
        return false;
      },
    );
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _stateRaw.value = prefs.getInt(_prefsKey) ?? _FreeMediaCastState.none.value;
    } catch (e) {
      debugPrint('[$_logScreen] Restore failed: $e');
      _stateRaw.value = _FreeMediaCastState.none.value;
    }
  }

  Future<void> _setState(_FreeMediaCastState next) async {
    _stateRaw.value = next.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, next.value);
    } catch (e) {
      debugPrint('[$_logScreen] Persist failed: $e');
    }
  }

  void _track(String name, {Map<String, Object?>? extra}) {
    unawaited(
      _analyticsService.logEvent(
        name,
        params: <String, Object?>{
          'screen_name': _logScreen,
          'state': _state.name,
          ...?extra,
        },
      ),
    );
  }
}

