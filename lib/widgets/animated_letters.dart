import 'package:flutter/material.dart';

/// Renders [text] one glyph at a time, each fading and sliding in on a short
/// stagger. Used for the brand wordmark so "Ataraxy" writes itself on instead
/// of popping in as a block.
///
/// Words are laid out in a [Wrap] so long strings still wrap normally, and
/// each word is a [Row] of individually animated glyphs — so the text breaks
/// at word boundaries (never mid-word) while every letter still animates on
/// its own.
class AnimatedLetters extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final double slide;
  final Curve curve;
  final WrapAlignment alignment;

  const AnimatedLetters(
    this.text, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 420),
    this.delay = const Duration(milliseconds: 45),
    this.slide = 8,
    this.curve = Curves.easeOutCubic,
    this.alignment = WrapAlignment.center,
  });

  @override
  State<AnimatedLetters> createState() => _AnimatedLettersState();
}

class _AnimatedLettersState extends State<AnimatedLetters>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _play();
  }

  @override
  void didUpdateWidget(covariant AnimatedLetters old) {
    super.didUpdateWidget(old);
    // Re-run the stagger whenever the visible text changes (e.g. a language
    // switch swaps the string) so the new glyphs write themselves in too.
    if (old.text != widget.text) {
      _controller.reset();
      _play();
    }
  }

  void _play() {
    final letters = widget.text.replaceAll(' ', '').length;
    _controller.duration = widget.duration + widget.delay * letters;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.text.split(' ');
    final total = widget.text.replaceAll(' ', '').length;
    // Running letter index so the stagger flows across word boundaries
    // instead of restarting on every word.
    var index = 0;
    final rows = <Widget>[];
    for (final word in words) {
      final letters = <Widget>[];
      for (final ch in word.characters) {
        letters.add(
          _Letter(
            char: ch,
            style: widget.style,
            slide: widget.slide,
            progress: _letterProgress(index, total),
            curve: widget.curve,
          ),
        );
        index++;
      }
      rows.add(Row(mainAxisSize: MainAxisSize.min, children: letters));
    }

    return Semantics(
      label: widget.text,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Wrap(
            alignment: widget.alignment,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: (widget.style?.fontSize ?? 16) * 0.28,
            children: rows,
          );
        },
      ),
    );
  }

  /// Each letter owns a slice of the timeline; slices overlap because
  /// [delay] is shorter than [duration].
  double _letterProgress(int index, int count) {
    final total = widget.duration + widget.delay * (count - 1);
    if (total.inMicroseconds <= 0) return 1;
    final start = widget.delay * index;
    final end = start + widget.duration;
    final t = _controller.value * total.inMicroseconds;
    return ((t - start.inMicroseconds) / (end - start).inMicroseconds)
        .clamp(0.0, 1.0);
  }
}

class _Letter extends StatelessWidget {
  final String char;
  final TextStyle? style;
  final double slide;
  final double progress;
  final Curve curve;

  const _Letter({
    required this.char,
    required this.style,
    required this.slide,
    required this.progress,
    required this.curve,
  });

  @override
  Widget build(BuildContext context) {
    final t = curve.transform(progress);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * slide),
        child: Text(char, style: style),
      ),
    );
  }
}
