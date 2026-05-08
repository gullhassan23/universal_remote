import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  Future<bool> showRewardedAd({
    required String adUnitId,
    Duration timeout = const Duration(minutes: 2),
    void Function(String event, Map<String, Object?> extra)? onEvent,
  }) async {
    if (adUnitId.trim().isEmpty) return false;

    final completer = Completer<bool>();
    var earned = false;

    void track(String name, [Map<String, Object?> extra = const {}]) {
      onEvent?.call(name, extra);
    }

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) => track('admob_rewarded_shown'),
            onAdDismissedFullScreenContent: (RewardedAd shownAd) {
              shownAd.dispose();
              if (!completer.isCompleted) {
                completer.complete(earned);
              }
              track('admob_rewarded_dismissed', <String, Object?>{'earned': earned});
            },
            onAdFailedToShowFullScreenContent: (RewardedAd shownAd, AdError e) {
              shownAd.dispose();
              track(
                'admob_rewarded_failed_show',
                <String, Object?>{'error_code': e.code, 'message': e.message},
              );
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
            onAdImpression: (_) => track('admob_rewarded_impression'),
            onAdClicked: (_) => track('admob_rewarded_clicked'),
          );

          ad.show(
            onUserEarnedReward: (_, reward) {
              earned = true;
              track(
                'admob_rewarded_earned',
                <String, Object?>{
                  'reward_type': reward.type,
                  'reward_amount': reward.amount,
                },
              );
            },
          );
        },
        onAdFailedToLoad: (LoadAdError e) {
          track(
            'admob_rewarded_failed_load',
            <String, Object?>{'error_code': e.code, 'message': e.message},
          );
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          track('admob_rewarded_timeout');
          return false;
        },
      );
    } catch (e) {
      debugPrint('[RewardedAdService] Unexpected error: $e');
      return false;
    }
  }
}

