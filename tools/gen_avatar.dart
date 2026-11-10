import 'dart:io';

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

  // Pure black field.
  var img = Image(width: size, height: size);
  final black = ColorRgba8(0, 0, 0, 255);
  fill(img, color: black);

  final moon = ColorRgba8(0xFF, 0xFB, 0xF0, 255);

  // Soft warm glow behind the crescent.
  final glow = ColorRgba8(0xFF, 0xAA, 0x91, 255);
  for (var i = 220; i > 0; i--) {
    final r = 400 * i / 220;
    final a = (58 * (1 - i / 220)).round();
    fillCircle(
      img,
      x: 512,
      y: 512,
      radius: r,
      color: glow.withAlpha(a),
      antialias: true,
    );
  }

  // Crescent: outer disc minus an offset disc.
  const outerR = 300, cutR = 268, ox = 660, oy = 452;
  fillCircle(img, x: 512, y: 512, radius: outerR, color: moon, antialias: true);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - ox, dy = y - oy;
      if (dx * dx + dy * dy <= cutR * cutR) {
        img.setPixel(x, y, black);
      }
    }
  }

  // Sparkle stars.
  void star(int cx, int cy, int len, int thick) {
    fillRect(img,
        x1: cx - len, y1: cy - thick, x2: cx + len, y2: cy + thick,
        color: moon);
    fillRect(img,
        x1: cx - thick, y1: cy - len, x2: cx + thick, y2: cy + len,
        color: moon);
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
