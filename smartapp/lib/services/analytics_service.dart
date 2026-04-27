import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';

class AnalyticsService extends GetxService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  String? _lastScreenKey;
  static const Map<String, String> _screenKeyToName = <String, String>{
    'Get_Started': 'GetStarted',
    'Remote_View': 'Remote_Screen',
    'Streaming_App_Screen': 'StreamingAppsScreen',
    'CastScreen': 'CastScreen',
    'SettingsScreen': 'SettingsScreen',
    'bottom_nav': 'BottomNav',
  };

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

    // Also emit a custom per-screen event so screens appear
    // in Firebase "Event count by event name".
    final screenEventName = 'screen_${_sanitizeToken(screenName).toLowerCase()}';
    await logEvent(
      screenEventName,
      params: _baseParams(screenName: screenName),
    );
  }

  Future<void> trackScreenByKey(String screenKey) async {
    final mapped = _screenKeyToName[screenKey];
    if (mapped == null) return;
    await logScreen(screenName: mapped, screenClass: mapped);
  }

  Future<void> trackClick(
    String buttonName, {
    String? screenName,
  }) async {
    final sanitizedButton = _sanitizeToken(buttonName);
    if (sanitizedButton.isEmpty) return;
    await logEvent(
      'click_$sanitizedButton',
      params: _baseParams(
        screenName: screenName,
        buttonName: sanitizedButton,
      ),
    );
  }

  Future<void> trackTab(
    String tabName, {
    String? screenName,
  }) async {
    final sanitizedTab = _sanitizeToken(tabName);
    if (sanitizedTab.isEmpty) return;
    await logEvent(
      'tab_$sanitizedTab',
      params: _baseParams(screenName: screenName),
    );
  }

  Future<void> trackBottomNav(
    String destination, {
    String? from,
  }) async {
    final sanitizedDestination = _sanitizeToken(destination);
    if (sanitizedDestination.isEmpty) return;
    await logEvent(
      'nav_$sanitizedDestination',
      params: _baseParams(
        screenName: _screenKeyToName['bottom_nav'],
        extra: <String, Object?>{
          'from': from == null ? null : _sanitizeToken(from),
          'to': sanitizedDestination,
        },
      ),
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

    if (trimmed == '/' || trimmed == '/get-started') {
      final screenName = _screenKeyToName['Get_Started']!;
      return (screenName, screenName);
    }
    if (trimmed == '/instructions') {
      return ('InstructionOnboardingScreen', 'InstructionOnboardingScreen');
    }
    if (trimmed == '/home') {
      final screenName = _screenKeyToName['bottom_nav']!;
      return (screenName, screenName);
    }

    final cleaned = trimmed.split('?').first;
    final segments = cleaned.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final leaf = segments.last;
    return (leaf, leaf);
  }

  Map<String, Object?> _baseParams({
    String? screenName,
    String? buttonName,
    Map<String, Object?>? extra,
  }) {
    return <String, Object?>{
      'screen_name': screenName,
      'button_name': buttonName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...?extra,
    };
  }

  String _sanitizeToken(String value) {
    final compact = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return compact;
  }
}
