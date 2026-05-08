abstract class AppAnalytics {
  Future<void> init();

  Future<void> screenView({
    required String screenName,
    String? screenClass,
    Map<String, Object?>? params,
  });

  Future<void> event(
    String name, {
    Map<String, Object?>? params,
    double? value,
  });

  Future<void> adEvent({
    required String action,
    required String adType,
    required String adSdkName,
    required String adPlacement,
    Map<String, Object?>? params,
  });

  Future<void> error({
    required String message,
    String? severity,
    Map<String, Object?>? params,
  });
}

