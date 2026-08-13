import 'package:flutter/material.dart';

/// A vertical list of options where a highlighted pill smoothly slides from
/// the currently selected option to the tapped one. Used for theme and
/// language pickers so the selection visibly glides between buttons.
class SlidingSelector<T> extends StatelessWidget {
  final List<T> values;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(BuildContext context, T value) labelOf;

  /// Optional tiny pill shown next to a row's label (e.g. the
  /// "ELEGANT-USER" tag on the MUTILATED theme).
  final String? Function(BuildContext context, T value)? badgeOf;

  const SlidingSelector({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.badgeOf,
  });

  static const double _rowHeight = 52;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final index = values.indexOf(value);
    final totalHeight =
        values.length * _rowHeight + (values.length - 1) * _gap;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // The sliding highlight pill, animated between option positions.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            top: index * (_rowHeight + _gap),
            left: 0,
            right: 0,
            height: _rowHeight,
            // Filled with the theme's primary color (black in Grok, purple in
            // lavender, etc.) — a bold, Grok-style highlight instead of the
            // washed-out container fill.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) const SizedBox(height: _gap),
                SizedBox(
                  height: _rowHeight,
                  child: InkWell(
                    onTap: () => onChanged(values[i]),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Label + badge live together inside one Expanded so
                          // the badge hugs the text and the checkmark on the
                          // right NEVER shoves them around (no jumping).
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: AnimatedDefaultTextStyle(
                                    duration:
                                        const Duration(milliseconds: 250),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: i == index
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: i == index
                                          ? scheme.onPrimary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    child: Text(
                                      labelOf(context, values[i]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (badgeOf != null)
                                  Builder(builder: (context) {
                                    final badge = badgeOf!(context, values[i]);
                                    if (badge == null || badge.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    final selected = i == index;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? scheme.onPrimary
                                                  .withValues(alpha: 0.16)
                                              : scheme.primary
                                                  .withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: selected
                                                ? scheme.onPrimary
                                                    .withValues(alpha: 0.35)
                                                : scheme.primary
                                                    .withValues(alpha: 0.45),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          badge,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: selected
                                                ? scheme.onPrimary
                                                : scheme.primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                          // Checkmark always reserves its slot: it fades in /
                          // out in place instead of appearing/disappearing,
                          // so the label+badge never jump sideways.
                          SizedBox(
                            width: 20,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 250),
                              opacity: i == index ? 1 : 0,
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
