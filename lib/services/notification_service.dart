import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dream_journal/models/settings.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
// Conditional web helpers: real Notification API on web, no-op stub on
// native — importing package:web directly here breaks VM tests/native builds.
import 'web_notifications_stub.dart'
    if (dart.library.js_interop) 'web_notifications.dart' as webnotif;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Repeating web timer for the daily reminder (browser Notification API).
  /// Only meaningful on web — native uses the plugin's exact alarms. If the
  /// tab is closed the browser stops the timer; within the open tab the
  /// reminder fires at the wall-clock time every day.
  static Timer? _webTimer;

  NotificationService();

  static FlutterLocalNotificationsPlugin get plugin => _notifications;

  /// Platform channel (Android MainActivity) that returns the device's real
  /// IANA timezone id, e.g. "Europe/Moscow".
  static const MethodChannel _tzChannel = MethodChannel('ataraxy/timezone');

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    // Set local timezone so scheduled notifications fire at the correct
    // wall-clock time. NOTE: on many MIUI/Redmi builds
    // `DateTime.now().timeZoneName` returns "UTC" even when the device is
    // UTC+3 — relying on tz.local there made reminders fire 3 hours late.
    await _setLocalTimezone();

    // flutter_local_notifications has no web implementation and `dart:io`
    // Platform is unavailable in the browser — skip all plugin work on web.
    if (kIsWeb) {
      debugPrint('[Notif] Web platform — notifications are not supported, skipping init');
      return;
    }

    // Small-icon for the status bar MUST be a white monochrome drawable —
    // a colorful launcher icon renders as a solid blob / blank square on
    // Android (incl. MIUI). ic_notification is our custom white vector.
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
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

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createChannels();

    // Request ALL required permissions at startup so the FIRST
    // scheduleDaily() does not fall back to inexactAllowWhileIdle
    // (which Doze-mode-batches to ~15-minute windows and can be hours late).
    await requestAllPermissions();
  }

  /// Resolves the device's real IANA timezone and sets tz.local accordingly.
  /// Priority: platform channel (Android) > DateTime.timeZoneName (iOS/desktop)
  /// > UTC-offset matching. Falls back to UTC only if everything fails.
  static Future<void> _setLocalTimezone() async {
    try {
      if (Platform.isAndroid) {
        final id = await _tzChannel.invokeMethod<String>('getTimeZone');
        if (id != null && id.isNotEmpty) {
          final loc = _tryGetLocation(id);
          if (loc != null) {
            tz.setLocalLocation(loc);
            debugPrint('[Notif] Local timezone (platform) set to: ${loc.name}');
            return;
          }
        }
        debugPrint('[Notif] Platform timezone "$id" unknown — falling back');
      } else {
        // iOS / desktop: Dart's timeZoneName is usually already an IANA name.
        final name = DateTime.now().timeZoneName;
        final loc = _tryGetLocation(name);
        if (loc != null) {
          tz.setLocalLocation(loc);
          debugPrint('[Notif] Local timezone set to: ${loc.name}');
          return;
        }
      }
      // Last resort: pick a zone matching the device's current UTC offset.
      final fallback = _zoneForOffset(DateTime.now().timeZoneOffset);
      tz.setLocalLocation(tz.getLocation(fallback));
      debugPrint('[Notif] Local timezone (offset fallback) set to: $fallback');
    } catch (e) {
      debugPrint('[Notif] Timezone init failed: $e — using UTC fallback');
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
  }

  static tz.Location? _tryGetLocation(String name) {
    try {
      return tz.getLocation(name);
    } catch (_) {
      return null;
    }
  }

  /// Best-effort IANA zone for the device's current UTC offset. Only used as
  /// a fallback when the platform id is unavailable. Fixed-offset zones (like
  /// Europe/Moscow, UTC+3 year-round) are exact; DST zones are approximate.
  static String _zoneForOffset(Duration offset) {
    // Keys are UTC offsets in minutes (Duration can't be a const map key).
    const candidates = <int, List<String>>{
      0: ['Etc/UTC'],
      60: ['Europe/Berlin', 'Europe/Paris'],
      120: ['Europe/Kyiv', 'Europe/Athens'],
      180: ['Europe/Moscow'],
      240: ['Europe/Samara', 'Asia/Dubai'],
      300: ['Asia/Yekaterinburg', 'Asia/Karachi'],
      360: ['Asia/Almaty', 'Asia/Dhaka'],
      420: ['Asia/Bangkok', 'Asia/Jakarta'],
      480: ['Asia/Shanghai', 'Asia/Singapore'],
      540: ['Asia/Tokyo', 'Asia/Seoul'],
      600: ['Australia/Sydney', 'Asia/Vladivostok'],
      660: ['Asia/Magadan'],
      720: ['Pacific/Auckland'],
      -60: ['Atlantic/Azores'],
      -120: ['America/Noronha'],
      -180: ['America/Sao_Paulo', 'America/Argentina/Buenos_Aires'],
      -240: ['America/New_York', 'America/Toronto'],
      -300: ['America/Chicago', 'America/Bogota'],
      -360: ['America/Denver', 'America/Mexico_City'],
      -420: ['America/Los_Angeles', 'America/Phoenix'],
      -480: ['America/Anchorage', 'America/Vancouver'],
      -540: ['America/Adak'],
      -600: ['Pacific/Honolulu'],
      -660: ['Pacific/Niue'],
      -720: ['Etc/GMT+12'],
    };
    for (final zone in candidates[offset.inMinutes] ?? const <String>[]) {
      if (_tryGetLocation(zone) != null) return zone;
    }
    return 'Etc/UTC';
  }

  Future<void> _createChannels() async {
    const dailyChannel = AndroidNotificationChannel(
      'daily_reminder',
      'Ежедневное напоминание',
      description: 'Напоминания о записи в дневник',
      // max importance triggers heads-up display and bypasses Doze batching
      // (channel importance is read by the OS, not the per-notification details).
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(dailyChannel);
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return webnotif.webRequestPermission();
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted == true) {
          await android.requestExactAlarmsPermission();
        }
        return granted ?? false;
      }
      return false;
    }
    if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return (await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          false;
    }
    return false;
  }

  /// Requests notification + exact-alarm + battery-optimization permissions.
  static Future<String> requestAllPermissions() async {
    if (kIsWeb) {
      final ok = await webnotif.webRequestPermission();
      return ok
          ? 'Уведомления: разрешено (браузер)'
          : 'Уведомления: ОТКЛОНЕНО (браузер) — разрешите в настройках сайта';
    }
    final buffer = StringBuffer();
    if (!Platform.isAndroid) {
      final ok = await NotificationService().requestPermissions();
      return ok ? 'OK' : 'Denied';
    }

    // --- Notification permission ---
    final notif = await Permission.notification.status;
    if (!notif.isGranted) {
      final res = await Permission.notification.request();
      buffer.writeln(
        res.isGranted ? 'Уведомления: разрешено' : 'Уведомления: ОТКЛОНЕНО',
      );
    } else {
      buffer.writeln('Уведомления: уже разрешено');
    }

    // --- SCHEDULE_EXACT_ALARM (Android 12+) ---
    final exact = await Permission.scheduleExactAlarm.status;
    if (exact.isGranted || exact.isRestricted) {
      buffer.writeln('Точные будильники: уже разрешено');
    } else if (exact.isPermanentlyDenied) {
      await openAppSettings();
      buffer.writeln(
        'Точные будильники: ОТКЛОНЕНО — открыты настройки приложения; '
        'найдите раздел "Будильники и напоминания" и включите точное расписание',
      );
    } else {
      final res = await Permission.scheduleExactAlarm.request();
      buffer.writeln(
        res.isGranted
            ? 'Точные будильники: разрешено'
            : 'Точные будильники: ОТКЛОНЕНО',
      );
    }

    // --- ignoreBatteryOptimizations ---
    final battery = await Permission.ignoreBatteryOptimizations.status;
    if (battery.isGranted || battery.isRestricted) {
      buffer.writeln('Оптимизация батареи: уже отключена');
    } else if (battery.isPermanentlyDenied) {
      await openAppSettings();
      buffer.writeln(
        'Оптимизация батареи: ОТКЛОНЕНО — открыты настройки приложения; '
        'в разделе "Батарея" выберите "Без ограничений"',
      );
    } else {
      final res = await Permission.ignoreBatteryOptimizations.request();
      buffer.writeln(
        res.isGranted
            ? 'Оптимизация батареи: отключена'
            : 'Оптимизация батареи: ОТКЛОНЕНО (уведомления могут опаздывать в фоне)',
      );
    }

    return buffer.toString();
  }

  Future<void> showNotification(
    String title,
    String body, [
    NotificationDetails? details,
  ]) async {
    if (kIsWeb) {
      webnotif.webShowNotification(title, body);
      return;
    }
    final finalDetails = details ?? _defaultDetails();
    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: finalDetails,
    );
  }

  static NotificationDetails _defaultDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Ежедневное напоминание',
        channelDescription: 'Напоминания о записи в дневник',
        // max importance + reminder category makes the OS treat this as an
        // alarm-class notification that fires on time even under Doze.
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: '@drawable/ic_notification',
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Parses a `HH:mm` string into (hour, minute), or returns `null` for
  /// anything malformed or out of range. Pure — no platform / timezone
  /// access, so it is directly unit-testable.
  static ({int hour, int minute})? parseScheduleTime(String time) {
    final parts = time.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return (hour: hour, minute: minute);
  }

  static Future<void> scheduleDaily(
    String time,
    String title,
    String body, {
    NotificationDetails? notificationDetails,
    // Only true when the user actively toggles the reminder on (settings /
    // home dialog). At startup we re-arm silently — no battery dialog then.
    bool requestBatteryExemption = false,
  }) async {
    // Parse HH:MM robustly (works identically on web and native)
    final parsed = parseScheduleTime(time);
    if (parsed == null) {
      debugPrint('[Notif] scheduleDaily rejected: invalid time "$time"');
      return;
    }
    final hour = parsed.hour;
    final minute = parsed.minute;

    if (kIsWeb) {
      // Browser Notification API: request permission lazily, then arm a
      // repeating timer that shows the notification and re-arms for the
      // next day. Active while the tab is open.
      final granted = await webnotif.webRequestPermission();
      if (!granted) {
        debugPrint('[Notif] Web: permission denied — reminder not scheduled');
        return;
      }
      final now = DateTime.now();
      var fire = DateTime(now.year, now.month, now.day, hour, minute);
      if (!fire.isAfter(now)) fire = fire.add(const Duration(days: 1));
      _webScheduleDaily(fire, title, body);
      debugPrint('[Notif] Web: daily reminder armed for $hour:$minute');
      return;
    }

    debugPrint('[Notif] Parsing time: hour=$hour minute=$minute from "$time"');

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('[Notif] Scheduled date (local): ${scheduledDate.toIso8601String()}');

    // Use calendar fields so the selected time remains a wall-clock time in
    // the local timezone instead of being converted from a different instant.
    final tzScheduled = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );
    debugPrint('[Notif] TZ scheduled: ${tzScheduled.toIso8601String()}, zone: ${tzScheduled.location.name}');

    final details = notificationDetails ?? _defaultDetails();

    // Decide scheduleMode EXPLICITLY from permission state
    AndroidScheduleMode mode;
    bool exactGranted = false;
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      exactGranted = status.isGranted || status.isRestricted;
      mode = exactGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } else {
      mode = AndroidScheduleMode.exactAllowWhileIdle;
    }

    debugPrint(
      '[Notif] scheduleDaily: '
      'wall=$hour:$minute, '
      'exact_alarm_granted=$exactGranted, '
      'mode=${mode.name}',
    );

    if (!exactGranted && Platform.isAndroid) {
      debugPrint(
        '[Notif] WARNING: SCHEDULE_EXACT_ALARM not granted — using '
        'inexactAllowWhileIdle which Doze-batches and can be 1-3+ hours late.',
      );
    }

    // MIUI/HyperOS (Redmi) aggressively kills background processes, which
    // silently drops scheduled alarms even when exact-alarm is granted.
    // Asking the user to exempt the app from battery optimization is the
    // single highest-value fix for "test notification arrives, reminder
    // never fires". The system dialog appears once; if denied we keep the
    // inexact fallback (better than nothing). Only ask when the user
    // actively toggles the reminder on — at startup we re-arm silently.
    if (requestBatteryExemption && Platform.isAndroid) {
      try {
        final batt = await Permission.ignoreBatteryOptimizations.status;
        if (!batt.isGranted && !batt.isRestricted) {
          final ok = await Permission.ignoreBatteryOptimizations.request();
          debugPrint('[Notif] battery-optimization request → $ok');
        }
      } catch (e) {
        debugPrint('[Notif] battery-optimization request failed: $e');
      }
    }

    // Cancel previous reminder first
    await _notifications.cancel(id: 0);

    // Note: `zonedSchedule` in flutter_local_notifications ^22 is timezone-aware
    // and does not accept `uiLocalNotificationDateInterpretation` — that param
    // is only meaningful for the non-zoned `show`/`periodicallyShow` paths.
    await _notifications.zonedSchedule(
      id: 0,
      title: title,
      body: body,
      scheduledDate: tzScheduled,
      notificationDetails: details,
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('[Notif] scheduled ok with mode=${mode.name}, next fire at ${tzScheduled.toIso8601String()}');
  }

  static Future<void> updateReminderFromSettings(
    AppSettings settings, {
    bool requestBatteryExemption = false,
  }) async {
    if (settings.reminderEnabled &&
        settings.reminderTime != null &&
        settings.reminderTime!.isNotEmpty) {
      final body = settings.reminderText?.isNotEmpty == true
          ? settings.reminderText!
          : 'Не забудьте записать свои мысли в дневник';
      await scheduleDaily(
        settings.reminderTime!,
        'Напоминание',
        body,
        requestBatteryExemption: requestBatteryExemption,
      );
      debugPrint('Scheduled daily notification at ${settings.reminderTime}');
    } else {
      await cancelAll();
      debugPrint('Cancelled all notifications');
    }
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) {
      _webTimer?.cancel();
      _webTimer = null;
      return;
    }
    await _notifications.cancelAll();
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) {
      _webTimer?.cancel();
      _webTimer = null;
      return;
    }
    await _notifications.cancel(id: id);
  }

  // ───────────────────────── Web (browser) helpers ────────────────────────

  /// Arms a repeating web timer: fires once at [nextFire], shows the
  /// notification, then re-arms for the following day. The actual browser
  /// permission + show calls are delegated to the conditional web module.
  static void _webScheduleDaily(
    DateTime nextFire,
    String title,
    String body,
  ) {
    _webTimer?.cancel();
    var fire = nextFire;
    final now = DateTime.now();
    if (!fire.isAfter(now)) fire = fire.add(const Duration(days: 1));
    final delay = fire.difference(now);
    _webTimer = Timer(delay, () {
      webnotif.webShowNotification(title, body);
      _webScheduleDaily(fire.add(const Duration(days: 1)), title, body);
    });
    debugPrint(
      '[Notif] Web: next fire in ${delay.inMinutes} min at '
      '${fire.toIso8601String()}',
    );
  }

  static Future<String> checkPermissions() async {
    if (kIsWeb) return 'Web: notifications unsupported';
    final buffer = StringBuffer();
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      buffer.writeln('Notification: $status');
      final exactAlarm = await Permission.scheduleExactAlarm.status;
      buffer.writeln('ExactAlarm: $exactAlarm');
      final ignoreBattery = await Permission.ignoreBatteryOptimizations.status;
      buffer.writeln('IgnoreBattery: $ignoreBattery');
    } else {
      buffer.writeln('Not Android');
    }
    return buffer.toString();
  }

  static Future<String?> sendTest() async {
    if (kIsWeb) {
      final ok = await webnotif.webRequestPermission();
      if (!ok) return 'Уведомления: ОТКЛОНЕНО браузером';
      webnotif.webShowNotification(
        'Тест уведомления',
        'Если вы это видите — уведомления работают!',
      );
      return null;
    }
    try {
      await _notifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Тест уведомления',
        body: 'Если вы это видите — уведомления работают!',
        notificationDetails: _defaultDetails(),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
