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

  test('a blank line becomes a real <p>, so the renderer can space it', () {
    // The reading/editor views render through flutter_markdown, which maps
    // each top-level <p> to a Paragraph with `blockSpacing` between them. The
    // parser must therefore emit a SEPARATE <p> per blank-line block (a
    // collapsed <br> would give the renderer nothing to space).
    final html = md.markdownToHtml('A\n\nB\n\nC');
    expect(RegExp(r'<p>').allMatches(html).length, 3);
    expect(html, isNot(contains('<br')));
  });
}
