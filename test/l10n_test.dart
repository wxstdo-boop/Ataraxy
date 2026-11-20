import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/l10n/strings.dart';

/// Guards the ARB → `strings_data.g.dart` pipeline: every message must exist
/// in all three locales, and the generated map must match the ARB files.
void main() {
  const languages = ['ru', 'en', 'fr'];
  const arbDir = 'lib/l10n/arb';

  Map<String, String> loadArb(String lang) {
    final raw = File('$arbDir/app_$lang.arb').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in data.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value as String,
    };
  }

  /// Plural messages carry a `_one` / `_few` / `_many` / `_other` suffix, and
  /// the valid categories are per language: Russian needs one/few/many, while
  /// English and French only have one/other. Comparing raw keys would demand
  /// Russian-only forms from en/fr and vice versa, so compare the BASE keys and
  /// check that every plural family has the forms its locale actually uses.
  String baseKey(String key) {
    for (final suffix in const ['_one', '_few', '_many', '_other']) {
      if (key.endsWith(suffix)) {
        return key.substring(0, key.length - suffix.length);
      }
    }
    return key;
  }

  const pluralForms = {
    'ru': ['one', 'few', 'many'],
    'en': ['one', 'other'],
    'fr': ['one', 'other'],
  };

  test('every message exists in every locale', () {
    final byLang = {for (final l in languages) l: loadArb(l)};
    final reference = byLang['ru']!.keys.map(baseKey).toSet();

    for (final lang in languages.skip(1)) {
      expect(
        byLang[lang]!.keys.map(baseKey).toSet(),
        reference,
        reason: 'app_$lang.arb diverges from app_ru.arb',
      );
    }
  });

  test('each locale provides the plural forms its grammar needs', () {
    final byLang = {for (final l in languages) l: loadArb(l)};
    // Families that are pluralized: base key -> true.
    final families = byLang['ru']!.keys
        .map(baseKey)
        .where((k) => byLang['ru']!.containsKey('${k}_one'))
        .toSet();

    for (final entry in byLang.entries) {
      final lang = entry.key;
      final keys = entry.value.keys.toSet();
      for (final family in families) {
        final present = pluralForms[lang]!
            .where((f) => keys.contains('${family}_$f'))
            .toList();
        expect(
          present,
          pluralForms[lang],
          reason: 'app_$lang.arb is missing forms for "$family"',
        );
      }
    }
  });

  test('generated map matches the ARB files', () {
    final ru = loadArb('ru');
    for (final key in ru.keys) {
      // Dream-sign labels are namespaced with a `sign_` prefix in the ARB and
      // are read through `L.dreamSign`, which needs a locale context.
      if (key.startsWith('sign_')) continue;
      expect(
        L.trStatic(key, languageCode: 'ru'),
        ru[key],
        reason: 'string for "$key" drifted from app_ru.arb',
      );
    }
  });

  test('trStatic substitutes {name} placeholders', () {
    final text = L.trStatic(
      'reminderNextFire',
      languageCode: 'ru',
      params: {'time': '09:30'},
    );
    expect(text, contains('09:30'));
    expect(text, isNot(contains('{time}')));
  });

  test('unknown keys fall back to the key itself', () {
    expect(L.trStatic('definitelyNotAKey'), 'definitelyNotAKey');
  });

  test('onboarding screen has no hardcoded Russian UI text', () {
    // The welcome/onboarding flow is the first thing an en/fr user sees, yet
    // every string in it was a Russian literal, so those locales got a fully
    // Russian first launch. Comments are excluded; only code lines count.
    _expectNoCyrillic('lib/welcome_screen.dart');
  });

  test('AI settings screen has no hardcoded Russian UI text', () {
    // Same trap: the provider sheet, the saved-keys list and its snack were
    // Russian-only literals while the rest of the screen went through L.tr.
    _expectNoCyrillic('lib/screens/settings_ai.dart');
  });

  test('every key passed to L.tr exists in the catalogue', () {
    // A renamed ARB key is invisible to the compiler: `L.tr` returns the key
    // itself, so the UI renders a literal like "miuiHint" to the user. That
    // happened when the MIUI hint became the per-vendor `oemHintXiaomi` — the
    // reminder dialog kept asking for the old key and nothing failed.
    final known = loadArb('ru').keys.toSet();
    final pattern = RegExp(
      r"L\.tr(?:Static)?\([^)]*?'([a-zA-Z0-9_]+)'",
    );
    final missing = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('l10n/')) continue;
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        final key = match.group(1)!;
        if (!known.contains(key)) missing.add('${entity.path}: $key');
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'unknown L.tr keys:\n${missing.join('\n')}',
    );
  });
}

void _expectNoCyrillic(String path) {
  final source = File(path).readAsStringSync();
  final cyrillic = RegExp(r'[А-Яа-яЁё]');
  final offenders = <String>[];
  var lineNo = 0;
  for (final line in source.split('\n')) {
    lineNo++;
    if (line.trimLeft().startsWith('//')) continue;
    final code = line.split('//').first;
    if (cyrillic.hasMatch(code)) offenders.add('$lineNo: ${line.trim()}');
  }
  expect(offenders, isEmpty, reason: '$path:\n${offenders.join('\n')}');
}
