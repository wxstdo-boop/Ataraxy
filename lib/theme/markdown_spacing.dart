import 'package:flutter/material.dart';

/// Paragraph spacing for every `MarkdownBody` in the app.
///
/// `MarkdownStyleSheet.blockSpacing` is the TOTAL vertical gap between two
/// paragraph blocks. If that gap is not clearly larger than the in-paragraph
/// line leading, a blank-line paragraph break reads as an ordinary line break
/// and the paragraphs merge ("не разделяются абзацы"). The library default
/// (8px) is far below the line leading at the body styles used here
/// (`height` 1.4–1.6 on 14–16px), so the gap must be derived from the style,
/// not hard-coded.
///
/// Returns [factor] × the paragraph's line box (`fontSize * height`).
double markdownBlockSpacing(TextStyle? style, {double factor = 1.25}) {
  final size = style?.fontSize ?? 16;
  final height = style?.height ?? 1.5;
  return size * height * factor;
}
