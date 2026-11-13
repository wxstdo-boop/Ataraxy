import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/press_scale.dart';

/// A fully themed, iOS-style wheel time picker used everywhere in the app.
///
/// Replaces the stock Material `showTimePicker`, which had a string of
/// problems on this app's themes and on MIUI/Redmi:
///  * the dial mode only responds to circular drags — plain swipes did
///    nothing, which read as "the time won't spin";
///  * its keyboard-entry fields fought the IME (the second digit wouldn't
///    type), and showed the system selection magnifier + the "Ask Copilot"
///    toolbar;
///  * a wrong `hourMinuteColor` made the digits invisible on some themes.
///
/// It now rises from the bottom as a rounded PLATE (плашка) instead of a
/// centred window ("пусть вылазит плашкой, а не отдельным окном") — the modal
/// sheet's own slide-up transition gives the smooth pop-in for free.
///
/// The wheel picker: two vertical scrolling columns (hours 0–23, minutes
/// 0–59). Swiping a column IS the time selection — no dial gestures to fight,
/// no keyboard, no text selection, no magnifier. All colors come straight
/// from the active ColorScheme, so every theme (incl. MUTILATED) renders
/// correctly.
Future<TimeOfDay?> showThemedTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? helpText,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    // The plate can grow taller than the default sheet cap on small screens.
    isScrollControlled: true,
    builder: (_) => _TimeWheelSheet(
      initial: initialTime,
      helpText: helpText,
    ),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  final TimeOfDay initial;
  final String? helpText;

  const _TimeWheelSheet({required this.initial, this.helpText});

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  static const double _itemExtent = 42;
  static const double _wheelHeight = 5 * _itemExtent; // 5 visible rows

  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: widget.initial.hour);
    _minuteCtrl =
        FixedExtentScrollController(initialItem: widget.initial.minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  Widget _wheel({
    required int count,
    required int selected,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
    required String Function(int) label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _wheelHeight,
      width: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Highlight pill behind the selected row.
          Container(
            width: 74,
            height: _itemExtent - 8,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: _itemExtent,
            diameterRatio: 1.4,
            useMagnifier: false,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) {
              // A soft tick as each row snaps under the highlight — the
              // "smooth selection" feel the wheel was missing.
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) {
                final sel = index == selected;
                // AnimatedDefaultTextStyle eases the size/weight/colour as a
                // row takes or gives up the highlight, so the digits swell and
                // settle instead of snapping between two styles.
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: sel ? 21 : 15,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    child: Text(label(index)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The rounded plate: only the top corners are rounded, a grab handle
    // signals "draggable sheet", and a safe-area pad keeps the actions clear
    // of the home indicator.
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle: a translucent red bar so it reads as the drag /
          // position marker ("верхний маркер — полупрозрачный красный").
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppAccents.danger.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (widget.helpText != null && widget.helpText!.isNotEmpty) ...[
            Text(
              widget.helpText!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _wheel(
                count: 24,
                selected: _hour,
                controller: _hourCtrl,
                onChanged: (i) => setState(() => _hour = i),
                label: (i) => i.toString().padLeft(2, '0'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              _wheel(
                count: 60,
                selected: _minute,
                controller: _minuteCtrl,
                onChanged: (i) => setState(() => _minute = i),
                label: (i) => i.toString().padLeft(2, '0'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Cancel/OK get the same soft press dimple as the rest of the
              // app's controls (the sheet's own buttons were the only flat,
              // ripple-only taps left). Shallow (0.97) and NOT symmetric — the
              // soft, slower recoil is what every other control uses; a
              // symmetric snap here read as a jolt on the short button.
              PressScale(
                scale: 0.97,
                duration: const Duration(milliseconds: 150),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(L.tr(context, 'cancel')),
                ),
              ),
              const SizedBox(width: 8),
              PressScale(
                scale: 0.97,
                duration: const Duration(milliseconds: 150),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    TimeOfDay(hour: _hour, minute: _minute),
                  ),
                  child: Text(L.tr(context, 'ok')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
