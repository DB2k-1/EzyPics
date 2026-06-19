import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'streak_service.dart';

class NotificationService {
  static const int _notifId = 0;
  static const String _keyMode = 'notif_mode';
  static const String _keySetHour = 'notif_set_hour';
  static const String _keySetMinute = 'notif_set_minute';
  static const String _keyRangeStartHour = 'notif_range_start_hour';
  static const String _keyRangeStartMinute = 'notif_range_start_minute';
  static const String _keyRangeEndHour = 'notif_range_end_hour';
  static const String _keyRangeEndMinute = 'notif_range_end_minute';
  static const String _keyLastRandomDate = 'notif_last_random_date';

  static const String _title = 'Time to tidy up 📸';
  static const String _body = 'Review your photos and free up some space!';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    // Set the local timezone so scheduled times match the device clock.
    final String tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) => scheduleReminder(),
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
    );
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleReminder() async {
    final mode = await getMode();

    // Turn off: cancel any pending notification and stop.
    if (mode == 'off') {
      await cancelReminder();
      return;
    }

    // If the user has already completed a review today, no reminder needed.
    final usageDates = await StreakService.getUsageDates();
    final todayIso = StreakService.isoDate(DateTime.now());
    if (usageDates.contains(todayIso)) {
      await cancelReminder();
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'ezypics_reminders',
      'Daily Reminders',
      channelDescription: 'Daily photo review reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails(badgeNumber: 1);
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final now = tz.TZDateTime.now(tz.local);

    if (mode == 'setTime') {
      final prefs = await SharedPreferences.getInstance();
      final hour = prefs.getInt(_keySetHour) ?? 9;
      final minute = prefs.getInt(_keySetMinute) ?? 0;

      // Cancel then reschedule at the (possibly updated) set time.
      await cancelReminder();
      await _plugin.zonedSchedule(
        _notifId,
        _title,
        _body,
        _nextInstanceOfTime(now, hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // random or timeRange: pick a time once per day and leave it alone.
      // IMPORTANT: check the date BEFORE cancelling — the previous bug was
      // cancelling first and then returning early, killing today's notification.
      final prefs = await SharedPreferences.getInstance();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (prefs.getString(_keyLastRandomDate) == todayStr) return;

      int startHour = 8;
      int startMinute = 0;
      int endHour = 21;
      int endMinute = 0;

      if (mode == 'timeRange') {
        startHour = prefs.getInt(_keyRangeStartHour) ?? 8;
        startMinute = prefs.getInt(_keyRangeStartMinute) ?? 0;
        endHour = prefs.getInt(_keyRangeEndHour) ?? 21;
        endMinute = prefs.getInt(_keyRangeEndMinute) ?? 0;
      }

      final startMinutes = startHour * 60 + startMinute;
      final endMinutes = endHour * 60 + endMinute;
      final rangeMinutes =
          (endMinutes > startMinutes) ? endMinutes - startMinutes : 60;
      final randomOffset = Random().nextInt(rangeMinutes);
      final pickedMinutes = startMinutes + randomOffset;
      final pickedHour = pickedMinutes ~/ 60;
      final pickedMinute = pickedMinutes % 60;

      await cancelReminder();
      await _plugin.zonedSchedule(
        _notifId,
        _title,
        _body,
        _nextInstanceOfTime(now, pickedHour, pickedMinute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      await prefs.setString(_keyLastRandomDate, todayStr);
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(
      tz.TZDateTime now, int hour, int minute) {
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> cancelReminder() async {
    await _plugin.cancel(_notifId);
  }

  static Future<String> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMode) ?? 'random';
  }

  static Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode);
  }

  static Future<TimeOfDay> getSetTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_keySetHour) ?? 9,
      minute: prefs.getInt(_keySetMinute) ?? 0,
    );
  }

  static Future<void> setSetTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySetHour, hour);
    await prefs.setInt(_keySetMinute, minute);
  }

  static Future<TimeOfDay> getRangeStart() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_keyRangeStartHour) ?? 8,
      minute: prefs.getInt(_keyRangeStartMinute) ?? 0,
    );
  }

  static Future<void> setRangeStart(int h, int m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRangeStartHour, h);
    await prefs.setInt(_keyRangeStartMinute, m);
  }

  static Future<TimeOfDay> getRangeEnd() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_keyRangeEndHour) ?? 21,
      minute: prefs.getInt(_keyRangeEndMinute) ?? 0,
    );
  }

  static Future<void> setRangeEnd(int h, int m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRangeEndHour, h);
    await prefs.setInt(_keyRangeEndMinute, m);
  }
}

// Top-level function required for Android background notification response.
@pragma('vm:entry-point')
void _onBackgroundNotification(NotificationResponse _) {
  NotificationService.scheduleReminder();
}
