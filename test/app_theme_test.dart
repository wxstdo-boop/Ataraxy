import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/theme/app_theme.dart';

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('every theme mode builds a light and a dark ThemeData', () {
    for (final mode in AppThemeMode.values) {
      expect(AppTheme.of(mode), isA<ThemeData>(), reason: '$mode light');
      expect(AppTheme.darkOf(mode), isA<ThemeData>(), reason: '$mode dark');
    }
  });

  test('Grok keeps a wide tonal range instead of one flat grey', () {
    final s = AppTheme.darkGrok().colorScheme;
    // Grok's identity is monochrome, so "not monotonous" here means the three
    // accents span a real lightness range (dark charcoal -> mid graphite ->
    // lighter taupe) rather than sitting on one tone.
    final ls = [
      HSLColor.fromColor(s.primary).lightness,
      HSLColor.fromColor(s.secondary).lightness,
      HSLColor.fromColor(s.tertiary).lightness,
    ];
    final range = ls.reduce((a, b) => a > b ? a : b) -
        ls.reduce((a, b) => a < b ? a : b);
    expect(range, greaterThan(0.15));
    // The tertiary is warm (taupe) against the cool charcoal — a deliberate
    // accent, not another grey.
    final primaryHue = HSLColor.fromColor(s.primary).hue;
    final tertiaryHue = HSLColor.fromColor(s.tertiary).hue;
    expect((tertiaryHue - primaryHue).abs(), greaterThan(60));
  });

  test('the Grok header stays legible against its title text', () {
    final theme = AppTheme.darkGrok();
    final scheme = theme.colorScheme;
    // White-ish title over a charcoal bar: contrast must clear WCAG AA for
    // large text (3:1) with room to spare.
    expect(
      _contrast(scheme.onPrimary, scheme.primary),
      greaterThan(4.5),
    );
  });

  test('MUTILATED exposes three distinct accent hues', () {
    final s = AppTheme.lightMutilated().colorScheme;
    final hues = [
      HSLColor.fromColor(s.primary).hue,
      HSLColor.fromColor(s.secondary).hue,
      HSLColor.fromColor(s.tertiary).hue,
    ];
    // Blood / plum / aged-gold: at least 20° apart from each other.
    for (var i = 0; i < hues.length; i++) {
      for (var j = i + 1; j < hues.length; j++) {
        final d = (hues[i] - hues[j]).abs();
        final sep = d > 180 ? 360 - d : d;
        expect(sep, greaterThan(20), reason: 'hues $i and $j too close');
      }
    }
  });
}
