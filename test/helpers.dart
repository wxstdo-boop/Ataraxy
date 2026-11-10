import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/theme/app_theme.dart';

/// Shared bootstrap for screen-level widget tests.
///
/// Every screen under test reads `SettingsProvider`, uses `L.tr` (which needs
/// a locale) and touches Hive/SharedPreferences, so all of that is set up here
/// once. Call [initTestStorage] from `setUpAll` and wrap widgets with
/// [testApp] / [testAppWithSettings].
void initTestStorage(String name) {
  TestWidgetsFlutterBinding.ensureInitialized();
  Hive.init(Directory.systemTemp.createTempSync('hive_$name').path);
}

/// Wraps [child] in a MaterialApp configured like the real app (theme + the
/// ru/en/fr localizations) with a [SettingsProvider] on top, so screens that
/// call `SettingsProvider.of` / `L.tr` behave exactly as in production.
Widget testApp(
  Widget child, {
  AppSettings settings = const AppSettings(),
  void Function(AppSettings)? onChanged,
  Locale locale = const Locale('ru'),
}) {
  return SettingsProvider(
    settings: settings,
    onChanged: onChanged ?? (_) {},
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.lightMaterialYou(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en'), Locale('fr')],
      home: child,
    ),
  );
}

/// Clears mocked prefs between tests.
void resetPrefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
}

/// Drives real (Hive/disk) async work to completion.
///
/// Storage I/O never runs under the fake async clock, and screens interleave
/// short `Future.delayed` timers with that I/O, so neither a plain `pump` nor
/// a single `runAsync` settles them. This alternates the two — advancing the
/// fake clock and letting real I/O progress — until [done] reports true (or
/// [maxRounds] is reached). Pass [done] to stop as soon as the expected state
/// appears; omit it to just wait a fixed number of rounds.
Future<void> settle(
  WidgetTester tester, {
  bool Function()? done,
  int maxRounds = 40,
}) async {
  for (var i = 0; i < maxRounds; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    if (done != null && done()) return;
  }
}
