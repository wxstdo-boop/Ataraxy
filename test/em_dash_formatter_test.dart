import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/widgets/em_dash_formatter.dart';

void main() {
  const formatter = EmDashInputFormatter();

  TextEditingValue format(String text) {
    return formatter.formatEditUpdate(
      const TextEditingValue(),
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  test('converts a dash between words to an em dash', () {
    expect(format('Привет - как дела').text, 'Привет — как дела');
  });

  test('converts a trailing dash to an em dash', () {
    expect(format('Итог -').text, 'Итог —');
  });

  test('keeps double/triple dashes untouched', () {
    expect(format('a--b').text, 'a--b');
    expect(format('---').text, '---');
  });

  test('keeps markdown list item at line start', () {
    expect(format('- первый пункт').text, '- первый пункт');
    expect(format('текст\n- второй').text, 'текст\n- второй');
  });

  test('keeps hyphen inside a compound word', () {
    expect(format('по-русски').text, 'по-русски');
  });

  test('leaves plain text without dashes alone', () {
    expect(format('Обычный текст без тире').text, 'Обычный текст без тире');
  });
}
