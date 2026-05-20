import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Reads ad timing from Firebase Remote Config (`adsControlTime` = seconds).
class RemoteConfigService {
  RemoteConfigService();

  static const String adsControlTimeKey = 'adsControlTime';
  static const int defaultAdsControlTimeSeconds = 30;

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 1)
            : const Duration(hours: 1),
      ),
    );
    await _remoteConfig.setDefaults(<String, Object>{
      adsControlTimeKey: defaultAdsControlTimeSeconds,
    });
    unawaited(_fetchAndActivate());
  }

  Future<void> _fetchAndActivate() async {
    try {
      await _remoteConfig
          .fetchAndActivate()
          .timeout(const Duration(seconds: 10));
      debugPrint(
        '[REMOTE_CONFIG] adsControlTime=${adsControlTimeSeconds}s',
      );
    } on TimeoutException {
      debugPrint('[REMOTE_CONFIG] fetch timed out; using defaults/cache.');
    } catch (error) {
      debugPrint('[REMOTE_CONFIG] fetch failed: $error');
    }
  }

  int get adsControlTimeSeconds {
    final int value = _remoteConfig.getInt(adsControlTimeKey);
    if (value <= 0) return defaultAdsControlTimeSeconds;
    return value.clamp(15, 600);
  }

  Duration get adsControlInterval =>
      Duration(seconds: adsControlTimeSeconds);
}
