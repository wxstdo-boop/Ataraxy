import 'dart:io';

import 'package:image/image.dart' as img;

/// Regenerates the web favicon + PWA icons from the app avatar
/// (assets/ataraxy.png). Run with: dart run tools/gen_web_icons.dart
void main() {
  final source = img.decodeImage(File('assets/ataraxy.png').readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode assets/ataraxy.png');
    exit(1);
  }

  // Light lavender background used for maskable safe-zone padding.
  final bg = img.ColorRgba8(0xF6, 0xF3, 0xFC, 255);

  void writeFilled(String path, int size) {
    final resized = img.copyResize(
      source,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    File(path).writeAsBytesSync(img.encodePng(resized));
  }

  void writeMaskable(String path, int size) {
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: bg);
    final inner = (size * 0.8).round();
    final resized = img.copyResize(
      source,
      width: inner,
      height: inner,
      interpolation: img.Interpolation.cubic,
    );
    img.compositeImage(
      canvas,
      resized,
      dstX: (size - inner) ~/ 2,
      dstY: (size - inner) ~/ 2,
    );
    File(path).writeAsBytesSync(img.encodePng(canvas));
  }

  writeFilled('web/favicon.png', 32);
  writeFilled('web/icons/Icon-192.png', 192);
  writeFilled('web/icons/Icon-512.png', 512);
  writeFilled('web/icons/apple-touch-icon.png', 180);
  writeMaskable('web/icons/Icon-maskable-192.png', 192);
  writeMaskable('web/icons/Icon-maskable-512.png', 512);

  stdout.writeln('Web icons generated from assets/ataraxy.png');
}
