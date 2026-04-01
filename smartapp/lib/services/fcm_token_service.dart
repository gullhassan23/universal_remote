import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:smartapp/utils/userId.dart';

/// Background handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][BG] messageId=${message.messageId} data=${message.data}');
}

/// Retries getToken() so APNS can become ready on iOS (e.g. after permission).
Future<String?> _getFcmTokenWithRetry(
    {int maxAttempts = 5, Duration delay = const Duration(seconds: 2)}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[FCM] getToken attempt $attempt failed: $e');
      if (attempt < maxAttempts) await Future<void>.delayed(delay);
    }
  }
  return null;
}

Future<void> updateFcmTokenInFirestore() async {
  try {
    final userId = await getOrCreateUserId();
    final token = await _getFcmTokenWithRetry();
    if (token == null || token.isEmpty) {
      debugPrint(
          '[FCM] No token available after retries (e.g. APNS not set or permission denied)');
      return;
    }
    await FirebaseFirestore.instance.collection('Users').doc(userId).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
    debugPrint('[FCM] Token saved for user $userId');
  } catch (e) {
    debugPrint('[FCM] Failed to update token: $e');
  }
}

Future<void> initializeFcmAndUploadToken() async {
  try {
    // Ensure FCM auto-init is enabled.
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // iOS: allow notification display while app is in foreground.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler early.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Log all incoming messages (foreground).
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FCM][FG] messageId=${message.messageId} '
        'title=${message.notification?.title} body=${message.notification?.body} data=${message.data}',
      );
    });

    // App opened from notification tap.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
          '[FCM][OPEN] messageId=${message.messageId} data=${message.data}');
    });

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied');
      return;
    }
    await updateFcmTokenInFirestore();

    // Keep Firestore token in sync if it rotates.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        if (newToken.isEmpty) return;
        final userId = await getOrCreateUserId();
        await FirebaseFirestore.instance.collection('Users').doc(userId).set(
          {'fcmToken': newToken},
          SetOptions(merge: true),
        );
        debugPrint('[FCM] Token refreshed and saved for user $userId');
      } catch (e) {
        debugPrint('[FCM] Failed to persist refreshed token: $e');
      }
    });
  } catch (e) {
    debugPrint('[FCM] initializeFcmAndUploadToken error: $e');
  }
}
