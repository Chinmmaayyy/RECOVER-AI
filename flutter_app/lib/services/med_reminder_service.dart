import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Medicine Reminder Service — schedules local push notifications
/// for each medication at the prescribed time.
class MedReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize the notification plugin — call once in main.dart
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request Android 13+ notification permission
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Could navigate to medication screen — for now just opens the app
  }

  /// Schedule daily reminders for a list of medications
  /// Each med should have: name, dosage, schedule_time (e.g. "8AM", "9PM")
  static Future<void> scheduleReminders(List<Map<String, dynamic>> medications) async {
    if (!_initialized) await init();

    // Cancel all existing reminders first
    await _notifications.cancelAll();

    for (int i = 0; i < medications.length; i++) {
      final med = medications[i];
      final name = med['name'] ?? med['medication'] ?? 'Medicine';
      final dosage = med['dosage'] ?? '';
      final timeStr = med['schedule_time'] ?? '';

      final hour = _parseHour(timeStr);
      if (hour == null) continue;

      // Schedule daily repeating notification
      await _notifications.zonedSchedule(
        100 + i, // unique ID per medication
        'Time for your medicine',
        '$name ${dosage.isNotEmpty ? "($dosage)" : ""} — tap to mark as taken',
        _nextInstanceOfTime(hour, 0),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'med_reminders',
            'Medication Reminders',
            channelDescription: 'Daily medication reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(
              '$name ${dosage.isNotEmpty ? "($dosage)" : ""}\nPlease take your medicine and mark it in the app.',
              contentTitle: 'Time for your medicine',
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      );
    }
  }

  /// Schedule a one-time reminder after X minutes (for "remind me later")
  static Future<void> remindLater({
    required String medName,
    int minutesLater = 15,
  }) async {
    if (!_initialized) await init();

    await _notifications.zonedSchedule(
      999, // special ID for snooze
      'Medicine Reminder',
      "Don't forget: $medName — take it now!",
      tz.TZDateTime.now(tz.local).add(Duration(minutes: minutesLater)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'med_reminders',
          'Medication Reminders',
          channelDescription: 'Medication snooze reminder',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Show an immediate notification (for testing or alerts)
  static Future<void> showNow({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_reminders',
          'Medication Reminders',
          channelDescription: 'Medication alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Cancel all scheduled reminders
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Parse time string like "8AM", "8 AM", "9PM", "21:00" to hour (0-23)
  static int? _parseHour(String timeStr) {
    if (timeStr.isEmpty) return null;
    final t = timeStr.toUpperCase().replaceAll(' ', '');

    // Handle "8AM", "9PM" format
    final amPmMatch = RegExp(r'(\d{1,2})(AM|PM)').firstMatch(t);
    if (amPmMatch != null) {
      int hour = int.parse(amPmMatch.group(1)!);
      final period = amPmMatch.group(2)!;
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour;
    }

    // Handle "21:00" format
    final colonMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(t);
    if (colonMatch != null) {
      return int.parse(colonMatch.group(1)!);
    }

    return null;
  }

  /// Get next instance of a given time (today if not passed, tomorrow if passed)
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
