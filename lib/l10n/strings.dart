import 'package:flutter/material.dart';

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

  /// Same as [tr] but without a [BuildContext] — for code that runs outside
  /// the widget tree (e.g. an AI controller). Falls back to Russian.
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
