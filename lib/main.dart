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
  
  // These can run in parallel as they don't block the UI
  final initFuture = Future.wait([
    notificationService.initialize(),
    autoExport.loadState(),
    _precacheAvatar(),
  ]);
  
  // Update reminders from settings (depends on settings being loaded)
  await NotificationService.updateReminderFromSettings(settings);
  
  // Set auto-export callback
  autoExport.setExportCallback(() async {
    return StorageService().exportToJson();
  });

  // Wait for parallel initialization to complete
  await initFuture;

  runApp(
    MyApp(notificationService: notificationService, initialSettings: settings),
  );
}

/// Loads and decodes the app avatar before the first frame so the splash
/// screen can show it immediately.
Future<void> _precacheAvatar() async {
  final provider = const AssetImage('assets/ataraxy.png');
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<void>();
  late final ImageStreamListener listener;
  void done() {
    if (completer.isCompleted) return;
    stream.removeListener(listener);
    completer.complete();
  }

  listener = ImageStreamListener(
    (_, __) => done(),
    onError: (_, __) => done(),
  );
  stream.addListener(listener);
  // Safety net: if the asset stream never delivers AND never errors (rare
  // but possible on some engines), don't block startup forever — the splash
  // paints the avatar from its own Image.asset anyway.
  try {
    await completer.future.timeout(const Duration(seconds: 4));
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
