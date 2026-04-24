import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';

class AnalyticsService extends GetxService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  String? _lastScreenKey;

  FirebaseAnalytics get analytics => _analytics;

  Future<void> logScreen({
    required String screenName,
    required String screenClass,
  }) async {
    final key = '$screenName|$screenClass';
    if (_lastScreenKey == key) {
      return;
    }
    _lastScreenKey = key;

    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? params,
  }) async {
    final sanitizedParams = params == null
        ? null
        : Map<String, Object>.fromEntries(
            params.entries.where((entry) => entry.value != null).map(
                  (entry) => MapEntry(entry.key, entry.value as Object),
                ),
          );

    await _analytics.logEvent(name: name, parameters: sanitizedParams);
  }

  void trackRouteFromGetX(Routing? routing) {
    final rawRoute = routing?.current ?? Get.currentRoute;
    if (rawRoute.isEmpty) return;

    final normalized = _normalizeRoute(rawRoute);
    if (normalized == null) return;

    final String screenClass = normalized.$1;
    final String screenName = normalized.$2;
    logScreen(screenName: screenName, screenClass: screenClass);
  }

  (String, String)? _normalizeRoute(String route) {
    final trimmed = route.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed == '/') return ('GetStarted', 'GetStarted');
    if (trimmed == '/instructions') {
      return ('InstructionOnboardingScreen', 'InstructionOnboardingScreen');
    }
    if (trimmed == '/home') return ('BottomNav', 'BottomNav');

    final cleaned = trimmed.split('?').first;
    final segments = cleaned.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final leaf = segments.last;
    return (leaf, leaf);
  }
}
