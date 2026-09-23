import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ataraxy/main.dart';
import 'package:ataraxy/models/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  Hive.init(Directory.systemTemp.createTempSync('hive_test').path);
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('hive_widget').path);
  });

  testWidgets('App launches smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MyApp(initialSettings: const AppSettings(showWelcome: false)),
    );
    // Splash animation runs ~1.8s before the home content is shown, then a
    // 600ms fade-in. Pump past both (pumpAndSettle would time out on the
    // looping splash spinner / home animations).
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('Locked app shows lock screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'app_settings': jsonEncode({
        'themeMode': 'lightMaterialYou',
        'language': 'system',
        'pin': '1234',
      }),
    });
    await tester.pumpWidget(MyApp(
      initialSettings: const AppSettings(showWelcome: false, pin: '1234'),
    ));
    // Splash animation runs ~1.8s before the lock screen is shown, then a
    // 600ms fade-in.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });
}