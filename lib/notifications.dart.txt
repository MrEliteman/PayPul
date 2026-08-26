import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Обёртка над локальными уведомлениями.
/// Два разных канала: "приближение к лимиту" (мягкое предупреждение на 80%)
/// и "лимит превышен" (более заметное, со своим звуком и вибрацией).
class AppNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> showLimitWarning({
    required String title,
    required String body,
  }) async {
    await _show(
      id: 1,
      title: title,
      body: body,
      channelId: 'limit_warning',
      channelName: 'Приближение к лимиту',
      vibrationPattern: Int64List.fromList([0, 150, 100, 150]),
    );
  }

  static Future<void> showLimitExceeded({
    required String title,
    required String body,
  }) async {
    await _show(
      id: 2,
      title: title,
      body: body,
      channelId: 'limit_exceeded',
      channelName: 'Превышение лимита',
      vibrationPattern: Int64List.fromList([0, 250, 150, 250, 150, 250]),
    );
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required Int64List vibrationPattern,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('limit_alert'),
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }
}
