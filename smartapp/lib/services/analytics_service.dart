import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'analytics/app_analytics.dart';
import 'analytics/analytics_debug.dart';
import 'analytics/analytics_dedupe.dart';
import 'analytics/composite_analytics.dart';
import 'analytics/firebase_analytics_backend.dart';
import 'analytics/game_analytics_backend.dart';

class AnalyticsService extends GetxService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  String? _lastScreenKey;
  int _lastScreenAtMs = 0;
  final AnalyticsDedupe _eventDedupe = AnalyticsDedupe(minIntervalMs: 250);
  AnalyticsDebug _debug = AnalyticsDebug(enabled: false);
  AppAnalytics? _fanout;
  static const Map<String, String> _screenKeyToName = <String, String>{
    'Get_Started': 'GetStarted',
    'Remote_View': 'Remote_Screen',
    'Streaming_App_Screen': 'StreamingAppsScreen',
    'CastScreen': 'CastScreen',
    'SettingsScreen': 'SettingsScreen',
    'bottom_nav': 'BottomNav',
  };

  FirebaseAnalytics get analytics => _analytics;

  Future<void> initialize() async {
    final debugEnabled =
        (dotenv.env['ANALYTICS_DEBUG'] ?? '').trim().toLowerCase() == 'true';
    _debug = AnalyticsDebug(enabled: debugEnabled);

    final pkg = await PackageInfo.fromPlatform();
    final build = '${pkg.version}+${pkg.buildNumber}';

    final gameKey = (dotenv.env['GAME_KEY'] ?? '').trim();
    final secretKey = (dotenv.env['SECRET_KEY_ANDROID'] ?? '').trim();

    final targets = <AppAnalytics>[
      FirebaseAnalyticsBackend(
        analytics: _analytics,
        debug: _debug,
      ),
      GameAnalyticsBackend(
        gameKey: gameKey,
        secretKey: secretKey,
        build: build,
        debug: _debug,
        enabled: true,
      ),
    ];

    _fanout = CompositeAnalytics(targets);
    await _fanout!.init();
    _debug.log(
        'initialized build=$build gaKeysPresent=${gameKey.isNotEmpty && secretKey.isNotEmpty}');
  }

  Future<void> logScreen({
    required String screenName,
    required String screenClass,
  }) async {
    final key = '$screenName|$screenClass';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastScreenKey == key && (nowMs - _lastScreenAtMs) < 800) {
      return;
    }
    _lastScreenKey = key;
    _lastScreenAtMs = nowMs;

    // Emit per-screen custom event so screens appear directly in
    // Firebase "Event count by event name" list.
    final screenEventName =
        'screen_${_sanitizeToken(screenName).toLowerCase()}';
    await logEvent(
      screenEventName,
      params: _baseParams(screenName: screenName),
    );

    final fanout = _fanout;
    if (fanout != null) {
      await fanout.screenView(
        screenName: screenName,
        screenClass: screenClass,
        params: _baseParams(screenName: screenName),
      );
    }
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dropKey =
        '${_normalizeEventName(name)}|${params?['screen_name'] ?? ''}|${params?['button_name'] ?? ''}';
    if (_eventDedupe.shouldDrop(dropKey, nowMs)) {
      _debug.log('dedupe drop event=$name');
      return;
    }

    final normalizedName = _normalizeEventName(name);
    final sanitizedParams = params == null
        ? null
        : Map<String, Object>.fromEntries(
            params.entries.where((entry) => entry.value != null).map(
                  (entry) => MapEntry(entry.key, entry.value as Object),
                ),
          );

    await _analytics.logEvent(
        name: normalizedName, parameters: sanitizedParams);

    final fanout = _fanout;
    if (fanout != null) {
      unawaited(
        fanout.event(
          normalizedName,
          params: sanitizedParams,
        ),
      );
    } else if (kDebugMode) {
      // Useful during early startup if initialize() wasn't called yet.
      _debug.log('fanout not ready: event=$normalizedName');
    }
  }

  Future<void> logAdEvent({
    required String action,
    required String adType,
    required String adSdkName,
    required String adPlacement,
    Map<String, Object?>? params,
  }) async {
    final base = <String, Object?>{
      'ad_action': action,
      'ad_type': adType,
      'ad_sdk': adSdkName,
      'ad_placement': adPlacement,
      ...?params,
    };
    await logEvent(
      'ad_${_sanitizeToken(adSdkName)}_${_sanitizeToken(action)}',
      params: base,
    );

    final fanout = _fanout;
    if (fanout != null) {
      unawaited(
        fanout.adEvent(
          action: action,
          adType: adType,
          adSdkName: adSdkName,
          adPlacement: adPlacement,
          params: base,
        ),
      );
    }
  }

  Future<void> logError(
    String message, {
    String severity = 'error',
    Map<String, Object?>? params,
  }) async {
    await logEvent(
      'app_error',
      params: <String, Object?>{
        'message': message,
        'severity': severity,
        ...?params,
      },
    );
    final fanout = _fanout;
    if (fanout != null) {
      unawaited(
        fanout.error(
          message: message,
          severity: severity,
          params: params,
        ),
      );
    }
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
    if (trimmed == '/premium' ||
        trimmed == '/pro' ||
        trimmed.contains('premium')) {
      return ('PremiumScreen', 'PremiumScreen');
    }

    final cleaned = trimmed.split('?').first;
    final segments =
        cleaned.split('/').where((part) => part.isNotEmpty).toList();
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

  String _normalizeEventName(String value) {
    final token = _sanitizeToken(value).toLowerCase();
    var normalized = token;
    if (normalized.isEmpty) {
      normalized = 'app_event';
    }
    if (RegExp(r'^[0-9]').hasMatch(normalized)) {
      normalized = 'e_$normalized';
    }
    if (normalized.startsWith('firebase_') ||
        normalized.startsWith('google_') ||
        normalized.startsWith('ga_')) {
      normalized = 'app_$normalized';
    }
    if (normalized.length > 40) {
      normalized = normalized.substring(0, 40).replaceAll(RegExp(r'_+$'), '');
      if (normalized.isEmpty) {
        normalized = 'app_event';
      }
    }
    return normalized;
  }
}
