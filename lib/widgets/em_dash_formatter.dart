import 'package:flutter/services.dart';

/// Converts ASCII hyphens used as punctuation into a proper em dash (—):
///   " - "  →  " — "
///   " -- " →  " — "
///   " -"  at the end of text → " —"
/// Markdown list items ("- " at the start of a line) and hyphens inside
/// words ("что-то", "2024-08-10") are left untouched.
String emDash(String text) {
  if (!text.contains('-')) return text;
  return text
      .replaceAll(' -- ', ' — ')
      .replaceAll(' - ', ' — ')
      .replaceAll(RegExp(r' -$'), ' —');
}

/// [TextInputFormatter] twin of [emDash] — applies the same conversion live
/// while the user types in the entry editor.
class EmDashInputFormatter extends TextInputFormatter {
  const EmDashInputFormatter();

  static final RegExp _dashSpace = RegExp(r' - ');
  static final RegExp _dashDashSpace = RegExp(r' -- ');
  static final RegExp _trailingDash = RegExp(r' -$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.contains('-')) return newValue;
    final text = newValue.text
        .replaceAll(_dashDashSpace, ' — ')
        .replaceAll(_dashSpace, ' — ')
        .replaceAll(_trailingDash, ' —');
    if (text == newValue.text) return newValue;
    // Keep the caret roughly where it was (the replacement shortens text).
    final offset = text.length - newValue.text.length;
    final caret = (newValue.selection.baseOffset + offset).clamp(
      0,
      text.length,
    );
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
