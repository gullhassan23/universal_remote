import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smartapp/utils/userId.dart';

/// Matches [AndroidManifest] `com.google.firebase.messaging.default_notification_channel_id`.
const String _androidFcmChannelId = 'smartapp_fcm';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Background handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][BG] messageId=${message.messageId} data=${message.data}');
}

/// Retries FCM `getToken()` so APNs can become ready on iOS.
///
/// A direct `getToken()` during IAP or shortly after launch often throws
/// `firebase_messaging/apns-token-not-set` — use this instead.
Future<String?> getFcmTokenWithRetry(
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
    final token = await getFcmTokenWithRetry();
    if (token == null || token.isEmpty) {
      debugPrint(
          '[FCM] No token available after retries (e.g. APNS not set or permission denied)');
      return;
    }
    debugPrint('[FCM] FCM token (app start): $token');
    await FirebaseFirestore.instance.collection('Users').doc(userId).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
    debugPrint('[FCM] Token saved for user $userId');
  } catch (e) {
    debugPrint('[FCM] Failed to update token: $e');
  }
}

Future<void> _ensureAndroidNotificationChannel() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  const channel = AndroidNotificationChannel(
    _androidFcmChannelId,
    'Push notifications',
    description: 'Firebase Cloud Messaging',
    importance: Importance.high,
  );

  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(channel);
}

Future<void> _initializeLocalNotifications() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  await _ensureAndroidNotificationChannel();
}

Future<void> _showForegroundAndroidNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  final id = Object.hash(message.messageId, message.sentTime?.millisecondsSinceEpoch);

  await _localNotifications.show(
    id,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidFcmChannelId,
        'Push notifications',
        channelDescription: 'Firebase Cloud Messaging',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

Future<void> initializeFcmAndUploadToken() async {
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Ensure FCM auto-init is enabled.
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // iOS: allow notification display while app is in foreground.
    // APNs: also upload an APNs Auth Key in Firebase Console → Project settings → Cloud Messaging.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _initializeLocalNotifications();

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '[FCM][INITIAL] messageId=${initialMessage.messageId} '
        'data=${initialMessage.data}',
      );
    }

    // Log all incoming messages (foreground). Android: show tray notification (FCM does not by default).
    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint(
        '[FCM][FG] messageId=${message.messageId} '
        'title=${message.notification?.title} body=${message.notification?.body} data=${message.data}',
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _showForegroundAndroidNotification(message);
      }
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
