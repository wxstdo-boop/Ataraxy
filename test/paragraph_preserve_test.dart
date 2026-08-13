import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  test('markdown keeps a paragraph break for a blank line', () {
    const src = 'Первый абзац\n\nВторой абзац';
    final html = md.markdownToHtml(src);
    expect(html, contains('<p>Первый абзац</p>'));
    expect(html, contains('<p>Второй абзац</p>'));
  });

  test('markdown keeps a soft break for a single newline', () {
    final html = md.markdownToHtml('Первая строка\nВторая строка');
    expect(html, contains('<p>Первая строка\nВторая строка</p>'));
  });
}
