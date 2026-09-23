import 'package:flutter/material.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/services/notification_service.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/animated_snack.dart';
import 'package:ataraxy/widgets/volumetric_switch.dart';

class DevSettingsScreen extends StatelessWidget {
  const DevSettingsScreen({super.key});

  Widget _card(BuildContext context, {required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = SettingsProvider.of(context);
    final s = provider.settings;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(L.tr(context, 'dev'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(context, children: [
            VolumetricSwitchListTile(
              leading: const Icon(Icons.medication_rounded),
              title: L.tr(context, 'devHrtTracking'),
              value: s.devHrtTracking,
              onChanged: (v) => provider.onChanged(
                s.copyWith(devHrtTracking: v),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _card(context, children: [
            ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: Text(L.tr(context, 'devTestNotification')),
              subtitle: Text(L.tr(context, 'testNotification')),
              onTap: () async {
                final err = await NotificationService.sendTest();
                if (context.mounted) {
                  AnimatedSnack.show(
                    context,
                    err ?? '${L.tr(context, 'testNotification')} ✓',
                    type: err == null ? SnackType.success : SnackType.error,
                  );
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: Text(L.tr(context, 'devScheduleDaily')),
              subtitle: Text(L.tr(context, 'devScheduleDailyHint')),
              onTap: () async {
                final now =
                    DateTime.now().add(const Duration(minutes: 1));
                final time =
                    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                await NotificationService.scheduleDaily(
                  time,
                  'Test',
                  'Test reminder',
                );
                if (context.mounted) {
                  AnimatedSnack.show(
                    context,
                    '${L.tr(context, 'devScheduleDaily')}: $time',
                    type: SnackType.info,
                  );
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cancel_rounded),
              title: Text(L.tr(context, 'devCancelAll')),
              onTap: () async {
                await NotificationService.cancelAll();
                if (context.mounted) {
                  AnimatedSnack.show(
                    context,
                    L.tr(context, 'devCancelAll'),
                    type: SnackType.info,
                  );
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.battery_alert_rounded),
              title: Text(L.tr(context, 'devCheckPermissions')),
              subtitle: Text(L.tr(context, 'devPermissionsHint')),
              onTap: () async {
                final status =
                    await NotificationService.checkPermissions();
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(L.tr(context, 'devPermissionsTitle')),
                      content: SingleChildScrollView(
                        child: Text(status),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(L.tr(context, 'ok')),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ]),
          const SizedBox(height: 12),
          _card(context, children: [
            ListTile(
              leading: Icon(
                Icons.clear_all_rounded,
                color: scheme.error,
              ),
              title: Text(
                L.tr(context, 'devClearAllData'),
                style: TextStyle(color: scheme.error),
              ),
              subtitle: Text(L.tr(context, 'devClearAllHint')),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(L.tr(context, 'devFullReset')),
                    content: Text(L.tr(context, 'devFullResetConfirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(L.tr(context, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppAccents.danger,
                        ),
                        child: Text(L.tr(context, 'delete')),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await _clearAllData(context);
                }
              },
            ),
          ]),
        ],
      ),
    );
  }

  static Future<void> _clearAllData(BuildContext context) async {
    AnimatedSnack.show(
      context,
      L.tr(context, 'devResetTriggered'),
      type: SnackType.warning,
    );
  }
}
