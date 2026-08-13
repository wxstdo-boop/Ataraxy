import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dream_journal/l10n/strings.dart';
import 'package:dream_journal/models/settings.dart';
import 'package:dream_journal/widgets/animated_snack.dart';
import 'package:dream_journal/services/notification_service.dart';
import 'package:dream_journal/widgets/volumetric_switch.dart';
import 'package:dream_journal/widgets/limited_context_menu.dart';
import 'package:dream_journal/widgets/themed_time_picker.dart';

class ReminderDialog extends StatefulWidget {
  final AppSettings settings;

  const ReminderDialog({super.key, required this.settings});

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late bool _enabled;
  TimeOfDay? _time;
  final _text = TextEditingController();
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.reminderEnabled;
    _time = widget.settings.reminderTime == null
        ? null
        : _parseTime(widget.settings.reminderTime!);
    _text.text = widget.settings.reminderText ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String v) {
    final parts = v.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// True when the chosen time has already passed today — the daily
  /// reminder then first fires tomorrow (scheduleDaily bumps it a day).
  bool get _firstFireTomorrow {
    final t = _time;
    if (t == null) return false;
    final now = TimeOfDay.now();
    return t.hour < now.hour ||
        (t.hour == now.hour && t.minute <= now.minute);
  }

  Future<void> _pickTime() async {
    final picked = await showThemedTimePicker(
      context,
      initialTime: _time ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L.tr(context, 'reminders')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(L.tr(context, 'reminders')),
              subtitle: _enabled && (_time == null || _text.text.trim().isEmpty)
                  ? Text(
                      L.tr(context, 'reminderRequired'),
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    )
                  : null,
              trailing: VolumetricSwitch(
                value: _enabled,
                onChanged: (v) {
                  if (v && (_time == null || _text.text.trim().isEmpty)) {
                    AnimatedSnack.show(
                      context,
                      L.tr(context, 'reminderRequired'),
                      type: SnackType.warning,
                      duration: const Duration(seconds: 2),
                    );
                    return;
                  }
                  setState(() => _enabled = v);
                },
              ),
              onTap: () {
                final newV = !_enabled;
                if (newV && (_time == null || _text.text.trim().isEmpty)) {
                  AnimatedSnack.show(
                    context,
                    L.tr(context, 'reminderRequired'),
                    type: SnackType.warning,
                    duration: const Duration(seconds: 2),
                  );
                  return;
                }
                setState(() => _enabled = newV);
              },
            ),
            // Кнопка проверки разрешений — показывается если включено напоминание.
            // AnimatedSize + FadeTransition дают плавное появление блока
            // (раньше он просто "впрыгивал" при включении переключателя).
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _enabled
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - v)),
                          child: child,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                            ),
                            title: Text(L.tr(context, 'permissions')),
                            subtitle: const Text('Проверить разрешения'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              final result =
                                  await NotificationService
                                      .requestAllPermissions();
                              if (mounted) {
                                AnimatedSnack.show(
                                  context,
                                  result.contains('ОТКЛОНЕНО')
                                      ? 'Проверьте разрешения'
                                      : 'Разрешения OK',
                                  type: result.contains('ОТКЛОНЕНО')
                                      ? SnackType.warning
                                      : SnackType.success,
                                );
                              }
                            },
                          ),
                          // MIUI/Xiaomi/Redmi hint: autostart + battery saver
                          // cannot be granted via API — the user has to flip
                          // them in system settings or the process gets killed
                          // in the background and reminders never fire.
                          if (kIsWeb) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.language_rounded,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      L.tr(context, 'webHint'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (Platform.isAndroid) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.phone_android_rounded,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      L.tr(context, 'miuiHint'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_rounded),
              title: Text(_time == null
                  ? L.tr(context, 'reminderTime')
                  : _time!.format(context)),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: _pickTime,
            ),
            // The chosen time may already be past for today — the daily
            // reminder then fires first tomorrow. Say so explicitly, otherwise
            // "it didn't fire at the set time" looks like a bug.
            if (_enabled && _time != null && _firstFireTomorrow) ...[
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      L.tr(context, 'reminderNextFire', params: {
                        'time': _fmt(_time!),
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            TextField(
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
              controller: _text,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: L.tr(context, 'reminderHint'),
                errorText: _error ? L.tr(context, 'reminderRequired') : null,
                counterText: '',
              ),
              onChanged: (_) => setState(() => _error = false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.tr(context, 'cancel')),
        ),
        TextButton(
          onPressed: () {
            if (_enabled && (_time == null || _text.text.trim().isEmpty)) {
              setState(() => _error = true);
              return;
            }
            final next = widget.settings.copyWith(
              reminderEnabled: _enabled,
              reminderTime: _time == null ? null : _fmt(_time!),
              reminderText:
                  _text.text.trim().isEmpty ? null : _text.text.trim(),
            );
            Navigator.pop(context, next);
          },
          child: Text(L.tr(context, 'save')),
        ),
      ],
    );
  }
}
