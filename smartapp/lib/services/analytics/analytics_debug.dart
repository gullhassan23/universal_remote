import 'package:flutter/foundation.dart';

class AnalyticsDebug {
  AnalyticsDebug({required this.enabled});

  final bool enabled;

  void log(String message) {
    if (!enabled) return;
    debugPrint('[ANALYTICS] $message');
  }
}

