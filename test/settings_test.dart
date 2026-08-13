import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dream_journal/main.dart';
import 'package:dream_journal/models/settings.dart';
import 'package:dream_journal/providers/settings_provider.dart';
import 'package:dream_journal/screens/settings_screen.dart';
import 'package:dream_journal/services/settings_service.dart';
import 'package:dream_journal/widgets/volumetric_switch.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('hive_settings').path);
    await Hive.openBox<String>('app_settings');
  });

testWidgets('tulpa toggle calls onChanged with true', (tester) async {
    AppSettings? captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('en'), Locale('fr')],
        home: SettingsProvider(
          settings: const AppSettings(),
          onChanged: (s) => captured = s,
          child: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Scroll to find the experimental section
    await tester.dragUntilVisible(
      find.text('Экспериментальные'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    // Debug: print all text widgets
    final allTexts = tester.allWidgets.whereType<Text>().map((w) => w.data).toList();
    debugPrint('All texts after scroll: $allTexts');

    // Find the tulpa VolumetricSwitchListTile
    final tulpaText = find.text('Тульпа (записи о тульпах)');
    expect(tulpaText, findsOneWidget);
    // Tap the tile (parent of the Text)
    await tester.tap(find.ancestor(of: tulpaText, matching: find.byType(VolumetricSwitchListTile)));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.tulpaEnabled, isTrue);
  });

  test('settings round-trip via service', () async {
    final svc = SettingsService();
    await svc.save(const AppSettings(tulpaEnabled: true, pin: '1234'));
    final loaded = await svc.load();
    expect(loaded.tulpaEnabled, isTrue);
    expect(loaded.pin, '1234');
  });

  testWidgets('switching theme keeps settings screen mounted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        home: MyApp(initialSettings: const AppSettings(showWelcome: false)),
      ),
    );
    // Splash animation runs ~1.8s before the home screen is shown.
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // open settings
    await tester.tap(find.byIcon(Icons.settings_rounded));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(SettingsScreen), findsOneWidget);

    // tap a theme tile by its label — this used to swap the root widget and
    // pop the route, kicking the user back out of Settings
    await tester.tap(find.text('Dark Peach'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // settings screen must still be present (not kicked out)
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
