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

  test('every message exists in every locale', () {
    final byLang = {for (final l in languages) l: loadArb(l)};
    final reference = byLang['ru']!.keys.toSet();

    for (final lang in languages.skip(1)) {
      expect(
        byLang[lang]!.keys.toSet(),
        reference,
        reason: 'app_$lang.arb diverges from app_ru.arb',
      );
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
}
