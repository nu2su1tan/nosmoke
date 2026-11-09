import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder.dart';

abstract class NotificationService {
  /// Запрашивает разрешение у пользователя. true — разрешено.
  Future<bool> requestPermission();

  /// Заменяет все запланированные напоминания переданными.
  Future<void> schedule(List<Reminder> reminders);

  Future<void> cancelAll();
}

/// Реализация на flutter_local_notifications. На неподдерживаемых
/// платформах (web, desktop кроме macOS) тихо ничего не делает.
class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _init;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Повторяем инициализацию, если прошлая попытка не удалась.
  Future<bool> _ensureInit() async {
    final ok = await (_init ??= _initialize());
    if (!ok) _init = null;
    return ok;
  }

  Future<bool> _initialize() async {
    if (!_supported) return false;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _ensureInit()) return false;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestNotificationsPermission() ??
              false;
        case TargetPlatform.iOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
        case TargetPlatform.macOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Notification permission failed: $e');
      return false;
    }
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    if (!await _ensureInit()) return;
    try {
      await _plugin.cancelAll();
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: _nextInstance(r.hour, r.minute, r.weekday),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_support',
              'Ежедневная поддержка',
              channelDescription: 'Напоминания и поддержка в трудные моменты',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: r.weekday == null
              ? DateTimeComponents.time
              : DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (e) {
      debugPrint('Scheduling notifications failed: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!await _ensureInit()) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Cancel notifications failed: $e');
    }
  }

  tz.TZDateTime _nextInstance(int hour, int minute, [int? weekday]) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!d.isAfter(now)) d = d.add(const Duration(days: 1));
    if (weekday != null) {
      while (d.weekday != weekday) {
        d = d.add(const Duration(days: 1));
      }
    }
    return d;
  }
}
