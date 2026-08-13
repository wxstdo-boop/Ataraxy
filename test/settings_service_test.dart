import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:dream_journal/models/settings.dart';
import 'package:dream_journal/services/settings_service.dart';
import 'package:dream_journal/theme/app_theme.dart';

void main() {
  group('SettingsService', () {
    setUpAll(() async {
      Hive.init(Directory.systemTemp.createTempSync('hive_settings').path);
      await Hive.openBox<String>('app_settings');
    });

    test('load returns defaults when no settings stored', () async {
      final service = SettingsService();
      final settings = await service.load();
      expect(settings, isA<AppSettings>());
      expect(settings.showWelcome, isTrue);
      expect(settings.themeMode, AppThemeMode.lightLavender);
    });

    test('save and load round-trip', () async {
      final service = SettingsService();
      const original = AppSettings(
        showWelcome: false,
        reminderEnabled: true,
        reminderTime: '21:00',
        reminderText: 'Test reminder',
      );
      await service.save(original);
      final loaded = await service.load();
      expect(loaded.showWelcome, isFalse);
      expect(loaded.reminderEnabled, isTrue);
      expect(loaded.reminderTime, equals('21:00'));
      expect(loaded.reminderText, equals('Test reminder'));
    });

    test('reset clears stored settings', () async {
      final service = SettingsService();
      await service.save(const AppSettings(showWelcome: false));
      await service.reset();
      final loaded = await service.load();
      expect(loaded.showWelcome, isTrue); // default
    });

    test('AppSettings copyWith works for all fields', () {
      const base = AppSettings(
        themeMode: AppThemeMode.lightLavender,
        language: AppLanguage.russian,
        pin: '1234',
        tulpaEnabled: true,
        showWelcome: true,
        reminderEnabled: false,
      );

      final updated = base.copyWith(
        themeMode: AppThemeMode.darkPeach,
        language: AppLanguage.english,
        pin: null,
        clearPin: true,
        tulpaEnabled: false,
        showWelcome: false,
        reminderEnabled: true,
        reminderTime: '07:00',
        reminderText: 'Новый текст',
        autosave: true,
        waterEnabled: true,
        fastingEnabled: true,
        pomodoroEnabled: true,
        stepsEnabled: true,
        devModeEnabled: true,
        devHrtTracking: true,
      );

      expect(updated.themeMode, AppThemeMode.darkPeach);
      expect(updated.language, AppLanguage.english);
      expect(updated.pin, isNull);
      expect(updated.tulpaEnabled, isFalse);
      expect(updated.showWelcome, isFalse);
      expect(updated.reminderEnabled, isTrue);
      expect(updated.reminderTime, equals('07:00'));
      expect(updated.reminderText, equals('Новый текст'));
      expect(updated.autosave, isTrue);
      expect(updated.waterEnabled, isTrue);
      expect(updated.fastingEnabled, isTrue);
      expect(updated.pomodoroEnabled, isTrue);
      expect(updated.stepsEnabled, isTrue);
      expect(updated.devModeEnabled, isTrue);
      expect(updated.devHrtTracking, isTrue);
    });

    test('AppSettings JSON round-trip', () {
      const original = AppSettings(
        themeMode: AppThemeMode.darkPeach,
        language: AppLanguage.french,
        pin: '9999',
        showWelcome: false,
        reminderEnabled: true,
        reminderTime: '18:00',
        reminderText: 'Сон',
      );
      final json = original.toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.themeMode, AppThemeMode.darkPeach);
      expect(restored.language, AppLanguage.french);
      expect(restored.pin, equals('9999'));
      expect(restored.showWelcome, isFalse);
      expect(restored.reminderEnabled, isTrue);
      expect(restored.reminderTime, equals('18:00'));
      expect(restored.reminderText, equals('Сон'));
    });

    test('AppSettings fromJson handles unknown theme mode gracefully', () {
      final restored = AppSettings.fromJson({
        'themeMode': 'nonexistent',
        'language': 'russian',
        'showWelcome': true,
      });
      expect(restored.themeMode, AppThemeMode.lightMaterialYou); // orElse fallback
    });
  });
}
