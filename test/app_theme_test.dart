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

  test('cards carry depth: a hairline rim plus a soft shadow', () {
    // The feed used to be flat same-tone fills; every theme now gives cards a
    // hairline rim and a soft drop shadow so they lift off the background.
    for (final mode in AppThemeMode.values) {
      final theme = AppTheme.of(mode);
      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>(), reason: '$mode');
      final side = (shape! as RoundedRectangleBorder).side;
      expect(side.width, greaterThan(0), reason: '$mode rim');
      expect(side.color.a, greaterThan(0), reason: '$mode rim alpha');
      expect(theme.cardTheme.shadowColor!.a, greaterThan(0), reason: '$mode');
    }
  });

  test('input fields keep a visible rim in every theme', () {
    for (final mode in AppThemeMode.values) {
      final theme = AppTheme.of(mode);
      final border =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder?;
      expect(border, isNotNull, reason: '$mode');
      expect(border!.borderSide.color.a, greaterThan(0), reason: '$mode');
    }
  });

  test('near-white surfaces are not used where a tinted plate is required', () {
    // Guards the recurring "белые полосы": on the light themes `surface` and
    // `surfaceContainerLowest` land near-neutral white while the scaffold
    // keeps the theme tint, so anything filled with them reads as a white
    // slab. Card/dialog/sheet-like plates must use a tinted container.
    for (final mode in AppThemeMode.values) {
      final theme = AppTheme.of(mode);
      if (theme.colorScheme.brightness != Brightness.light) continue;
      final scheme = theme.colorScheme;
      final scaffold = theme.scaffoldBackgroundColor.computeLuminance();
      for (final plate in <String, Color>{
        'cardTheme': theme.cardTheme.color ?? scheme.surfaceContainerHighest,
        'dialogTheme': theme.dialogTheme.backgroundColor ??
            scheme.surfaceContainerHigh,
        'bottomSheetTheme':
            theme.bottomSheetTheme.backgroundColor ?? scheme.surfaceContainerHigh,
      }.entries) {
        // A plate within a hair of the tinted scaffold but far from it in
        // luminance would be the white-slab bug; require it to stay off the
        // near-white band (>=0.90 luminance) OR be no brighter than scaffold.
        final lum = plate.value.computeLuminance();
        expect(
          lum < 0.90 || lum <= scaffold,
          isTrue,
          reason: '$mode ${plate.key} is a near-white slab '
              '(lum=${lum.toStringAsFixed(3)}, scaffold='
              '${scaffold.toStringAsFixed(3)})',
        );
      }
    }
  });

  test('Grok keeps its stark monochrome identity', () {
    final s = AppTheme.darkGrok().colorScheme;
    // Grok is deliberately monochrome: primary and secondary share a near
    // neutral hue, and the accent is not a saturated colour.
    final primarySat = HSLColor.fromColor(s.primary).saturation;
    expect(primarySat, lessThan(0.2));
  });

  test('the Grok header stays legible against its title text', () {
    final theme = AppTheme.darkGrok();
    final scheme = theme.colorScheme;
    // White-ish title over a charcoal bar: contrast must clear WCAG AA for
    // large text (3:1) with room to spare.
    expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
  });

  test('MUTILATED keeps its blood-red identity', () {
    final s = AppTheme.lightMutilated().colorScheme;
    // The primary stays in the red family (hue ~0-20 or ~340-360).
    final hue = HSLColor.fromColor(s.primary).hue;
    final inRedFamily = hue < 30 || hue > 330;
    expect(inRedFamily, isTrue, reason: 'primary hue $hue not red');
  });
}
