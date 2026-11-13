import 'package:flutter/material.dart';

/// A single-select pill: the same animated container used by the entry
/// editor's category row and other filter rows.
///
/// Custom instead of a [ChoiceChip] because the selection eases (colour +
/// border + shadow) on the [AnimatedContainer] itself; the chip's internal
/// controller replays on rebuild, which flashed the PREVIOUS selection when
/// switching fast.
class SelectionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SelectionPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.35)
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        // No splash/highlight: the AnimatedContainer above owns the selected
        // state — a ripple here lingered as the previous selection's
        // background when switching fast.
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
