import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

/// Regenerates the app artwork (assets/ataraxy.png) and the Windows icon.
///
/// Run with: dart run tools/gen_avatar.dart
///
/// The artwork is a cream crescent moon over a pure black field, with a soft
/// warm glow behind it and white paint splashed around the moon — drops that
/// cling to the crescent and a few thin drips running down. The black field is
/// deliberate: every platform icon, the native splash and the in-app avatar
/// all sit on black, so the moon reads as a floating crescent everywhere.
///
/// Everything is drawn at [ss]x supersampling and then box-filtered down, so
/// the crescent edge and the paint stay crisp at small avatar sizes.
void main() {
  const ss = 2; // supersample factor
  const finalSize = 1024;
  const size = finalSize * ss;

  final moon = _Rgba(0xFF, 0xFB, 0xF0);

  // Crescent geometry (in supersampled pixels).
  const s = size / finalSize;
  const cx = 512.0 * s, cy = 512.0 * s, outerR = 300.0 * s;
  const ox = 660.0 * s, oy = 452.0 * s, cutR = 268.0 * s;

  final glowR = 0xFF, glowG = 0xAA, glowB = 0x91;
  final glowMaxR = 430.0 * s;

  final img = Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dOuter = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
      final dCut = math.sqrt((x - ox) * (x - ox) + (y - oy) * (y - oy));

      final outerIn = (outerR + 0.5 - dOuter).clamp(0.0, 1.0);
      final cutOut = (dCut - cutR + 0.5).clamp(0.0, 1.0);
      final moonA = outerIn * cutOut;

      var r = 0.0, g = 0.0, b = 0.0;
      if (dOuter < glowMaxR) {
        final t = 1 - dOuter / glowMaxR;
        final a = 64 * math.pow(t, 1.8) / 255;
        r = glowR * a;
        g = glowG * a;
        b = glowB * a;
      }

      final pr = (r + (moon.r - r) * moonA).round().clamp(0, 255);
      final pg = (g + (moon.g - g) * moonA).round().clamp(0, 255);
      final pb = (b + (moon.b - b) * moonA).round().clamp(0, 255);
      img.setPixelRgba(x, y, pr, pg, pb, 255);
    }
  }

  final paint = _Canvas(img);

  // --- White paint splash around the crescent ---------------------------
  // A wobbly band of paint smeared along the outer rim (with drips running
  // down from it), plus a handful of drops — so the white reads as blood
  // flowing around the moon rather than scattered specks.
  final rnd = math.Random(7);
  const white = _Rgba(0xFF, 0xFF, 0xFF);

  // Rim flow: walk the outer circle and lay a variable-width, wobbly band
  // just outside the crescent, fading in and out at its ends.
  void rimFlow(double a0, double a1, double baseW) {
    final steps = ((a1 - a0).abs() * outerR / (3 * s)).round();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final ang = a0 + (a1 - a0) * t;
      // End taper so the band melts into the rim instead of stopping flat.
      final taper = math.sin(t * math.pi).clamp(0.0, 1.0);
      final wobble = math.sin(t * math.pi * 7) * baseW * 0.35;
      final r = outerR + baseW * (0.1 + 0.4 * taper) + wobble;
      final dx = cx + math.cos(ang) * r;
      final dy = cy + math.sin(ang) * r;
      final w = baseW * (0.25 + 0.9 * taper) * (0.7 + 0.6 * rnd.nextDouble());
      if (w < 0.6) continue;
      paint.blob(dx, dy, w, white, 0.9, rnd);
    }
  }

  rimFlow(-math.pi * 0.78, math.pi * 0.28, 11 * s);
  rimFlow(math.pi * 0.08, math.pi * 0.5, 8 * s);

  // Drops clinging to the rim, mostly where the band runs.
  for (var i = 0; i < 12; i++) {
    final ang = -math.pi * 0.75 + rnd.nextDouble() * math.pi * 1.1;
    final rad = outerR * (0.96 + rnd.nextDouble() * 0.05);
    final dx = cx + math.cos(ang) * rad;
    final dy = cy + math.sin(ang) * rad;
    final dropR = (5 + rnd.nextDouble() * 10) * s;
    paint.blob(dx, dy, dropR, white, 0.8 + rnd.nextDouble() * 0.2, rnd);
  }

  // A few drops just off the rim for a flung-paint feel — kept close.
  for (var i = 0; i < 5; i++) {
    final ang = rnd.nextDouble() * math.pi * 2;
    final rad = outerR * (1.0 + rnd.nextDouble() * 0.08);
    final dx = cx + math.cos(ang) * rad;
    final dy = cy + math.sin(ang) * rad;
    final dropR = (4 + rnd.nextDouble() * 8) * s;
    paint.blob(dx, dy, dropR, white, 0.7 + rnd.nextDouble() * 0.3, rnd);
  }

  // Drips: thin tapering streaks sliding down from the rim flow.
  for (var i = 0; i < 5; i++) {
    final ang = -math.pi * 0.7 + rnd.nextDouble() * math.pi * 0.7;
    final rad = outerR * (0.98 + rnd.nextDouble() * 0.03);
    final dx = cx + math.cos(ang) * rad;
    final dy = cy + math.sin(ang) * rad;
    paint.drip(dx, dy, (5 + rnd.nextDouble() * 6) * s,
        (30 + rnd.nextDouble() * 70) * s, white, rnd);
  }

  // Sparkle stars.
  void star(int x, int y, int len, int thick) {
    paint.rect(x - len, y - thick, x + len, y + thick, moon);
    paint.rect(x - thick, y - len, x + thick, y + len, moon);
  }

  star((800 * s).round(), (300 * s).round(), (20 * s).round(), (5 * s).round());
  star((700 * s).round(), (560 * s).round(), (14 * s).round(), (4 * s).round());
  star((860 * s).round(), (640 * s).round(), (17 * s).round(), (4 * s).round());
  star((300 * s).round(), (760 * s).round(), (15 * s).round(), (4 * s).round());
  star((560 * s).round(), (830 * s).round(), (11 * s).round(), (3 * s).round());
  star((255 * s).round(), (300 * s).round(), (12 * s).round(), (3 * s).round());

  final down = copyResize(
    img,
    width: finalSize,
    height: finalSize,
    interpolation: Interpolation.average,
  );

  File('assets/ataraxy.png')
      .writeAsBytesSync(encodePng(copyResize(down, width: 512, height: 512)));

  final ico = copyResize(down, width: 256, height: 256);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(encodeIco(ico));
}

class _Rgba {
  final int r, g, b;
  const _Rgba(this.r, this.g, this.b);
}

/// Thin blend helpers layered over an [Image] for the paint splash.
class _Canvas {
  final Image img;
  _Canvas(this.img);

  void _blend(int x, int y, _Rgba c, double a) {
    if (x < 0 || y < 0 || x >= img.width || y >= img.height || a <= 0) return;
    final p = img.getPixel(x, y);
    final na = a.clamp(0.0, 1.0);
    img.setPixelRgba(
      x,
      y,
      (p.r + (c.r - p.r) * na).round(),
      (p.g + (c.g - p.g) * na).round(),
      (p.b + (c.b - p.b) * na).round(),
      255,
    );
  }

  /// A soft, slightly irregular round drop (a few overlapping lobes so the
  /// silhouette never reads as a perfect circle).
  void blob(double cx, double cy, double r, _Rgba c, double alpha,
      math.Random rnd) {
    final lobes = 3 + rnd.nextInt(3);
    for (var i = 0; i < lobes; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final off = r * rnd.nextDouble() * 0.35;
      _disc(cx + math.cos(a) * off, cy + math.sin(a) * off,
          r * (0.7 + rnd.nextDouble() * 0.4), c, alpha);
    }
  }

  void _disc(double cx, double cy, double r, _Rgba c, double alpha) {
    final x0 = (cx - r - 1).floor(), x1 = (cx + r + 1).ceil();
    final y0 = (cy - r - 1).floor(), y1 = (cy + r + 1).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        final cov = (r + 0.5 - d).clamp(0.0, 1.0);
        if (cov > 0) _blend(x, y, c, alpha * cov);
      }
    }
  }

  /// A tapering streak that runs downward from (cx, cy) for [len] pixels,
  /// with a faint wobble so it reads as paint sliding down.
  void drip(double cx, double cy, double r0, double len, _Rgba c,
      math.Random rnd) {
    final steps = (len * 1.5).round();
    final wobbleAmp = r0 * 0.6;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final y = cy + len * t;
      final x = cx + math.sin(t * math.pi * 2) * wobbleAmp;
      final r = r0 * math.pow(1 - t, 1.4);
      if (r < 0.6) break;
      _disc(x, y, r, c, 0.92);
    }
  }

  void rect(int x1, int y1, int x2, int y2, _Rgba c) {
    for (var y = y1; y <= y2; y++) {
      for (var x = x1; x <= x2; x++) {
        _blend(x, y, c, 1.0);
      }
    }
  }
}
