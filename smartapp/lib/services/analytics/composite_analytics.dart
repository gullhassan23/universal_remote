import 'app_analytics.dart';

class CompositeAnalytics implements AppAnalytics {
  CompositeAnalytics(this._targets);

  final List<AppAnalytics> _targets;

  @override
  Future<void> init() async {
    for (final t in _targets) {
      await t.init();
    }
  }

  @override
  Future<void> screenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?>? params,
  }) async {
    for (final t in _targets) {
      await t.screenView(
        screenName: screenName,
        screenClass: screenClass,
        params: params,
      );
    }
  }

  @override
  Future<void> event(
    String name, {
    Map<String, Object?>? params,
    double? value,
  }) async {
    for (final t in _targets) {
      await t.event(name, params: params, value: value);
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
    for (final t in _targets) {
      await t.adEvent(
        action: action,
        adType: adType,
        adSdkName: adSdkName,
        adPlacement: adPlacement,
        params: params,
      );
    }
  }

  @override
  Future<void> error({
    required String message,
    String? severity,
    Map<String, Object?>? params,
  }) async {
    for (final t in _targets) {
      await t.error(message: message, severity: severity, params: params);
    }
  }
}

