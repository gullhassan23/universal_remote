import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_params.dart';
import 'app_analytics.dart';
import 'analytics_debug.dart';
import 'event_naming.dart';

class FirebaseAnalyticsBackend implements AppAnalytics {
  FirebaseAnalyticsBackend({
    required FirebaseAnalytics analytics,
    required AnalyticsDebug debug,
  })  : _analytics = analytics,
        _debug = debug;

  final FirebaseAnalytics _analytics;
  final AnalyticsDebug _debug;

  @override
  Future<void> init() async {}

  @override
  Future<void> screenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?>? params,
  }) async {
    // Keep the existing behavior: emit a custom screen_* event.
    final eventName = 'screen_${EventNaming.sanitizeToken(screenName).toLowerCase()}';
    _debug.log('firebase screenView name=$screenName class=$screenClass -> $eventName');
    await event(
      eventName,
      params: params,
    );
  }

  @override
  Future<void> event(
    String name, {
    Map<String, Object?>? params,
    double? value,
  }) async {
    final normalizedName = EventNaming.normalizeFirebaseEventName(name);
    final sanitizedParams = sanitizeEventParameters(params);
    _debug.log('firebase event=$normalizedName params=${sanitizedParams?.keys.toList()}');
    await _analytics.logEvent(name: normalizedName, parameters: sanitizedParams);
  }

  @override
  Future<void> adEvent({
    required String action,
    required String adType,
    required String adSdkName,
    required String adPlacement,
    Map<String, Object?>? params,
  }) async {
    await event(
      'ad_${EventNaming.sanitizeToken(adSdkName)}_${EventNaming.sanitizeToken(action)}',
      params: <String, Object?>{
        'ad_action': action,
        'ad_type': adType,
        'ad_sdk': adSdkName,
        'ad_placement': adPlacement,
        ...?params,
      },
    );
  }

  @override
  Future<void> error({
    required String message,
    String? severity,
    Map<String, Object?>? params,
  }) async {
    await event(
      'app_error',
      params: <String, Object?>{
        'message': message,
        'severity': severity,
        ...?params,
      },
    );
  }
}

