import 'package:gameanalytics_sdk/gameanalytics.dart';

import 'app_analytics.dart';
import 'analytics_debug.dart';
import 'event_naming.dart';

class GameAnalyticsBackend implements AppAnalytics {
  GameAnalyticsBackend({
    required String gameKey,
    required String secretKey,
    required String build,
    required AnalyticsDebug debug,
    bool enabled = true,
  })  : _gameKey = gameKey.trim(),
        _secretKey = secretKey.trim(),
        _build = build.trim(),
        _debug = debug,
        _enabled = enabled;

  final String _gameKey;
  final String _secretKey;
  final String _build;
  final AnalyticsDebug _debug;
  final bool _enabled;

  bool _initialized = false;

  bool get isReady => _enabled && _initialized;

  @override
  Future<void> init() async {
    if (!_enabled) return;
    if (_initialized) return;
    if (_gameKey.isEmpty || _secretKey.isEmpty) {
      _debug.log('ga init skipped: missing keys');
      return;
    }
    if (_build.isEmpty) {
      _debug.log('ga init skipped: missing build');
      return;
    }
    try {
      // Let the first frame paint before native GA init runs on the UI isolate.
      await Future<void>.delayed(Duration.zero);
      GameAnalytics.configureBuild(_build);
      GameAnalytics.initialize(_gameKey, _secretKey);
      _initialized = true;
      _debug.log('ga initialized build=$_build');
    } catch (e) {
      _debug.log('ga init failed: $e');
      _initialized = false;
    }
  }

  @override
  Future<void> screenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?>? params,
  }) async {
    if (!isReady) return;
    final id = 'screen:${EventNaming.sanitizeToken(screenName)}';
    _debug.log('ga screenView id=$id');
    try {
      GameAnalytics.addDesignEvent(<String, dynamic>{'eventId': id});
    } catch (e) {
      _debug.log('ga screenView failed: $e');
    }
  }

  @override
  Future<void> event(
    String name, {
    Map<String, Object?>? params,
    double? value,
  }) async {
    if (!isReady) return;
    final id = EventNaming.gaDesignIdFromEventName(name);
    _debug.log('ga event id=$id value=$value');
    try {
      if (value == null) {
        GameAnalytics.addDesignEvent(<String, dynamic>{'eventId': id});
      } else {
        GameAnalytics.addDesignEvent(<String, dynamic>{
          'eventId': id,
          'value': value,
        });
      }
    } catch (e) {
      _debug.log('ga event failed: $e');
    }
  }

  @override
  Future<void> adEvent({
    required String action,
    required String adType,
    required String adSdkName,
    required String adPlacement,
    Map<String, Object?>? params,
  }) async {
    if (!isReady) return;

    final int? gaAction = _mapAdAction(action);
    final int? gaType = _mapAdType(adType);
    if (gaAction == null || gaType == null) {
      // Fallback to design event to keep GA usable even if mapping is incomplete.
      await event(
        'ad_${adSdkName}_$action',
        params: <String, Object?>{
          'ad_type': adType,
          'ad_placement': adPlacement,
        },
      );
      return;
    }
    _debug.log('ga adEvent action=$gaAction type=$gaType sdk=$adSdkName placement=$adPlacement');
    try {
      GameAnalytics.addAdEvent(<String, dynamic>{
        'adAction': gaAction,
        'adType': gaType,
        'adSdkName': adSdkName,
        'adPlacement': adPlacement,
      });
    } catch (e) {
      _debug.log('ga adEvent failed: $e');
    }
  }

  @override
  Future<void> error({
    required String message,
    String? severity,
    Map<String, Object?>? params,
  }) async {
    if (!isReady) return;
    final int gaSeverity = _mapErrorSeverity(severity);
    _debug.log('ga error severity=$gaSeverity msg=$message');
    try {
      GameAnalytics.addErrorEvent(<String, dynamic>{
        'severity': gaSeverity,
        'message': message,
      });
    } catch (e) {
      _debug.log('ga error failed: $e');
    }
  }

  int? _mapAdAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'loaded':
        return GAAdAction.Loaded;
      case 'shown':
      case 'show':
        return GAAdAction.Show;
      case 'impression':
        return GAAdAction.Show;
      case 'clicked':
      case 'click':
        return GAAdAction.Clicked;
      case 'dismissed':
      case 'closed':
        return GAAdAction.Show;
      case 'failed_load':
      case 'failed_to_load':
        return GAAdAction.FailedShow;
      case 'failed_show':
      case 'failed_to_show':
        return GAAdAction.FailedShow;
      case 'timeout':
        return GAAdAction.FailedShow;
      case 'rewarded':
      case 'earned':
        return GAAdAction.RewardReceived;
    }
    return null;
  }

  int? _mapAdType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'rewarded':
      case 'rewardedvideo':
      case 'rewarded_video':
        return GAAdType.RewardedVideo;
      case 'interstitial':
        return GAAdType.Interstitial;
      case 'banner':
        return GAAdType.Banner;
      case 'video':
        return GAAdType.Video;
    }
    return null;
  }

  int _mapErrorSeverity(String? severity) {
    switch (severity?.trim().toLowerCase()) {
      case 'critical':
        return GAErrorSeverity.Critical;
      case 'error':
        return GAErrorSeverity.Error;
      case 'warning':
        return GAErrorSeverity.Warning;
      case 'info':
        return GAErrorSeverity.Info;
      default:
        return GAErrorSeverity.Info;
    }
  }
}

