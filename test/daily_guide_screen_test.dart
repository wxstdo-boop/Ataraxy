import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/screens/daily_guide_screen.dart';

import 'helpers.dart';

/// Regression guard for the "белые полосы" on the dream/tulpa guide.
///
/// The guide stacks tip tiles over a page background. Both the tiles and the
/// page must be TINTED containers — a near-white surface on either one (a
/// `surfaceContainerLow` card or the scaffold wash showing through the gaps)
/// renders as a column of white stripes. This renders the screen and asserts
/// the dominant surface colour below the header stays clear of near-white.
void main() {
  setUpAll(() async => initTestStorage('guide'));
  setUp(() async => resetPrefs());

  testWidgets('guide tiles and page are tinted, never near-white',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: testApp(
            const DailyGuideScreen(topic: DailyGuideTopic.tulpa),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage());
    final data = await tester.runAsync(() => image!.toByteData());
    final bytes = data!.buffer.asUint8List();
    final width = image!.width;
    final height = image.height;

    // Sample the tip-tile region (below the gradient header), collecting the
    // most frequent opaque colour — that is the card/page surface, ignoring
    // the dark text glyphs.
    final counts = <int, int>{};
    for (var y = (height * 0.55).round(); y < height - 40; y += 3) {
      for (var x = 20; x < width - 20; x += 3) {
        final i = (y * width + x) * 4;
        final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
        final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
        // Ignore text/ink so only the surface colour remains.
        if (lum < 180) continue;
        counts[(r << 16) | (g << 8) | b] = (counts[(r << 16) | (g << 8) | b] ?? 0) + 1;
      }
    }
    image.dispose();

    expect(counts, isNotEmpty, reason: 'guide rendered no surface pixels');
    final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final r = (dominant >> 16) & 0xFF, g = (dominant >> 8) & 0xFF, b = dominant & 0xFF;
    final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
    expect(
      lum,
      lessThan(240),
      reason: 'dominant guide surface #${dominant.toRadixString(16).padLeft(6, '0')} '
          'is near-white (luminance $lum) — that is the "белые полосы" bug',
    );
  });
}
