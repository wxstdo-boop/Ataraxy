import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/splash_content.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/animated_letters.dart';
import 'package:ataraxy/widgets/press_scale.dart';

void main() {
  testWidgets('AnimatedLetters renders one widget per glyph and settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AnimatedLetters('Ataraxy.')),
        ),
      ),
    );
    // One Text per character (8 glyphs in "Ataraxy.").
    expect(find.byType(Text), findsNWidgets('Ataraxy.'.length));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedLetters), findsOneWidget);
  });

  testWidgets('AnimatedLetters actually reveals every glyph over time', (
    tester,
  ) async {
    // Regression: the glyph widgets used to be built OUTSIDE the
    // AnimatedBuilder, so each letter's opacity froze at the first frame
    // (0) and the wordmark never faded in — the "Ataraxy пропал" bug.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AnimatedLetters('Ataraxy.')),
        ),
      ),
    );

    double minOpacity() => tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(AnimatedLetters),
            matching: find.byType(Opacity),
          ),
        )
        .map((o) => o.opacity)
        .reduce((a, b) => a < b ? a : b);

    double maxOpacity() => tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(AnimatedLetters),
            matching: find.byType(Opacity),
          ),
        )
        .map((o) => o.opacity)
        .reduce((a, b) => a > b ? a : b);

    // First frame: nothing visible yet.
    expect(minOpacity(), 0.0);
    expect(maxOpacity(), 0.0);
    // Mid-flight: the leading glyphs have started fading in.
    await tester.pump(const Duration(milliseconds: 200));
    expect(maxOpacity(), greaterThan(0.0));
    // Settled: every glyph fully visible.
    await tester.pumpAndSettle();
    expect(minOpacity(), 1.0);
  });

  testWidgets('SplashContent paints the italic wordmark with the wave', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightMaterialYou(),
        home: SplashContent(
          opacity: const AlwaysStoppedAnimation(1.0),
          contentOpacity: const AlwaysStoppedAnimation(1.0),
          // The comet spinner repeats forever, so settle by pumping frames
          // rather than pumpAndSettle (which would time out).
          spinning: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // The wordmark is rendered glyph-by-glyph.
    expect(find.byType(AnimatedLetters), findsOneWidget);
    // The wordmark carries the trailing period.
    expect(find.text('.'), findsOneWidget);
  });

  testWidgets('CometSpinner paints without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CometSpinner(size: 46))),
      ),
    );
    // It repeats forever, so settle by pumping a couple of frames instead.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CometSpinner), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('PressScale dimples while held and springs back on release', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressScale(
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );

    AnimatedScale scaleWidget() => tester.widget<AnimatedScale>(
          find.descendant(
            of: find.byType(PressScale),
            matching: find.byType(AnimatedScale),
          ),
        );

    expect(scaleWidget().scale, 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pump();
    expect(scaleWidget().scale, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleWidget().scale, 1.0);
  });
}
