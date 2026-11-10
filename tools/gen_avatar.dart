import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

/// Regenerates the app artwork (assets/ataraxy.png) and the Windows icon.
///
/// Run with: dart run tools/gen_avatar.dart
///
/// The artwork is a cream crescent moon over a pure black field, with a soft
/// warm glow behind it and a few sparkle stars. The black field is deliberate:
/// every platform icon, the native splash and the in-app avatar all sit on
/// black, so the moon reads as a floating crescent everywhere.
void main() {
  const size = 1024;
  final moon = ColorRgba8(0xFF, 0xFB, 0xF0, 255);

  // Crescent geometry: an outer disc minus an offset disc.
  const cx = 512.0, cy = 512.0, outerR = 300.0;
  const ox = 660.0, oy = 452.0, cutR = 268.0;

  // Warm glow behind the crescent.
  const glowR = 0xFF, glowG = 0xAA, glowB = 0x91;
  const glowMaxR = 430.0;

  final img = Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dOuter = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
      final dCut = math.sqrt((x - ox) * (x - ox) + (y - oy) * (y - oy));

      // Anti-aliased moon coverage: inside the outer disc, outside the cut.
      final outerIn = ((outerR + 0.5 - dOuter)).clamp(0.0, 1.0);
      final cutOut = ((dCut - cutR + 0.5)).clamp(0.0, 1.0);
      final moonA = outerIn * cutOut;

      // Radial glow fading outwards, composited over the black field.
      var r = 0.0, g = 0.0, b = 0.0;
      if (dOuter < glowMaxR) {
        final t = 1 - dOuter / glowMaxR;
        final a = 64 * math.pow(t, 1.8) / 255;
        r = glowR * a;
        g = glowG * a;
        b = glowB * a;
      }

      // Blend the moon over the glow/black backdrop.
      final pr = (r + (moon.r - r) * moonA).round().clamp(0, 255);
      final pg = (g + (moon.g - g) * moonA).round().clamp(0, 255);
      final pb = (b + (moon.b - b) * moonA).round().clamp(0, 255);
      img.setPixelRgba(x, y, pr, pg, pb, 255);
    }
  }

  // Sparkle stars: a horizontal and a vertical bar.
  void star(int x, int y, int len, int thick) {
    fillRect(img,
        x1: x - len, y1: y - thick, x2: x + len, y2: y + thick, color: moon);
    fillRect(img,
        x1: x - thick, y1: y - len, x2: x + thick, y2: y + len, color: moon);
  }

  star(800, 300, 20, 5);
  star(700, 560, 14, 4);
  star(860, 640, 17, 4);
  star(300, 760, 15, 4);
  star(560, 830, 11, 3);
  star(255, 300, 12, 3);

  File('assets/ataraxy.png')
      .writeAsBytesSync(encodePng(copyResize(img, width: 512, height: 512)));

  final ico = copyResize(img, width: 256, height: 256);
  File('windows/runner/resources/app_icon.ico')
      .writeAsBytesSync(encodeIco(ico));
}
