import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdMobConfig {
  static String get bannerAdUnitId {
    if (!kIsWeb && Platform.isAndroid) {
      return _envOrFallback(
        'ADMOB_ANDROID_BANNER_ID',
        'ca-app-pub-3605518487927639/9209972929',
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return _envOrFallback('ADMOB_IOS_BANNER_ID', '');
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
      return _envOrFallback('ADMOB_IOS_INTERSTITIAL_ID', '');
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
      return _envOrFallback('ADMOB_IOS_REWARDED_ID', '');
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
      return _envOrFallback('ADMOB_IOS_APP_OPEN_ID', '');
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
