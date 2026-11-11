
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/settings.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/auto_export_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // DIAGNOSTIC (temporary): in release builds Flutter swallows the widget
  // chain of build errors ("Another exception was thrown"). Dump the full
  // details so we can identify the crashing subtree from logcat.
  FlutterError.onError = (details) {
    debugPrint('FLUTTER-ERROR-START');
    debugPrint('exception: ${details.exception}');
    debugPrint('stack:\n${details.stack}');
    debugPrint('context: ${details.context}');
    debugPrint('FLUTTER-ERROR-END');
  };
  // Lock the app to portrait only — landscape is disabled entirely.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Performance optimization: run critical path sequentially, 
  // non-critical work in parallel. This reduces splash screen time on Redmi Note 12.
  
  // CRITICAL: Initialize ONLY the locale data the app actually ships (ru/en/fr).
  // The no-arg form initializes every locale intl knows about, which can
  // take seconds on low-end devices and hang the app on the splash
  // ("зависло на Ataraxy").
  await initializeDateFormatting('ru');
  await initializeDateFormatting('en');
  await initializeDateFormatting('fr');
  
  // CRITICAL: Hive powers settings/chat/favorites storage. On web there is no file
  // system, so initialize with the browser backend; on native platforms use
  // the path_provider-backed hive_flutter setup.
  await Hive.initFlutter();
  
  // Load settings early - they're needed for the initial app state
  final settings = await SettingsService().load();
  
  // Run non-critical initialization in parallel
  final notificationService = NotificationService();
  final autoExport = AutoExportService();

  // Precache the avatar BEFORE the first frame so the splash logo paints
  // immediately instead of blinking in a beat later ("АДА появляется не
  // сразу"). This is the only piece of the boot we must finish up front.
  await _precacheAvatar();

  // Draw the first frame NOW — the Flutter splash (with the avatar) is on
  // screen from this point. Everything below is non-critical boot work and
  // used to run BEFORE runApp, holding the native launch window (a flat
  // colour, no logo) on screen for its whole duration.
  runApp(
    MyApp(notificationService: notificationService, initialSettings: settings),
  );

  autoExport.setExportCallback(() async {
    return StorageService().exportToJson();
  });
  // Deferred off the startup path: notification setup, auto-export state and
  // the reminder refresh all do platform-channel I/O that would otherwise
  // delay the first frame.
  unawaited(_guarded(notificationService.initialize(), 'Notification init'));
  unawaited(_guarded(autoExport.loadState(), 'Auto-export load'));
  unawaited(
    _guarded(
      NotificationService.updateReminderFromSettings(settings),
      'Reminder update',
    ),
  );
}

/// Runs [future] and swallows/logs any error so a single failing subsystem
/// (e.g. notifications) can never block startup and leave a black screen.
Future<void> _guarded(Future<dynamic> future, String label) async {
  try {
    await future;
  } catch (e) {
    debugPrint('[Boot] $label failed (non-fatal): $e');
  }
}

/// Loads and decodes the app avatar before the first frame so the splash
/// screen can show it immediately.
///
/// The splash requests the avatar RESIZED (`cacheWidth: 96 * dpr`), which
/// resolves to a different image-cache key than the raw asset. Precaching the
/// bare `AssetImage` therefore populated a key the splash never looked up, and
/// the tile re-decoded on its first frame — the avatar "появляется не сразу".
/// We precache the exact [ResizeImage] variant the widget will ask for, using
/// the same width formula, so the first painted frame already has it.
Future<void> _precacheAvatar() async {
  final dpr =
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
  final targetWidth = (96 * dpr).ceil();
  final provider = ResizeImage(
    const AssetImage('assets/ataraxy.png'),
    width: targetWidth,
  );
  // Resolve with the same devicePixelRatio the widget will use: AssetImage
  // picks its asset variant (and thus its cache key) from
  // `configuration.devicePixelRatio`, so an `ImageConfiguration.empty`
  // (dpr 1.0) would key a different image and defeat the precache.
  final stream = provider.resolve(ImageConfiguration(devicePixelRatio: dpr));
  final completer = Completer<void>();
  late final ImageStreamListener listener;
  void done() {
    if (completer.isCompleted) return;
    stream.removeListener(listener);
    completer.complete();
  }

  listener = ImageStreamListener((_, _) => done(), onError: (_, _) => done());
  stream.addListener(listener);
  // Safety net: if the asset stream never delivers AND never errors (rare
  // but possible on some engines), don't block startup forever.
  try {
    await completer.future.timeout(const Duration(seconds: 1));
  } catch (_) {
    done();
  }
}

class MyApp extends StatefulWidget {
  final NotificationService? notificationService;
  final AppSettings initialSettings;

  const MyApp({
    super.key,
    this.notificationService,
    required this.initialSettings,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppSettings _settings;
  late bool _showWelcome;
  bool _authenticated = false;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _settingsNotifier = ValueNotifier<AppSettings>(AppSettings());

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _settingsNotifier.value = widget.initialSettings;
    _showWelcome = widget.initialSettings.showWelcome;
  }

  @override
  void dispose() {
    _settingsNotifier.dispose();
    super.dispose();
  }

  void _onSettingsChanged(AppSettings newSettings) {
    final remindersChanged =
        _settings.reminderEnabled != newSettings.reminderEnabled ||
        _settings.reminderTime != newSettings.reminderTime ||
        _settings.reminderText != newSettings.reminderText;
    // Only fields MaterialApp reads directly (theme / language / auth gates)
    // need the full setState rebuild of the shell. Everything else travels
    // through the ValueNotifier → SettingsProvider path, so rebuilding the
    // whole app here would be pure duplicated work on every toggle — the
    // main cause of the theme-switch jank on low-end devices.
    final shellRelevant =
        _settings.themeMode != newSettings.themeMode ||
        _settings.language != newSettings.language ||
        _settings.showWelcome != newSettings.showWelcome;

    _settings = newSettings;
    _settingsNotifier.value = newSettings;

    if (shellRelevant) {
      setState(() {});
    }

    SettingsService().save(newSettings);
    if (remindersChanged) {
      NotificationService.updateReminderFromSettings(newSettings);
    }
  }

  void _onWelcomeComplete(AppSettings newSettings) {
    _settings = newSettings;
    _settingsNotifier.value = newSettings;
    _showWelcome = false;

    setState(() {});

    SettingsService().save(newSettings);
    NotificationService.updateReminderFromSettings(newSettings);
  }

  void _dismissWelcome() {
    setState(() => _showWelcome = false);
  }

  void _onUnlocked() {
    setState(() => _authenticated = true);
  }

  void _onRequestLock() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() => _authenticated = false);
  }

  AppThemeMode get _mode => _settings.themeMode;

  String? get _localeCode => _settings.language.localeCode;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      key: const ValueKey('shell'),
      themeMode: _mode,
      localeCode: _localeCode,
      navigatorKey: _navigatorKey,
      settingsNotifier: _settingsNotifier,
      onSettingsChanged: _onSettingsChanged,
      showWelcome: _showWelcome,
      authenticated: _authenticated,
      onUnlocked: _onUnlocked,
      onRequestLock: _onRequestLock,
      onWelcomeComplete: _onWelcomeComplete,
      onDismissWelcome: _dismissWelcome,
    );
  }
}