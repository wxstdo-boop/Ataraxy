import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/models/settings.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
// Conditional web helpers: real Notification API on web, no-op stub on
// native — importing package:web directly here breaks VM tests/native builds.
import 'web_notifications_stub.dart'
    if (dart.library.js_interop) 'web_notifications.dart'
    as webnotif;

/// Which permission a [PermissionCheck] describes.
enum PermissionKind { notifications, exactAlarms, batteryOptimizations }

/// What happened when the permission was requested.
enum PermissionOutcome {
  granted,
  alreadyGranted,
  denied,
  deniedOpenedSettings,
  grantedInBrowser,
  deniedInBrowser,
}

/// One permission verdict, free of user-facing wording.
///
/// The service used to build a Russian report string and the UI searched it for
/// «ОТКЛОНЕНО» — which silently read a denial as success on iOS/desktop (they
/// answer 'OK'/'Denied') and could never be translated. Verdicts travel as
/// enums now and `permissionReportText` renders them with the active locale.
class PermissionCheck {
  final PermissionKind kind;
  final PermissionOutcome outcome;

  const PermissionCheck(this.kind, this.outcome);

  bool get isDenied =>
      outcome == PermissionOutcome.denied ||
      outcome == PermissionOutcome.deniedOpenedSettings ||
      outcome == PermissionOutcome.deniedInBrowser;
}

/// Result of [NotificationService.requestAllPermissions].
///
/// [checks] carries one verdict per requested permission; [denied] is the
/// aggregate the UI must branch on.
class PermissionReport {
  final List<PermissionCheck> checks;

  const PermissionReport(this.checks);

  bool get denied => checks.any((c) => c.isDenied);
}

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

  /// Locale used for notification text built outside the widget tree.
  ///
  /// Channels, the reminder body and the test notification are created from
  /// `main`/`initialize`, where no `BuildContext` exists — so the language is
  /// pushed in from `_AppRootState` instead of read from `Localizations`.
  static String languageCode = 'en';

  static String _t(String key) => L.trStatic(key, languageCode: languageCode);

  /// OEM family of this device ("xiaomi", "huawei", "samsung", …), resolved
  /// once over the platform channel.
  ///
  /// The reminder dialog used to show the MIUI battery steps on every Android
  /// phone, so a Samsung owner was told to enable "Autostart" in a menu their
  /// ROM does not have. Null means "not asked yet"; [otherOem] means "asked,
  /// and this vendor needs no special steps".
  static String? _oem;
  static const String otherOem = 'other';

  static String? get oem => _oem;

  /// Loads [oem] if it has not been resolved yet. Cheap and never throws.
  static Future<String?> resolveOem() async {
    if (_oem != null) return _oem;
    if (kIsWeb || !Platform.isAndroid) {
      _oem = otherOem;
      return _oem;
    }
    try {
      _oem = await _tzChannel.invokeMethod<String>('getOem') ?? otherOem;
    } catch (e) {
      // An older build without the channel method still has to render the
      // dialog — fall back to "no vendor-specific hint".
      debugPrint('[Notif] OEM lookup failed: $e');
      _oem = otherOem;
    }
    return _oem;
  }

  /// ARB key of the battery/autostart hint for a given OEM family.
  ///
  /// Only vendors whose ROM actually kills background work get a specific
  /// instruction; everyone else gets the generic line. Naming a menu the ROM
  /// does not have is worse than no hint at all.
  static String oemHintKey(String? oem) => switch (oem) {
        'xiaomi' => 'oemHintXiaomi',
        'huawei' => 'oemHintHuawei',
        'oppo' => 'oemHintOppo',
        'vivo' => 'oemHintVivo',
        _ => 'oemHintAndroid',
      };

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    // Set local timezone so scheduled notifications fire at the correct
    // wall-clock time. NOTE: on many MIUI/Redmi builds
    // `DateTime.now().timeZoneName` returns "UTC" even when the device is
    // UTC+3 — relying on tz.local there made reminders fire 3 hours late.
    await _setLocalTimezone();
    // Warms the OEM lookup so the reminder dialog can pick its hint without
    // awaiting inside `build`.
    await resolveOem();

    // flutter_local_notifications has no web implementation and `dart:io`
    // Platform is unavailable in the browser — skip all plugin work on web.
    if (kIsWeb) {
      debugPrint(
        '[Notif] Web platform — notifications are not supported, skipping init',
      );
      return;
    }

    // Small-icon for the status bar MUST be a white monochrome drawable —
    // a colorful launcher icon renders as a solid blob / blank square on
    // Android (incl. MIUI). ic_notification is our custom white vector.
    const androidSettings = AndroidInitializationSettings('ic_notification');
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

    // NOTE: permissions are intentionally NOT requested here. Popping the
    // notification + battery dialogs at every launch was hostile — they are
    // now requested from the welcome screen's "enable" button and from
    // Settings, where the user actually has context for them.
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
    final dailyChannel = AndroidNotificationChannel(
      'daily_reminder',
      _t('notifChannelDailyName'),
      description: _t('notifChannelDailyDescription'),
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

  /// Requests the notification permission and returns whether it was granted.
  ///
  /// [requestExactAlarms] additionally asks for the exact-alarm permission on
  /// Android, which opens the system settings page. Onboarding passes `false`
  /// so a single tap only shows the notification dialog; the settings screen
  /// asks for everything.
  Future<bool> requestPermissions({bool requestExactAlarms = true}) async {
    if (kIsWeb) return webnotif.webRequestPermission();
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted == true && requestExactAlarms) {
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
  ///
  /// Returns one structured verdict per permission; the caller renders them
  /// with `permissionReportText` in the active locale and branches on
  /// [PermissionReport.denied], never on the wording.
  static Future<PermissionReport> requestAllPermissions() async {
    if (kIsWeb) {
      final ok = await webnotif.webRequestPermission();
      return PermissionReport([
        PermissionCheck(
          PermissionKind.notifications,
          ok
              ? PermissionOutcome.grantedInBrowser
              : PermissionOutcome.deniedInBrowser,
        ),
      ]);
    }

    if (!Platform.isAndroid) {
      final ok = await NotificationService().requestPermissions();
      return PermissionReport([
        PermissionCheck(
          PermissionKind.notifications,
          ok ? PermissionOutcome.granted : PermissionOutcome.denied,
        ),
      ]);
    }

    final checks = <PermissionCheck>[];

    // --- Notification permission ---
    final notif = await Permission.notification.status;
    if (notif.isGranted) {
      checks.add(
        const PermissionCheck(
          PermissionKind.notifications,
          PermissionOutcome.alreadyGranted,
        ),
      );
    } else {
      final res = await Permission.notification.request();
      checks.add(
        PermissionCheck(
          PermissionKind.notifications,
          res.isGranted
              ? PermissionOutcome.granted
              : PermissionOutcome.denied,
        ),
      );
    }

    // --- SCHEDULE_EXACT_ALARM (Android 12+) ---
    final exact = await Permission.scheduleExactAlarm.status;
    if (exact.isGranted || exact.isRestricted) {
      checks.add(
        const PermissionCheck(
          PermissionKind.exactAlarms,
          PermissionOutcome.alreadyGranted,
        ),
      );
    } else if (exact.isPermanentlyDenied) {
      await openAppSettings();
      checks.add(
        const PermissionCheck(
          PermissionKind.exactAlarms,
          PermissionOutcome.deniedOpenedSettings,
        ),
      );
    } else {
      final res = await Permission.scheduleExactAlarm.request();
      checks.add(
        PermissionCheck(
          PermissionKind.exactAlarms,
          res.isGranted
              ? PermissionOutcome.granted
              : PermissionOutcome.denied,
        ),
      );
    }

    // --- ignoreBatteryOptimizations ---
    final battery = await Permission.ignoreBatteryOptimizations.status;
    if (battery.isGranted || battery.isRestricted) {
      checks.add(
        const PermissionCheck(
          PermissionKind.batteryOptimizations,
          PermissionOutcome.alreadyGranted,
        ),
      );
    } else if (battery.isPermanentlyDenied) {
      await openAppSettings();
      checks.add(
        const PermissionCheck(
          PermissionKind.batteryOptimizations,
          PermissionOutcome.deniedOpenedSettings,
        ),
      );
    } else {
      final res = await Permission.ignoreBatteryOptimizations.request();
      checks.add(
        PermissionCheck(
          PermissionKind.batteryOptimizations,
          res.isGranted
              ? PermissionOutcome.granted
              : PermissionOutcome.denied,
        ),
      );
    }

    return PermissionReport(checks);
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
        _t('notifChannelDailyName'),
        channelDescription: _t('notifChannelDailyDescription'),
        // max importance + reminder category makes the OS treat this as an
        // alarm-class notification that fires on time even under Doze.
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        icon: 'ic_notification',
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
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
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

    debugPrint(
      '[Notif] Scheduled date (local): ${scheduledDate.toIso8601String()}',
    );

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
    debugPrint(
      '[Notif] TZ scheduled: ${tzScheduled.toIso8601String()}, zone: ${tzScheduled.location.name}',
    );

    final details = notificationDetails ?? _defaultDetails();

    // Decide scheduleMode EXPLICITLY from permission state
    // On Android 14+, also check for USE_EXACT_ALARM permission
    AndroidScheduleMode mode;
    bool exactGranted = false;

    if (Platform.isAndroid) {
      // Check SCHEDULE_EXACT_ALARM permission
      final scheduleExactStatus = await Permission.scheduleExactAlarm.status;
      exactGranted =
          scheduleExactStatus.isGranted || scheduleExactStatus.isRestricted;

      // Use exact mode if permission is granted
      mode = exactGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      // If exact alarm not granted and this is user-initiated, try to request it
      if (!exactGranted && requestBatteryExemption) {
        try {
          final res = await Permission.scheduleExactAlarm.request();
          if (res.isGranted || res.isRestricted) {
            mode = AndroidScheduleMode.exactAllowWhileIdle;
            debugPrint('[Notif] SCHEDULE_EXACT_ALARM granted after request');
          }
        } catch (e) {
          debugPrint('[Notif] SCHEDULE_EXACT_ALARM request failed: $e');
        }
      }
    } else {
      mode = AndroidScheduleMode.exactAllowWhileIdle;
    }

    debugPrint(
      '[Notif] scheduleDaily: '
      'wall=$hour:$minute, '
      'exact_alarm_granted=$exactGranted,'
      'mode=${mode.name}',
    );

    if (!exactGranted && Platform.isAndroid) {
      debugPrint(
        '[Notif] WARNING: SCHEDULE_EXACT_ALARM not granted — using '
        'inexactAllowWhileIdle which Doze-batches and can be 1-3+ hours late. '
        'User should grant permission in settings for exact alarm scheduling.',
      );
    }

    // MIUI/HyperOS (Redmi) aggressively kills background processes, which
    // silently drops scheduled alarms even when exact-alarm is granted.
    // Asking the user to exempt the app from battery optimization is the
    // single highest-value fix for "test notification arrives, reminder
    // never fires". Only when the user actively enables the reminder — at
    // startup we re-arm silently, and popping this system dialog on every
    // launch was hostile.
    if (Platform.isAndroid && requestBatteryExemption) {
      try {
        final batt = await Permission.ignoreBatteryOptimizations.status;
        if (!batt.isGranted && !batt.isRestricted) {
          final ok = await Permission.ignoreBatteryOptimizations.request();
          debugPrint(
            '[Notif] battery-optimization request → ${ok == PermissionStatus.granted ? 'GRANTED' : 'DENIED'}',
          );
        } else {
          debugPrint(
            '[Notif] battery-optimization already granted or restricted',
          );
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
    try {
      await _notifications.zonedSchedule(
        id: 0,
        title: title,
        body: body,
        scheduledDate: tzScheduled,
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint(
        '[NOTIF SUCCESS] Reminder scheduled! Mode=$mode, Next fire: ${tzScheduled.toIso8601String()}',
      );
    } catch (e) {
      debugPrint('[NOTIF ERROR] Failed to schedule: $e');
      rethrow;
    }
  }

  static Future<void> updateReminderFromSettings(
    AppSettings settings, {
    bool requestBatteryExemption = false,
  }) async {
    debugPrint(
      '[NOTIF SETTINGS] reminderEnabled=${settings.reminderEnabled}, time=${settings.reminderTime}',
    );
    if (settings.reminderEnabled &&
        settings.reminderTime != null &&
        settings.reminderTime!.isNotEmpty) {
      final body = settings.reminderText?.isNotEmpty == true
          ? settings.reminderText!
          : _t('notifReminderBody');
      debugPrint(
        '[NOTIF] Scheduling daily at ${settings.reminderTime}, body: $body',
      );
      await scheduleDaily(
        settings.reminderTime!,
        _t('reminder'),
        body,
        requestBatteryExemption: requestBatteryExemption,
      );
      debugPrint(
        '[NOTIF SETTINGS] ✓ Scheduled daily notification at ${settings.reminderTime}',
      );
    } else {
      await cancelAll();
      debugPrint(
        '[NOTIF SETTINGS] × Cancelled all notifications (reminder disabled or no time set)',
      );
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
  static void _webScheduleDaily(DateTime nextFire, String title, String body) {
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

  /// Snapshot of the current permission state, without prompting the user.
  ///
  /// Returns the same structured shape as [requestAllPermissions] so the dev
  /// screen renders it with the shared, localized formatter instead of the raw
  /// English `PermissionStatus` names it used to concatenate.
  static Future<PermissionReport> checkPermissions() async {
    if (kIsWeb) return const PermissionReport([]);
    if (!Platform.isAndroid) {
      final ok = await Permission.notification.isGranted;
      return PermissionReport([
        PermissionCheck(
          PermissionKind.notifications,
          ok ? PermissionOutcome.alreadyGranted : PermissionOutcome.denied,
        ),
      ]);
    }

    PermissionOutcome state(PermissionStatus status) => status.isGranted ||
            status.isRestricted ||
            status.isLimited
        ? PermissionOutcome.alreadyGranted
        : PermissionOutcome.denied;

    return PermissionReport([
      PermissionCheck(
        PermissionKind.notifications,
        state(await Permission.notification.status),
      ),
      PermissionCheck(
        PermissionKind.exactAlarms,
        state(await Permission.scheduleExactAlarm.status),
      ),
      PermissionCheck(
        PermissionKind.batteryOptimizations,
        state(await Permission.ignoreBatteryOptimizations.status),
      ),
    ]);
  }

  static Future<String?> sendTest() async {
    if (kIsWeb) {
      final ok = await webnotif.webRequestPermission();
      if (!ok) return _t('notifTestDeniedBrowser');
      webnotif.webShowNotification(
        _t('testNotification'),
        _t('notifTestBody'),
      );
      return null;
    }
    try {
      await _notifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _t('testNotification'),
        body: _t('notifTestBody'),
        notificationDetails: _defaultDetails(),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
