import 'package:ataraxy/compat/material.dart';
import 'package:intl/intl.dart';

import 'strings_data.g.dart';

/// Localized UI strings.
///
/// The message catalogue lives in the ARB files under `lib/l10n/arb/` and is
/// flattened into `strings_data.g.dart` by `tools/build_l10n.py`. This class
/// keeps the small string-key lookup API the rest of the app already uses.
class L {
  static const Map<String, Map<String, String>> _strings = kStrings;

  static final Map<String, Map<String, String>> _signLabels = kSignLabels;

  static String dreamSign(BuildContext context, String id) {
    final code = Localizations.localeOf(context).languageCode;
    final map = _signLabels[id];
    if (map == null) return id;
    return map[code] ?? map['en'] ?? id;
  }

  static String tr(
    BuildContext context,
    String key, {
    Map<String, Object?>? params,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    return trStatic(key, languageCode: code, params: params);
  }

  /// Locales the app ships, in `MaterialApp.supportedLocales` order.
  static const List<String> supportedLanguageCodes = ['en', 'fr', 'ru'];

  /// Resolves the language the app is actually showing, for code that runs
  /// outside the widget tree (notification text scheduled from `main`, the AI
  /// controller).
  ///
  /// An explicit user choice wins; otherwise the first system locale we ship
  /// wins; otherwise English — the same resolution `MaterialApp` performs, so
  /// a scheduled notification never speaks a different language than the UI.
  static String resolveLanguage(
    String? chosen,
    Iterable<Locale> systemLocales,
  ) {
    if (chosen != null && supportedLanguageCodes.contains(chosen)) {
      return chosen;
    }
    for (final locale in systemLocales) {
      if (supportedLanguageCodes.contains(locale.languageCode)) {
        return locale.languageCode;
      }
    }
    return 'en';
  }

  /// Plural form of a message: looks up `key_one` / `key_few` / `key_many` /
  /// `key_other` for the locale's CLDR plural category of [count].
  ///
  /// The counts the app shows ("1 запись", "2 записи", "5 записей") cannot be
  /// expressed by substituting a number into one flat string, and the AI screen
  /// used to branch on `languageCode == 'ru'` with hand-written Russian
  /// endings — which left English and French with the Russian grammar. Suffixed
  /// ARB keys let each locale supply only the forms it actually has: ru defines
  /// `_one/_few/_many`, en and fr define `_one/_other`.
  static String trPlural(
    BuildContext context,
    String key,
    num count, {
    Map<String, Object?>? params,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    return trPluralStatic(key, count, languageCode: code, params: params);
  }

  /// Same as [trPlural] without a [BuildContext].
  static String trPluralStatic(
    String key,
    num count, {
    String languageCode = 'ru',
    Map<String, Object?>? params,
  }) {
    final category = Intl.pluralLogic<String>(
      count,
      locale: languageCode,
      one: 'one',
      few: 'few',
      many: 'many',
      other: 'other',
    );
    // Fall back to `other` when a locale has no dedicated form for the
    // category (ru's `many` never exists in en/fr).
    for (final suffix in [category, 'other', 'many', 'few', 'one']) {
      final candidate = '${key}_$suffix';
      if (_strings.containsKey(candidate)) {
        return trStatic(
          candidate,
          languageCode: languageCode,
          params: {...?params, 'n': count},
        );
      }
    }
    return trStatic(key, languageCode: languageCode, params: params);
  }

  /// Same as [tr] but without a [BuildContext] — for code that runs outside
  /// the widget tree (e.g. an AI controller). Unknown languages fall back to
  /// English, matching [resolveLanguage].
  static String trStatic(
    String key, {
    String languageCode = 'ru',
    Map<String, Object?>? params,
  }) {
    final map = _strings[key];
    if (map == null) return key;
    final raw = map[languageCode] ?? map['en'] ?? key;
    if (params == null) return raw;
    var value = raw;
    params.forEach((k, v) {
      final text = v?.toString() ?? '';
      value = value.replaceAll('{$k}', text).replaceAll('%{$k}', text);
    });
    return value;
  }
}
