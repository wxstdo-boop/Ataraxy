import 'package:dream_journal/theme/app_theme.dart';

enum AppLanguage { system, russian, english, french }

extension AppLanguageExtension on AppLanguage {
  String get label {
    return switch (this) {
      AppLanguage.system => 'Системный',
      AppLanguage.russian => 'Русский',
      AppLanguage.english => 'English',
      AppLanguage.french => 'Français',
    };
  }

  String get translationKey {
    return switch (this) {
      AppLanguage.system => 'langSystem',
      AppLanguage.russian => 'langRussian',
      AppLanguage.english => 'langEnglish',
      AppLanguage.french => 'langFrench',
    };
  }

  // languageCode для MaterialApp.locale, null = системный
  String? get localeCode {
    switch (this) {
      case AppLanguage.system:
        return null;
      case AppLanguage.russian:
        return 'ru';
      case AppLanguage.english:
        return 'en';
      case AppLanguage.french:
        return 'fr';
    }
  }
}

class AppSettings {
  final AppThemeMode themeMode;
  final AppLanguage language;
  final String? pin;
  final bool tulpaEnabled;
  final bool showWelcome;
  final bool reminderEnabled;
  final String? reminderTime; // "HH:mm"
  final String? reminderText;
  final bool autosave;
  final bool waterEnabled;
  final bool fastingEnabled;
  final bool pomodoroEnabled;
  final bool stepsEnabled;
  final bool devModeEnabled;
  final bool devHrtTracking;
  // Data protection: when importing a backup, entries that were deleted on
  // this device stay deleted (their ids are remembered as tombstones and
  // skipped during import). Off by default = import behaves like a plain
  // merge (old behaviour); on = deleted entries never resurrect.
  final bool protectDeletedOnImport;
  // AI assistant: optional custom OpenAI-compatible provider. When the
  // endpoint/key are empty, the free Pollinations.AI endpoint is used.
  // The key is stored locally (lightly obfuscated), never in the repo.
  final bool aiEnabled;
  final String? aiEndpoint;
  final String? aiModel;
  final String? aiKey; // stored obfuscated
  final int aiDailyLimit; // messages per day, <=0 = unlimited

  const AppSettings({
    this.themeMode = AppThemeMode.lightLavender,
    this.language = AppLanguage.system,
    this.pin,
    this.tulpaEnabled = false,
    this.showWelcome = true,
    this.reminderEnabled = false,
    this.reminderTime,
    this.reminderText,
    this.autosave = false,
    this.waterEnabled = false,
    this.fastingEnabled = false,
    this.pomodoroEnabled = false,
    this.stepsEnabled = false,
    this.devModeEnabled = false,
    this.devHrtTracking = false,
    this.protectDeletedOnImport = false,
    this.aiEnabled = true,
    this.aiEndpoint,
    this.aiModel,
    this.aiKey,
    this.aiDailyLimit = 13000,
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    String? pin,
    bool? tulpaEnabled,
    bool clearPin = false,
    bool? showWelcome,
    bool? reminderEnabled,
    String? reminderTime,
    String? reminderText,
    bool clearReminderTime = false,
    bool clearReminderText = false,
    bool? autosave,
    bool? waterEnabled,
    bool? fastingEnabled,
    bool? pomodoroEnabled,
    bool? stepsEnabled,
    bool? devModeEnabled,
    bool? devHrtTracking,
    bool? protectDeletedOnImport,
    bool? aiEnabled,
    String? aiEndpoint,
    String? aiModel,
    String? aiKey,
    int? aiDailyLimit,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      pin: clearPin ? null : (pin ?? this.pin),
      tulpaEnabled: tulpaEnabled ?? this.tulpaEnabled,
      showWelcome: showWelcome ?? this.showWelcome,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime:
          clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      reminderText:
          clearReminderText ? null : (reminderText ?? this.reminderText),
      autosave: autosave ?? this.autosave,
      waterEnabled: waterEnabled ?? this.waterEnabled,
      fastingEnabled: fastingEnabled ?? this.fastingEnabled,
      pomodoroEnabled: pomodoroEnabled ?? this.pomodoroEnabled,
      stepsEnabled: stepsEnabled ?? this.stepsEnabled,
      devModeEnabled: devModeEnabled ?? this.devModeEnabled,
      devHrtTracking: devHrtTracking ?? this.devHrtTracking,
      protectDeletedOnImport:
          protectDeletedOnImport ?? this.protectDeletedOnImport,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiEndpoint: aiEndpoint ?? this.aiEndpoint,
      aiModel: aiModel ?? this.aiModel,
      aiKey: aiKey ?? this.aiKey,
      aiDailyLimit: aiDailyLimit ?? this.aiDailyLimit,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'language': language.name,
        'pin': pin,
        'tulpaEnabled': tulpaEnabled,
        'showWelcome': showWelcome,
        'reminderEnabled': reminderEnabled,
        'reminderTime': reminderTime,
        'reminderText': reminderText,
        'autosave': autosave,
        'waterEnabled': waterEnabled,
        'fastingEnabled': fastingEnabled,
        'pomodoroEnabled': pomodoroEnabled,
        'stepsEnabled': stepsEnabled,
        'devModeEnabled': devModeEnabled,
        'devHrtTracking': devHrtTracking,
        'protectDeletedOnImport': protectDeletedOnImport,
        'aiEnabled': aiEnabled,
        'aiEndpoint': aiEndpoint,
        'aiModel': aiModel,
        'aiKey': aiKey,
        'aiDailyLimit': aiDailyLimit,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == json['themeMode'],
        orElse: () => AppThemeMode.lightMaterialYou,
      ),
      language: AppLanguage.values.firstWhere(
        (e) => e.name == json['language'],
        orElse: () => AppLanguage.system,
      ),
      pin: json['pin'] as String?,
      tulpaEnabled: (json['tulpaEnabled'] as bool?) ?? false,
      showWelcome: (json['showWelcome'] as bool?) ?? true,
      reminderEnabled: (json['reminderEnabled'] as bool?) ?? false,
      reminderTime: json['reminderTime'] as String?,
      reminderText: json['reminderText'] as String?,
      autosave: (json['autosave'] as bool?) ?? false,
      waterEnabled: (json['waterEnabled'] as bool?) ?? false,
      fastingEnabled: (json['fastingEnabled'] as bool?) ?? false,
      pomodoroEnabled: (json['pomodoroEnabled'] as bool?) ?? false,
      stepsEnabled: (json['stepsEnabled'] as bool?) ?? false,
      devModeEnabled: (json['devModeEnabled'] as bool?) ?? false,
      devHrtTracking: (json['devHrtTracking'] as bool?) ?? false,
      protectDeletedOnImport:
          (json['protectDeletedOnImport'] as bool?) ?? false,
      aiEnabled: (json['aiEnabled'] as bool?) ?? true,
      aiEndpoint: json['aiEndpoint'] as String?,
      aiModel: json['aiModel'] as String?,
      aiKey: json['aiKey'] as String?,
      aiDailyLimit: (json['aiDailyLimit'] as num?)?.toInt() ?? 500,
    );
  }
}
