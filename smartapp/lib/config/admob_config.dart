import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdMobConfig {
  static const String _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _iosTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _iosTestAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/5575463023';

  static String get bannerAdUnitId {
    if (!kIsWeb && Platform.isAndroid) {
      return _envOrFallback(
        'ADMOB_ANDROID_BANNER_ID',
        'ca-app-pub-3605518487927639/9209972929',
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return _envOrFallback('ADMOB_IOS_BANNER_ID', _iosTestBannerAdUnitId);
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (!kIsWeb && Platform.isAndroid) {
      return _envOrFallback(
        'ADMOB_ANDROID_INTERSTITIAL_ID',
        'ca-app-pub-3605518487927639/5270727918',
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return _envOrFallback(
        'ADMOB_IOS_INTERSTITIAL_ID',
        _iosTestInterstitialAdUnitId,
      );
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (!kIsWeb && Platform.isAndroid) {
      return _envOrFallback(
        'ADMOB_ANDROID_REWARDED_ID',
        'ca-app-pub-3605518487927639/7238415706',
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return _envOrFallback('ADMOB_IOS_REWARDED_ID', _iosTestRewardedAdUnitId);
    }
    return '';
  }

  static String get mrecAdUnitId {
    if (!kIsWeb && Platform.isAndroid) {
      return _envOrFallback(
        'ADMOB_ANDROID_MREC_ID',
        'ca-app-pub-3605518487927639/2257551761',
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return _envOrFallback('ADMOB_IOS_MREC_ID', '');
    }
    return '';
  }

  static String get appOpenAdUnitId {
    if (!kIsWeb && Platform.isAndroid) {
      return _envOrFallback(
        'ADMOB_ANDROID_APP_OPEN_ID',
        'ca-app-pub-3605518487927639/4595940497',
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return _envOrFallback('ADMOB_IOS_APP_OPEN_ID', _iosTestAppOpenAdUnitId);
    }
    return '';
  }

  static String _envOrFallback(String key, String fallback) {
    final value = dotenv.env[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return fallback;
  }
}
