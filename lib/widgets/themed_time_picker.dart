import 'package:flutter/material.dart';
import 'package:dream_journal/l10n/strings.dart';

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
/// The wheel picker: two vertical scrolling columns (hours 0–23, minutes
/// 0–59). Swiping a column IS the time selection — no dial gestures to
/// fight, no keyboard, no text selection, no magnifier. All colors come
/// straight from the active ColorScheme, so every theme (incl. MUTILATED)
/// renders correctly.
Future<TimeOfDay?> showThemedTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? helpText,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _TimeWheelDialog(
      initial: initialTime,
      helpText: helpText,
    ),
  );
}

class _TimeWheelDialog extends StatefulWidget {
  final TimeOfDay initial;
  final String? helpText;

  const _TimeWheelDialog({required this.initial, this.helpText});

  @override
  State<_TimeWheelDialog> createState() => _TimeWheelDialogState();
}

class _TimeWheelDialogState extends State<_TimeWheelDialog> {
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
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) {
                final sel = index == selected;
                return Center(
                  child: Text(
                    label(index),
                    style: TextStyle(
                      fontSize: sel ? 21 : 15,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
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
    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(L.tr(context, 'cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(TimeOfDay(
                    hour: _hour,
                    minute: _minute,
                  )),
                  child: Text(L.tr(context, 'ok')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
