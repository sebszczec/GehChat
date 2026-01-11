import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _notificationsEnabled = true;
  bool _isShowingPersistentNotification = false;
  Function(String?, bool)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _initialized = true;

      // Request permissions for iOS
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // Request permissions for Android 13+
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
      _initialized = false;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (onNotificationTap != null) {
      if (response.payload != null) {
        try {
          final data = jsonDecode(response.payload!);
          final username = data['username'] as String?;
          final isPrivate = data['isPrivate'] as bool? ?? false;
          onNotificationTap!(username, isPrivate);
        } catch (e) {
          debugPrint('Failed to parse notification payload: $e');
        }
      } else {
        // Persistent notification tapped (no payload) - go to main chat
        onNotificationTap!(null, false);
      }
    }
  }

  Future<void> showMessageNotification({
    required String sender,
    required String message,
    required bool isPrivate,
  }) async {
    if (!_notificationsEnabled || !_initialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'irc_messages',
        'IRC Messages',
        channelDescription: 'Notifications for IRC chat messages',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = isPrivate ? 'Private message from $sender' : sender;
      final body = message.length > 100
          ? '${message.substring(0, 97)}...'
          : message;

      final payload = jsonEncode({
        'username': isPrivate ? sender : null,
        'isPrivate': isPrivate,
      });

      await _notificationsPlugin.show(
        sender
            .hashCode, // Use sender as ID so multiple messages from same user update
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      // Ignore notification errors - don't crash the app
      debugPrint('Failed to show notification: $e');
    }
  }

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  Future<void> showPersistentNotification() async {
    if (_isShowingPersistentNotification || !_initialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'irc_connection',
        'IRC Connection',
        channelDescription: 'Shows connection status',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        category: AndroidNotificationCategory.service,
        visibility: NotificationVisibility.public,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        0, // Fixed ID for persistent notification
        'GehChat',
        'Connected to GehChat',
        notificationDetails,
      );

      _isShowingPersistentNotification = true;
    } catch (e) {
      debugPrint('Failed to show persistent notification: $e');
    }
  }

  Future<void> hidePersistentNotification() async {
    if (!_isShowingPersistentNotification) return;

    try {
      await _notificationsPlugin.cancel(0);
      _isShowingPersistentNotification = false;
    } catch (e) {
      debugPrint('Failed to hide persistent notification: $e');
    }
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
    _isShowingPersistentNotification = false;
  }
}
