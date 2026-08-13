import 'dart:io';

import 'package:image/image.dart';

void main() {
  const size = 512;
  var img = Image(width: size, height: size);

  // Мягкий персиково-розовый фон с вертикальным градиентом
  final top = ColorRgba8(0xFB, 0xB8, 0x9A, 255);
  final bottom = ColorRgba8(0xFF, 0x9F, 0xB6, 255);
  for (var y = 0; y < size; y++) {
    final t = y / (size - 1);
    final r = (top.r + (bottom.r - top.r) * t).round().clamp(0, 255);
    final g = (top.g + (bottom.g - top.g) * t).round().clamp(0, 255);
    final b = (top.b + (bottom.b - top.b) * t).round().clamp(0, 255);
    final row = ColorRgba8(r, g, b, 255);
    for (var x = 0; x < size; x++) {
      img.setPixel(x, y, row);
    }
  }

  Color bgAt(int x, int y) {
    final t = y / (size - 1);
    final r = (top.r + (bottom.r - top.r) * t).round().clamp(0, 255);
    final g = (top.g + (bottom.g - top.g) * t).round().clamp(0, 255);
    final b = (top.b + (bottom.b - top.b) * t).round().clamp(0, 255);
    return ColorRgba8(r, g, b, 255);
  }

  // Белая кремовая луна
  final moon = ColorRgba8(0xFF, 0xFB, 0xF0, 255);
  img = fillCircle(img, x: 210, y: 215, radius: 120, color: moon, antialias: true);
  // Вырезаем серп, закрашивая круг цветом фона
  for (var y = 90; y < 360; y++) {
    for (var x = 60; x < 380; x++) {
      final dx = x - 258;
      final dy = y - 180;
      if (dx * dx + dy * dy <= 108 * 108) {
        img.setPixel(x, y, bgAt(x, y));
      }
    }
  }

  // Звёзды
  final star = ColorRgba8(0xFF, 0xFF, 0xFF, 255);
  void drawStar(int cx, int cy, int len) {
    for (var i = -len; i <= len; i++) {
      img.setPixel(cx + i, cy, star);
      img.setPixel(cx, cy + i, star);
    }
  }

  drawStar(370, 140, 7);
  drawStar(330, 250, 5);
  drawStar(400, 300, 6);
  drawStar(150, 360, 5);
  drawStar(300, 380, 4);

  File('assets/ataraxy.png').writeAsBytesSync(encodePng(img));

  // Иконка приложения Windows (.ico)
  final ico = copyResize(img, width: 256, height: 256);
  File('windows/runner/resources/app_icon.ico')
      .writeAsBytesSync(encodeIco(ico));

  // Готово: assets/ataraxy.png и windows/runner/resources/app_icon.ico
}
