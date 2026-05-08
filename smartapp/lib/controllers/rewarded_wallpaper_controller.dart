import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smartapp/config/admob_config.dart';
import 'package:smartapp/controllers/premium_controller.dart';
import 'package:smartapp/controllers/remote_style_controller.dart';
import 'package:smartapp/controllers/temporary_wallpaper_timer_controller.dart';
import 'package:smartapp/services/analytics_service.dart';
import 'package:smartapp/services/rewarded_ad_service.dart';
import 'package:smartapp/widgets/rewarded_wallpaper_sheet.dart';

enum RewardedWallpaperOutcome { dismissed, unlockedTemporarily, goPremium }

class RewardedWallpaperController extends GetxController {
  static const String _logScreen = 'RewardedWallpaperController';

  RewardedWallpaperController({
    PremiumController? premiumController,
    RemoteStyleController? styleController,
    TemporaryWallpaperTimerController? timerController,
    RewardedAdService? rewardedAdService,
    AnalyticsService? analyticsService,
  }) : _premiumController = premiumController ?? Get.find<PremiumController>(),
       _styleController = styleController ?? Get.find<RemoteStyleController>(),
       _timerController =
           timerController ?? Get.find<TemporaryWallpaperTimerController>(),
       _rewardedAdService = rewardedAdService ?? Get.find<RewardedAdService>(),
       _analyticsService = analyticsService ?? Get.find<AnalyticsService>();

  final PremiumController _premiumController;
  final RemoteStyleController _styleController;
  final TemporaryWallpaperTimerController _timerController;
  final RewardedAdService _rewardedAdService;
  final AnalyticsService _analyticsService;

  final RxBool isRewardedLoading = false.obs;

  Future<RewardedWallpaperOutcome> handlePremiumWallpaperTap({
    required String wallpaperPath,
    required VoidCallback openPaywall,
  }) async {
    if (_premiumController.isPremium.value) {
      await _styleController.selectAndApply(wallpaperPath);
      return RewardedWallpaperOutcome.unlockedTemporarily;
    }

    final action = await Get.bottomSheet<RewardedWallpaperSheetAction>(
      const RewardedWallpaperSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    _track(
      'wallpaper_rewarded_sheet_dismissed',
      extra: <String, Object?>{'action': action?.name ?? 'null'},
    );

    if (action == null || action == RewardedWallpaperSheetAction.cancel) {
      return RewardedWallpaperOutcome.dismissed;
    }

    if (action == RewardedWallpaperSheetAction.goPremium) {
      _track('wallpaper_rewarded_go_premium_clicked');
      await _styleController.setPendingPremiumWallpaper(wallpaperPath);
      openPaywall();
      return RewardedWallpaperOutcome.goPremium;
    }

    _track('wallpaper_rewarded_watch_ad_clicked');
    final earned = await _watchRewardedAd();
    if (!earned) return RewardedWallpaperOutcome.dismissed;

    await _timerController.startTemporaryWallpaper(
      wallpaperPath: wallpaperPath,
      duration: const Duration(seconds: 30),
    );

    return RewardedWallpaperOutcome.unlockedTemporarily;
  }

  Future<bool> _watchRewardedAd() async {
    final adUnitId = AdMobConfig.rewardedAdUnitId;
    if (adUnitId.trim().isEmpty) {
      Get.snackbar(
        'Ad unavailable',
        'Rewarded ads are not available right now.',
        colorText: Colors.white,
      );
      _track('wallpaper_rewarded_ad_unit_missing');
      return false;
    }

    isRewardedLoading.value = true;
    try {
      final earned = await _rewardedAdService.showRewardedAd(
        adUnitId: adUnitId,
        onEvent: (event, extra) => _track(event, extra: extra),
      );
      if (!earned) {
        Get.snackbar(
          'Ad not completed',
          'Please finish the ad to unlock this wallpaper for 30 seconds.',
          colorText: Colors.white,
        );
        _track('wallpaper_rewarded_not_earned');
        return false;
      }
      _track('wallpaper_rewarded_earned');
      return true;
    } finally {
      isRewardedLoading.value = false;
    }
  }

  void _track(String name, {Map<String, Object?>? extra}) {
    unawaited(
      _analyticsService.logEvent(
        name,
        params: <String, Object?>{
          'screen_name': _logScreen,
          ...?extra,
        },
      ),
    );
  }
}
