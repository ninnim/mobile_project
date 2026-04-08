import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/dio_client.dart';

/// Handles Firebase Cloud Messaging for background/killed-app push notifications.
/// Supports both Android and iOS.
/// Call [FcmService.init()] after Firebase.initializeApp() and after the user logs in.

const _kChatChannelId = 'chat_channel';
const _kChatChannelName = 'Chat Messages';

/// Must be a top-level function — called by FCM when app is in background/terminated.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // On Android: FCM shows the system notification automatically from the
  // notification payload. No local plugin call needed here.
  // On iOS: handled by APNs + FlutterLocalNotificationsPlugin delegate.
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Must be registered before any other FCM call.
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Request permission (required on iOS 10+, Android 13+).
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    if (Platform.isAndroid) {
      // Create the high-priority channel that FCM will use on Android 8+.
      const channel = AndroidNotificationChannel(
        _kChatChannelId,
        _kChatChannelName,
        description: 'New chat messages',
        importance: Importance.high,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    if (Platform.isIOS) {
      // Tell iOS to show alert/badge/sound even when app is in foreground.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Initialize flutter_local_notifications for foreground display on Android.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false, // already requested above via FCM
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(initSettings);

    // Show a local notification when a message arrives while the app is OPEN.
    // iOS handles this via setForegroundNotificationPresentationOptions above.
    // Android needs an explicit local notification show.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;

      if (Platform.isAndroid) {
        _localNotifications.show(
          message.messageId.hashCode,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _kChatChannelId,
              _kChatChannelName,
              channelDescription: 'New chat messages',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
            ),
          ),
        );
      }
      // iOS: foreground notification is shown automatically by APNs
      // because of setForegroundNotificationPresentationOptions above.
    });

    // Get token and register with our backend.
    // On iOS, getToken() returns the APNs token wrapped in an FCM token.
    final token = await _messaging.getToken();
    if (token != null) await _registerToken(token);

    // Re-register whenever FCM rotates the token.
    _messaging.onTokenRefresh.listen(_registerToken);
  }

  static Future<void> _registerToken(String token) async {
    try {
      await dioClient.put('/auth/fcm-token', data: {'token': token});
    } catch (_) {
      // Non-critical — will retry on next app launch.
    }
  }
}
