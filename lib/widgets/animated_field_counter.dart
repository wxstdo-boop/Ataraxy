import 'package:flutter/material.dart';

/// Smoothly cross-fading character counter for [TextField].
///
/// The stock counter snaps from "12/100" to "13/100" on every keystroke;
/// this one cross-fades the digits (180ms) so the label breathes instead of
/// flickering. Pass it directly as `TextField.buildCounter`:
///
/// ```dart
/// TextField(
///   cursorOpacityAnimates: true,
///   maxLength: 100,
///   buildCounter: animatedFieldCounter,
/// )
/// ```
Widget? animatedFieldCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) {
  if (maxLength == null) return null;
  final scheme = Theme.of(context).colorScheme;
  final style = Theme.of(context).textTheme.bodySmall?.copyWith(
    color: currentLength >= maxLength ? scheme.error : scheme.onSurfaceVariant,
  );
  return Padding(
    padding: const EdgeInsets.only(right: 12),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Stack the outgoing label under the incoming one — no layout jump
      // while the two labels cross-fade.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.centerRight,
        // Null-aware spread element: `?currentChild` adds the child only
        // when it is non-null (keeps the outgoing label under the new one).
        children: [...previousChildren, ?currentChild],
      ),
      child: Text(
        '$currentLength/$maxLength',
        key: ValueKey<int>(currentLength),
        style: style,
      ),
    ),
  );
}
