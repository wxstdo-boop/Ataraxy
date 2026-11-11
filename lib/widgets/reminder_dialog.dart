import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/animated_snack.dart';
import 'package:ataraxy/services/notification_service.dart';
import 'package:ataraxy/widgets/volumetric_switch.dart';
import 'package:ataraxy/widgets/limited_context_menu.dart';
import 'package:ataraxy/widgets/press_scale.dart';
import 'package:ataraxy/widgets/themed_time_picker.dart';

class ReminderDialog extends StatefulWidget {
  final AppSettings settings;

  const ReminderDialog({super.key, required this.settings});

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog>
    with SingleTickerProviderStateMixin {
  late bool _enabled;
  TimeOfDay? _time;
  final _text = TextEditingController();
  bool _error = false;

  /// Drives the reveal/collapse of the time + text group. A real controller
  /// (not a one-shot TweenAnimationBuilder) so it animates BOTH ways: the group
  /// fades/slides in when the reminder is switched on and melts away when it is
  /// switched off.
  late final AnimationController _reveal;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.reminderEnabled;
    _time = widget.settings.reminderTime == null
        ? null
        : _parseTime(widget.settings.reminderTime!);
    _text.text = widget.settings.reminderText ?? '';
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _enabled ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _setEnabled(bool value) {
    setState(() => _enabled = value);
    if (value) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
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
    return t.hour < now.hour || (t.hour == now.hour && t.minute <= now.minute);
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
      // Fixed-width content (maxFinite) so the dialog never widens/narrows as
      // the enabled block slides in — that width change was the "окно
      // расширяется по бокам и обратно дёргано". Only the HEIGHT animates.
      // Plain Column, NOT a SingleChildScrollView: the dialog content must not
      // scroll ("пусть внутри содержимое там не листается").
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(L.tr(context, 'reminders')),
              trailing: VolumetricSwitch(
                value: _enabled,
                // Toggling ALWAYS flips the switch. The old version refused to
                // move whenever the time/text were not filled yet, so after
                // typing the text the switch still looked dead — the reminder
                // was silently blocked by a missing TIME. Validation now happens
                // on Save (with the inline warning below); the toggle itself is
                // never a no-op.
                onChanged: _setEnabled,
              ),
              onTap: () => _setEnabled(!_enabled),
            ),
            // Validation hint: fades + slides in/out instead of popping
            // ("текст уведомления должен появляться и исчезать плавно").
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _enabled && (_time == null || _text.text.trim().isEmpty)
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 15,
                            color: AppAccents.amber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              L.tr(context, 'reminderRequired'),
                              style: const TextStyle(
                                color: AppAccents.amber,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
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
                              color: AppAccents.sage,
                            ),
                            title: Text(L.tr(context, 'permissions')),
                            subtitle: Text(L.tr(context, 'checkPermissionsAction')),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              final result =
                                  await NotificationService
                                      .requestAllPermissions();
                              if (context.mounted) {
                                final denied = result.contains('ОТКЛОНЕНО');
                                AnimatedSnack.show(
                                  context,
                                  L.tr(
                                    context,
                                    denied
                                        ? 'permissionsCheckFailed'
                                        : 'permissionsOk',
                                  ),
                                  type: denied
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
            // The time row + notification-text field only make sense while the
            // reminder is ON, so they REVEAL (fade + slide + size) when it is
            // switched on and melt away when it is switched off — instead of
            // snapping in/out ("текст уведомления появляется и исчезает
            // плавно"). A persistent fade controller drives opacity/slide, so
            // both the reveal AND the collapse are smooth.
            ClipRect(
              child: AnimatedBuilder(
                animation: _reveal,
                builder: (context, child) => Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _reveal.value,
                  child: Opacity(
                    opacity: _reveal.value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - _reveal.value)),
                      child: child,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_rounded),
                      // The chosen time cross-fades when it changes, so picking
                      // a new one eases in instead of snapping.
                      title: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          _time == null
                              ? L.tr(context, 'reminderTime')
                              : _time!.format(context),
                          key: ValueKey(_time?.toString() ?? 'none'),
                        ),
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: _pickTime,
                    ),
                    // The chosen time may already be past for today — the daily
                    // reminder then fires first tomorrow. Say so explicitly,
                    // otherwise "it didn't fire at the set time" looks like a
                    // bug.
                    if (_time != null && _firstFireTomorrow) ...[
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              L.tr(
                                context,
                                'reminderNextFire',
                                params: {'time': _fmt(_time!)},
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    TextField(
                      cursorOpacityAnimates: true,
                      magnifierConfiguration:
                          TextMagnifierConfiguration.disabled,
                      contextMenuBuilder: (ctx, state) =>
                          buildLimitedContextMenu(ctx, state),
                      controller: _text,
                      maxLength: 50,
                      decoration: InputDecoration(
                        hintText: L.tr(context, 'reminderHint'),
                        errorText:
                            _error ? L.tr(context, 'reminderRequired') : null,
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() => _error = false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        PressScale(
          scale: 0.92,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L.tr(context, 'cancel')),
          ),
        ),
        PressScale(
          scale: 0.92,
          child: TextButton(
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
        ),
      ],
    );
  }
}
