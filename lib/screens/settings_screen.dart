import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/widgets/animated_field_counter.dart';
import 'package:ataraxy/widgets/app_route.dart';
import 'package:ataraxy/widgets/press_scale.dart';
import 'package:ataraxy/widgets/pressable_icon_button.dart';
import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/screens/about_screen.dart';
import 'package:ataraxy/screens/dev_settings_screen.dart';
import 'package:ataraxy/services/storage_service.dart';
import 'package:ataraxy/services/notification_service.dart';
import 'package:ataraxy/services/settings_service.dart';
import 'package:ataraxy/services/ai_service.dart';
import 'package:ataraxy/services/auto_export_service.dart';
import 'package:ataraxy/services/github_update_service.dart';
import 'package:ataraxy/widgets/reminder_dialog.dart';
import 'package:ataraxy/widgets/animated_snack.dart';
import 'package:ataraxy/widgets/sliding_selector.dart';
import 'package:ataraxy/widgets/volumetric_switch.dart';
import 'package:ataraxy/widgets/app_avatar.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/limited_context_menu.dart';
import 'package:ataraxy/widgets/premium_header.dart';

part 'settings_pin_dialogs.dart';
part 'settings_key_rows.dart';
part 'settings_painters.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoExportEnabled = false;
  bool _isUpdating = false;
  double? _updateProgress;
  String? _updateMessage;
  late final GithubUpdateService _updateService = GithubUpdateService(
    currentVersion: const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.3.5',
    ),
  );
  static const _updateChannel = MethodChannel('ataraxy/updates');

  @override
  void initState() {
    super.initState();
    _loadAutoExportState();
  }

  @override
  void dispose() {
    _updateService.close();
    super.dispose();
  }
  
  Future<void> _loadAutoExportState() async {
    final service = AutoExportService();
    await service.loadState();
    if (mounted) {
      setState(() => _autoExportEnabled = service.enabled);
    }
  }

  Future<void> _checkAndInstallUpdate() async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
      _updateProgress = null;
      _updateMessage = L.tr(context, 'updateChecking');
    });

    try {
      final release = await _updateService.checkForUpdate();
      if (!mounted) return;
      if (release == null) {
        setState(() => _updateMessage = L.tr(context, 'updateCurrent'));
        return;
      }
      setState(() => _updateMessage =
          '${L.tr(context, 'updateFound')} ${release.version}');

      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        final opened = await launchUrl(
          Uri.parse(release.url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) throw StateError('Could not open the GitHub release page');
        setState(() => _updateMessage = release.tag);
        return;
      }

      final allowed = await _updateChannel.invokeMethod<bool>(
        'requestInstallPermission',
      );
      if (allowed != true) {
        setState(() => _updateMessage = L.tr(context, 'updatePermission'));
        return;
      }

      final apk = await _updateService.findDownloadedApk(
        release,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _updateProgress = total == 0 ? null : received / total;
            _updateMessage =
                '${L.tr(context, 'updateDownloading')} ${(_updateProgress! * 100).round()}%';
          });
        },
      );
      if (!mounted) return;
      final opened = await _updateChannel.invokeMethod<bool>(
        'installApk',
        {'path': apk.path},
      );
      if (!mounted) return;
      setState(() {
        _updateMessage = opened == true
            ? L.tr(context, 'updateInstalling')
            : L.tr(context, 'updatePermission');
        _updateProgress = null;
      });
    } catch (error, stackTrace) {
      debugPrint('GitHub update failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _updateMessage = L.tr(context, 'updateFailed');
          _updateProgress = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = SettingsProvider.of(context);
    final settings = provider.settings;
    final scheme = Theme.of(context).colorScheme;
    final headerFg = Colors.white;

    return Scaffold(
      appBar: AppBar(
        leading: PressScale(
          // Explicit leading so the back arrow gets the same soft press
          // dimple + recoil as every other control (the stock BackButton
          // only had the flat Material ripple).
          scale: 0.88,
          haptic: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          L.tr(context, 'settings'),
          style: Theme.of(context)
                  .appBarTheme
                  .titleTextStyle
                  ?.copyWith(color: headerFg, fontWeight: FontWeight.bold) ??
              TextStyle(color: headerFg, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: headerFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        flexibleSpace: PremiumHeader(colors: AppTheme.headerColors(scheme)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const AppAvatar(radius: 44),
                const SizedBox(height: 12),
                const Text(
                  'Ataraxy.',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            L.tr(context, 'theme'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          SlidingSelector<AppThemeMode>(
            values: AppThemeMode.values,
            value: settings.themeMode,
            onChanged: (mode) {
              // The MaterialApp-level AnimatedTheme morphs every color from
              // the old palette to the new one — no snapshot needed.
              provider.onChanged(settings.copyWith(themeMode: mode));
            },
            labelOf: (context, mode) => L.tr(context, mode.translationKey),
            // The MUTILATED theme wears a small designer tag.
            badgeOf: (context, mode) => mode == AppThemeMode.mutilated
                ? 'ELEGANT-USER'
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            L.tr(context, 'language'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          SlidingSelector<AppLanguage>(
            values: AppLanguage.values,
            value: settings.language,
            onChanged: (lang) {
              provider.onChanged(settings.copyWith(language: lang));
            },
            labelOf: (context, lang) => L.tr(context, lang.translationKey),
          ),
          const SizedBox(height: 20),
          Text(
            L.tr(context, 'security'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: PressScale(
              scale: 0.98,
              child: ListTile(
                leading: const Icon(Icons.pin_rounded),
                title: Text(L.tr(context, 'pin')),
                subtitle: settings.pin != null
                    ? Text('••••')
                    : null,
                trailing: TextButton(
                  onPressed: () => _managePin(context, provider, settings),
                  child: Text(
                    settings.pin != null
                        ? L.tr(context, 'changePin')
                        : L.tr(context, 'setPin'),
                  ),
                ),
            )
            ),
          ),
          // Smoothly appears when a PIN is set and collapses (fade + size)
          // when it's removed, instead of hard-snapping out of the layout.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: settings.pin != null
                ? Padding(
                    key: const ValueKey('pin-remove'),
                    padding: const EdgeInsets.only(top: 10),
                    child: TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(L.tr(context, 'removePin')),
                            content: Text(L.tr(context, 'removePinConfirm')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text(L.tr(context, 'cancel')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(L.tr(context, 'delete')),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          provider.onChanged(
                            settings.copyWith(clearPin: true),
                          );
                          if (context.mounted) {
                            AnimatedSnack.show(
                              context,
                              L.tr(context, 'pinRemoved'),
                              type: SnackType.info,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(L.tr(context, 'removePin')),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('pin-none')),
          ),
          const SizedBox(height: 20),
          Text(
            L.tr(context, 'reminders'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: PressScale(
              scale: 0.98,
              haptic: true,
              child: ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: Text(L.tr(context, 'reminders')),
                subtitle: settings.reminderEnabled &&
                        settings.reminderTime != null
                    ? Text(
                        '${settings.reminderTime} · ${settings.reminderText ?? ''}',
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final result = await showDialog<AppSettings>(
                    context: context,
                    builder: (_) => ReminderDialog(settings: settings),
                  );
                  if (result != null && context.mounted) {
                    provider.onChanged(result);
                    await NotificationService.updateReminderFromSettings(
                      result,
                      requestBatteryExemption: result.reminderEnabled,
                    );
                    if (context.mounted) {
                      AnimatedSnack.show(
                        context,
                        L.tr(context, result.reminderEnabled ? 'reminderSet' : 'reminderDisabled'),
                        type: result.reminderEnabled ? SnackType.success : SnackType.info,
                      );
                    }
                  }
                },
            )
            ),
          ),
          const SizedBox(height: 8),
          PressScale(
            scale: 0.97,
            child: OutlinedButton.icon(
              onPressed: () async {
                final details =
                    await NotificationService.requestAllPermissions();
              final err = await NotificationService.sendTest();
              if (context.mounted) {
                if (err == null && details.contains('ОТКЛОНЕНО')) {
                  AnimatedSnack.show(
                    context,
                    details,
                    type: SnackType.warning,
                    duration: const Duration(seconds: 6),
                  );
                } else {
                  AnimatedSnack.show(
                    context,
                    err ?? '${L.tr(context, 'testNotification')} ✓',
                    type: err == null ? SnackType.success : SnackType.error,
                  );
                }
              }
            },
            icon: const Icon(Icons.notifications_rounded, size: 18),
              label: Text(L.tr(context, 'testNotification')),
            ),
          ),
          const SizedBox(height: 8),
          PressScale(
            scale: 0.97,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(L.tr(context, 'confirmDelete')),
                  content: Text(L.tr(context, 'confirmDeleteData')),
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
                      child: Text(L.tr(context, 'deleteData')),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                // Очищаем все данные и настройки
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                
                // Удаляем файлы кэша
                try {
                  final appDir = await getApplicationDocumentsDirectory();
                  if (appDir.existsSync()) {
                    appDir.delete(recursive: true);
                  }
                } catch (e) {
                  // Игнорируем ошибки удаления файлов
                }
                
                // Перезапускаем приложение
                SystemChannels.platform.invokeMethod('System.exit', 0);
              }
            },
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: AppAccents.danger,
            ),
              label: Text(
                L.tr(context, 'clearData'),
                style: const TextStyle(color: AppAccents.danger),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: VolumetricSwitchListTile(
              leading: const Icon(Icons.save_rounded),
              title: L.tr(context, 'autosave'),
              subtitle: L.tr(context, 'autosaveHint'),
              value: settings.autosave,
              onChanged: (v) =>
                  provider.onChanged(settings.copyWith(autosave: v)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            L.tr(context, 'experimental'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: VolumetricSwitchListTile(
              leading: const Icon(Icons.psychology_rounded),
              title: L.tr(context, 'tulpa'),
              subtitle: L.tr(context, 'tulpaHint'),
              value: settings.tulpaEnabled,
              onChanged: (v) =>
                  provider.onChanged(settings.copyWith(tulpaEnabled: v)),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                VolumetricSwitchListTile(
                  leading: const Icon(Icons.water_drop_rounded),
                  title: L.tr(context, 'expWater'),
                  value: settings.waterEnabled,
                  onChanged: (v) =>
                      provider.onChanged(settings.copyWith(waterEnabled: v)),
                ),
                const Divider(height: 1),
                VolumetricSwitchListTile(
                  leading: const Icon(Icons.timer_rounded),
                  title: L.tr(context, 'expFasting'),
                  value: settings.fastingEnabled,
                  onChanged: (v) =>
                      provider.onChanged(settings.copyWith(fastingEnabled: v)),
                ),
                const Divider(height: 1),
                VolumetricSwitchListTile(
                  leading: const Icon(Icons.bolt_rounded),
                  title: L.tr(context, 'expPomodoro'),
                  value: settings.pomodoroEnabled,
                  onChanged: (v) => provider.onChanged(
                    settings.copyWith(pomodoroEnabled: v),
                  ),
                ),
                const Divider(height: 1),
                VolumetricSwitchListTile(
                  leading: const Icon(Icons.directions_walk_rounded),
                  title: L.tr(context, 'expSteps'),
                  value: settings.stepsEnabled,
                  onChanged: (v) =>
                      provider.onChanged(settings.copyWith(stepsEnabled: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            L.tr(context, 'data'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                PressScale(
                  scale: 0.98,
                  haptic: true,
                  child: ListTile(
                    leading: const Icon(Icons.upload_rounded),
                    title: Text(L.tr(context, 'export')),
                    onTap: () => _export(context),
                )
                ),
                const Divider(height: 1),
                PressScale(
                  scale: 0.98,
                  haptic: true,
                  child: ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: Text(L.tr(context, 'import')),
                    onTap: () => _import(context),
                )
                ),
                const Divider(height: 1),
                VolumetricSwitchListTile(
                  leading: const Icon(Icons.shield_rounded),
                  title: L.tr(context, 'protectDeletedTitle'),
                  subtitle: L.tr(context, 'protectDeletedHint'),
                  value: settings.protectDeletedOnImport,
                  onChanged: (v) => provider.onChanged(
                    settings.copyWith(protectDeletedOnImport: v),
                  ),
                ),
                // Auto-export switch lives right under the import-protection
                // toggle (same data section) — not its own category.
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_rounded),
                  title: Text(L.tr(context, 'autoExportTitle')),
                  subtitle: Text(L.tr(context, 'autoExportHint')),
                  trailing: VolumetricSwitch(
                    value: _autoExportEnabled,
                    onChanged: (v) async {
                      final service = AutoExportService();
                      if (v) {
                        await service.enable();
                      } else {
                        await service.disable();
                      }
                      setState(() => _autoExportEnabled = v);
                      if (context.mounted) {
                        AnimatedSnack.show(
                          context,
                          v
                              ? L.tr(context, 'autoExportEnabled')
                              : L.tr(context, 'autoExportDisabled'),
                          type: v ? SnackType.success : SnackType.info,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
           const SizedBox(height: 12),
           PressScale(
             scale: 0.98,
             haptic: true,
             child: ListTile(
               leading: const Icon(Icons.info_outline_rounded),
               title: Text(L.tr(context, 'about')),
               trailing: const Icon(Icons.chevron_right_rounded),
               onTap: () => Navigator.of(context).push(
                 fadeRoute(const AboutScreen()),
               ),
           )
           ),
           const SizedBox(height: 8),
           Container(
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(16),
               border: Border.all(
                 color: scheme.outline.withValues(alpha: 0.3),
               ),
             ),
             child: Column(
               children: [
                 PressScale(
                   scale: 0.98,
                   haptic: true,
                   child: ListTile(
                     leading: const Icon(Icons.system_update_alt_rounded),
                     title: Text(L.tr(context, 'updateTitle')),
                     subtitle: Text(_updateMessage ?? L.tr(context, 'updateHint')),
                     trailing: _isUpdating
                         ? const SizedBox(
                             width: 22,
                             height: 22,
                             child: CircularProgressIndicator(strokeWidth: 2),
                           )
                         : const Icon(Icons.download_rounded),
                     onTap: _isUpdating ? null : _checkAndInstallUpdate,
                 )
                 ),
                 if (_updateProgress != null)
                   Padding(
                     padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                     child: LinearProgressIndicator(value: _updateProgress),
                   ),
               ],
             ),
           ),
           const SizedBox(height: 12),
           PressScale(
             scale: 0.98,
             haptic: true,
             child: ListTile(
               leading: const Icon(Icons.refresh_rounded),
               title: Text(L.tr(context, 'resetSettings')),
               trailing: const Icon(Icons.chevron_right_rounded),
               onTap: () => _resetSettings(context),
           )
           ),
          const SizedBox(height: 20),
          Text(
            L.tr(context, 'aiSettingsTitle'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                VolumetricSwitchListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: L.tr(context, 'aiSettingsTitle'),
                  subtitle: L.tr(context, 'aiSettingsHint'),
                  value: settings.aiEnabled,
                  onChanged: (v) =>
                      provider.onChanged(settings.copyWith(aiEnabled: v)),
                ),
                // Sub-items collapse smoothly when the assistant is OFF —
                // like a dropdown closing, the ADA/provider/key/limit rows
                // and pills slide away; re-enabling opens them the same
                // way. The switch itself always stays.
                ClipRect(
                  child: AnimatedAlign(
                    alignment: Alignment.topCenter,
                    heightFactor: settings.aiEnabled ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOutCubic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(height: 1),
                        // «Участвуй в развитии ADA» — bold-outlined tile that opens
                        // a rounded info sheet (same style as the provider sheet).
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showAdaJoinInfo(context),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          // Bolder outline — clearly stands out from the
                          // thin 1px borders used elsewhere.
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.75),
                            width: 2,
                          ),
                          color: scheme.primaryContainer
                              .withValues(alpha: 0.25),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.handshake_rounded,
                              color: scheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Участвуй в развитии ADA',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: scheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                PressScale(
                  scale: 0.98,
                  haptic: true,
                  child: ListTile(
                    leading: const Icon(Icons.dns_rounded),
                    title: Text(L.tr(context, 'aiProvider')),
                    // The label/model cross-fades smoothly when the key
                    // changes instead of snapping.
                    subtitle: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        () {
                          final det = AiService.providerForKey(settings.aiKey);
                          return '${det.label} · ${det.model}';
                        }(),
                        key: ValueKey(
                          '${AiService.providerForKey(settings.aiKey).label} · '
                          '${AiService.providerForKey(settings.aiKey).model}',
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showProviderInfo(context),
                )
                ),
                const Divider(height: 1),
                PressScale(
                  scale: 0.98,
                  haptic: true,
                  child: ListTile(
                    leading: const Icon(Icons.key_rounded),
                    title: Text(L.tr(context, 'aiKey')),
                    // The key preview is always MASKED here (privacy) — the
                    // eye lives INSIDE the edit dialog's input field, where
                    // the key text smoothly fades between hidden and shown.
                    subtitle: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        (settings.aiKey ?? '').isEmpty
                            ? L.tr(context, 'aiKeyEmpty')
                            : _maskKey(settings.aiKey!),
                        key: ValueKey(settings.aiKey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editAiKey(context, provider, settings),
                )
                ),
                // Key-source pills BELOW the tile (outside its tap area, so
                // they never get swallowed by the ListTile onTap). Label sits
                // ABOVE the pills — «Получить ключ:» must not squeeze to the
                // right of GROQ/PSAI.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Получить ключ:',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // One prominent pill: freellm.net already catalogs
                          // every free provider with fresh key links — so it
                          // is the main way to get a key.
                          _KeyPill(
                            label: 'FreeLLM',
                            gradient: true,
                            large: true,
                            onTap: () => _openFreeLlm(context),
                          ),
                          _KeyPill(
                            label: 'PSAI',
                            gradient: true,
                            onTap: () => _openPoolside(context),
                          ),
                          _KeyPill(
                            label: '(VPN)',
                            onTap: () => _openVpnSites(context),
                          ),
                          // Saved-keys dropdown: tap opens the list, hold a
                          // key 10 s to delete it. Local app feature — not
                          // available on freellm, so it stays.
                          _KeyPill(
                            label: 'Мои ключи',
                            onTap: () =>
                                _showSavedKeys(context, provider, settings),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                PressScale(
                  scale: 0.98,
                  haptic: true,
                  child: ListTile(
                    leading: const Icon(Icons.speed_rounded),
                    title: Text(L.tr(context, 'aiDailyLimit')),
                    subtitle: Text(
                      settings.aiDailyLimit <= 0
                          ? L.tr(context, 'aiLimitUnlimited')
                          : _perDayLimitLabel(context, settings.aiDailyLimit),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editAiLimit(context, provider, settings),
                )
                ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.developer_mode_rounded, size: 18),
              label: Text(
                L.tr(context, 'devMode'),
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.4)),
              ),
              onPressed: () => _openDevMode(context),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              L.tr(context, 'license'),
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: GestureDetector(
              onTap: () async {
                final uri = Uri.parse('https://github.com/wxstdo-boop/Ataraxy');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                L.tr(context, 'githubLink'),
                style: TextStyle(
                  color: scheme.primary.withValues(alpha: 0.7),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),        ],
      ),
    );
  }

  /// Rounded info sheet shown on the provider tile: lists the providers
  /// whose API keys are recognized — pasting any of them into the key field
  /// makes it work instead of the default Laguna.
  Future<void> _showProviderInfo(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Icon(
              Icons.dns_rounded,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(L.tr(ctx, 'aiProvider')),
          ],
        ),
        content: const Text(
          'Поддерживаются почти все из FreeLLM — вставь их API-ключ в поле '
          'ниже, и провайдер заработает вместо Laguna. OVHcloud AI '
          'Endpoints и AI Horde работают вообще без ключа (подключены как '
          'бесплатные фолбэки). Пилля FreeLLM откроет каталог freellm.net — '
          '400+ бесплатных моделей и ссылки на свежие ключи.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.tr(ctx, 'ok')),
          ),
        ],
      ),
    );
  }

  /// Rounded info sheet for the «Участвуй в развитии ADA» tile — describes
  /// how to try the author's other FOSS apps while ADA is early-stage.
  Future<void> _showAdaJoinInfo(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Icon(Icons.handshake_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Участвуй в развитии ADA',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'АДА в начальном развитии, если хотите участвовать — пробуйте '
          'приложение Misasoc (или IDE на PC) от того же автора, '
          'полностью FOSS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.tr(ctx, 'ok')),
          ),
        ],
      ),
    );
  }

  Future<void> _editAiKey(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) async {
    final controller = TextEditingController(text: settings.aiKey ?? '');
    // The key is hidden by default; the eye reveals it. The flag lives
    // OUTSIDE the dialog builder closure so StatefulBuilder can toggle it
    // across rebuilds.
    var obscure = true;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(L.tr(ctx, 'aiKey')),
          // The WHOLE field cross-fades between the masked and revealed
          // states (the key text itself changes smoothly, not just the eye
          // icon). Both children share the same controller; the incoming
          // one re-focuses and restores the caret after the swap.
          content: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: TextField(
              cursorOpacityAnimates: true,
              key: ValueKey('key-field-$obscure'),
              controller: controller,
              obscureText: obscure,
              // No auto keyboard popup — the user taps the field to type.
              autofocus: false,
              maxLength: 350,
              maxLines: 3,
              buildCounter: animatedFieldCounter,
              // No magnifying-glass selection loupe + clean toolbar (Cut/
              // Copy/Paste/Share only — no "Ask Copilot" / web lookup).
              magnifierConfiguration: TextMagnifierConfiguration.disabled,
              contextMenuBuilder: buildLimitedContextMenu,
              decoration: InputDecoration(
                hintText: 'gsk_… / nvapi-… / AIza… / sk-or-… / sky_…',
                border: const OutlineInputBorder(),
                // Smooth eye toggle: fades/scales between the two states and
                // keeps the caret exactly where it was.
                suffixIcon: PressableIconButton(
                  size: 32,
                  onPressed: () {
                    final sel = controller.selection;
                    setDlgState(() => obscure = !obscure);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (controller.selection != sel) {
                        controller.selection = sel;
                      }
                    });
                  },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      key: ValueKey(obscure),
                      size: 20,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.tr(ctx, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(L.tr(ctx, 'save')),
            ),
          ],
        ),
      ),
    );
    if (value != null && context.mounted) {
      provider.onChanged(settings.copyWith(aiKey: value));
      // Every pasted key is remembered (most recent first, max 10) so it
      // can be re-picked from the «Мои ключи» dropdown without retyping.
      if (value.trim().isNotEmpty) {
        unawaited(() async {
          try {
            await StorageService().saveAiKeyToSaved(value.trim());
          } catch (e) {
            debugPrint('saveAiKeyToSaved: $e');
          }
        }());
      }
    }
  }

  /// Bottom sheet with all saved API keys: tap to select, hold 10 s to
  /// delete (a progress ring counts the hold).
  Future<void> _showSavedKeys(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) async {
    final storage = StorageService();
    var keys = await storage.loadSavedAiKeys();
    if (!context.mounted) return;
    if (keys.isEmpty) {
      AnimatedSnack.show(
        context,
        'Пока нет сохранённых ключей — вставь ключ в поле выше.',
        type: SnackType.info,
      );
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.key_rounded, size: 19, color: scheme.primary),
                    const SizedBox(width: 9),
                    Text(
                      'Мои API-ключи',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Тап — выбрать · зажми 10 сек — удалить',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: keys.length,
                    itemBuilder: (ctx, i) {
                      final k = keys[i];
                      return _SavedKeyRow(
                        keyValue: k,
                        active: k == settings.aiKey,
                        onSelect: () => Navigator.pop(ctx, k),
                        onDelete: () {
                          storage.deleteSavedAiKey(k).then((updated) {
                            if (ctx.mounted) {
                              setSheetState(() => keys = updated);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && context.mounted) {
      provider.onChanged(settings.copyWith(aiKey: picked));
      AnimatedSnack.show(
        context,
        'Ключ выбран: ${_maskKey(picked)}',
        type: SnackType.success,
      );
    }
  }

  /// `abcdef…Wxyz` — shows enough to recognise the key, hides the middle.
  static String _maskKey(String key) {
    if (key.length <= 10) return key;
    return '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
  }

  /// Opens freellm.net — a directory of 400+ free LLM APIs (NVIDIA NIM,
  /// Google Gemini, Groq, OpenRouter, Cerebras…) with links to fresh free
  /// keys and live rate limits. The app already supports every provider it
  /// lists; this is the way to discover new free backends.
  Future<void> _openFreeLlm(BuildContext context) async {
    final uri = Uri.parse('https://freellm.net/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens the Poolside Platform in the browser — free Laguna API keys.
  Future<void> _openPoolside(BuildContext context) async {
    final uri = Uri.parse('https://platform.poolside.ai');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens the author's Misasoc repo — VPN-for-websites helper for sites
  /// that block RU.
  Future<void> _openVpnSites(BuildContext context) async {
    final uri = Uri.parse('https://github.com/wxstdo-boop/Misasoc');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _editAiLimit(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) async {
    final controller = TextEditingController(
      text: settings.aiDailyLimit.toString(),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.tr(ctx, 'aiDailyLimit')),
        content: TextField(
          cursorOpacityAnimates: true,
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 5,
          buildCounter: animatedFieldCounter,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          // No magnifying-glass selection loupe + clean toolbar (Cut/
          // Copy/Paste/Share only).
          magnifierConfiguration: TextMagnifierConfiguration.disabled,
          contextMenuBuilder: buildLimitedContextMenu,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.tr(ctx, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(L.tr(ctx, 'save')),
          ),
        ],
      ),
    );
    if (value != null && context.mounted) {
      final limit = (int.tryParse(value) ?? AiService.maxDailyLimit)
          .clamp(1, AiService.maxDailyLimit);
      provider.onChanged(settings.copyWith(aiDailyLimit: limit));
    }
  }

  static Future<void> _resetSettings(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.tr(context, 'resetSettings')),
        content: Text(L.tr(context, 'resetSettingsConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.tr(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppAccents.amber),
            child: Text(L.tr(context, 'reset')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (!context.mounted) return;

    try {
      final provider = SettingsProvider.of(context);
      final service = SettingsService();
      await service.reset();
      
      // Обновляем провайдер с настройками по умолчанию
      provider.onChanged(const AppSettings());
      
      if (context.mounted) {
        AnimatedSnack.show(
          context,
          L.tr(context, 'settingsReset'),
          type: SnackType.success,
        );
      }
    } catch (e) {
      debugPrint('Reset settings error: $e');
      if (context.mounted) {
        AnimatedSnack.show(
          context,
          L.tr(context, 'errorResettingSettings'),
          type: SnackType.error,
        );
      }
    }
  }

  Future<void> _openDevMode(BuildContext context) async {
    final p = SettingsProvider.of(context);
    final s = p.settings;
    if (s.devModeEnabled) {
      Navigator.of(context).push(
        fadeRoute(const DevSettingsScreen()),
      );
      return;
    }
    final pass = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctl = TextEditingController();
        return AlertDialog(
          title: Text(L.tr(context, 'devPassword')),
          content: TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
            controller: ctl,
            obscureText: true,
            maxLength: 10,
            decoration: const InputDecoration(
              hintText: '••••',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (ctl.text == '7720') {
                  Navigator.pop(ctx, 'ok');
                } else {
                  AnimatedSnack.show(
                    ctx,
                    L.tr(context, 'devWrongPassword'),
                    type: SnackType.error,
                  );
                }
              },
              child: Text(L.tr(context, 'unlock')),
            ),
          ],
        );
      },
    );
    if (pass != null && context.mounted) {
      p.onChanged(s.copyWith(devModeEnabled: true));
      if (context.mounted) {
        Navigator.of(context).push(
          fadeRoute(const DevSettingsScreen()),
        );
      }
    }
  }

  Future<void> _export(BuildContext context) async {
    // Resolved before the first await: the localized strings below are read
    // from the element, which may be gone once the save sheet closes.
    final pickTitle = L.tr(context, 'exportPickLocation');
    final doneText = L.tr(context, 'exportDone');
    final cancelledText = L.tr(context, 'exportCancelled');

    final service = StorageService();
    final json = await service.exportToJson();

    // Generate filename with timestamp
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final suggestedName = 'ataraxy_backup_$timestamp.json';

    // System "Save as" sheet (SAF ACTION_CREATE_DOCUMENT): the user picks the
    // folder and may rename the file, and the app writes only there. This
    // replaces the share sheet, which handed the whole backup to another app
    // and, on MIUI, surfaced a file-access prompt on the way.
    final saved = await FilePicker.saveFile(
      dialogTitle: pickTitle,
      fileName: suggestedName,
      bytes: utf8.encode(json),
      mimeType: 'application/json',
    );
    if (!context.mounted) return;
    if (saved == null) {
      AnimatedSnack.show(context, cancelledText, type: SnackType.info);
      return;
    }
    AnimatedSnack.show(
      context,
      '$doneText\n${saved.path}',
      type: SnackType.success,
    );
  }

  Future<void> _import(BuildContext context) async {
    final errorText = L.tr(context, 'importError');
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (file == null) return;
    try {
      // Читаем файл с правильной кодировкой
      final content = StorageService.readFileWithEncoding(file.path);
      final service = StorageService();
      final summary = await service.importFromJson(content);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_buildImportSnackBar(context, summary));
      }
    } catch (e) {
      if (context.mounted) {
        AnimatedSnack.show(context, errorText, type: SnackType.error);
      }
    }
  }

  /// Build a snackbar that honestly lists what was imported + what was
  /// lost on the way (media files whose paths no longer exist on this
  /// device, activities trimmed by the 5-cap, items dropped on parse).
  /// Previously `_import` showed a single "import done" line that hid
  /// real losses — the user mistook "2 of 7 transferred" for "not all
  /// imported".
  SnackBar _buildImportSnackBar(BuildContext context, ImportSummary s) {
    // IMPORTANT: the snackbar must use the THEME's snackbar colours (light
    // bg + dark text on light themes, dark bg + light text on dark themes).
    // Previously the background was hard-coded to scheme.inverseSurface
    // (dark on light themes) while the text colour came from the theme's
    // light snackbar contentTextStyle (dark) — dark-on-dark rendered as an
    // EMPTY snackbar after import. Now both come from the same theme source.
    final snackTheme = Theme.of(context).snackBarTheme;
    final scheme = Theme.of(context).colorScheme;
    final bg = snackTheme.backgroundColor ?? scheme.inverseSurface;
    final fg = snackTheme.contentTextStyle?.color ?? scheme.onInverseSurface;

    final lines = <Widget>[
      Text(
        L.tr(context, 'importSummary'),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        L.tr(context, 'importSummaryLine', params: {
          'entries': s.entriesChanged,
          'favorites': s.favoritesParsed,
          'activities': s.activitiesParsed,
        }),
        style: const TextStyle(fontSize: 13),
      ),
    ];
    final totalSkipped =
        s.entriesSkipped + s.favoritesSkipped + s.activitiesSkipped;
    if (totalSkipped > 0) {
      lines.add(const SizedBox(height: 4));
      lines.add(Text(
        L.tr(context, 'importItemsSkipped', params: {'n': totalSkipped}),
        style: const TextStyle(fontSize: 12),
      ));
    }
    if (s.activitiesTrimmed > 0) {
      lines.add(const SizedBox(height: 4));
      lines.add(Text(
        L.tr(context, 'importActivitiesTrimmed',
            params: {'n': s.activitiesTrimmed}),
        style: const TextStyle(fontSize: 12),
      ));
    }
    if (s.favoritesMediaMissing > 0) {
      lines.add(const SizedBox(height: 4));
      lines.add(Text(
        L.tr(context, 'importMediaMissing',
            params: {'n': s.favoritesMediaMissing}),
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ));
    }
    final isWarning = s.favoritesMediaMissing > 0;
    // In warning mode we swap in errorContainer — its own on-colour keeps
    // the text readable there too.
    final effectiveBg = isWarning ? scheme.errorContainer : bg;
    final effectiveFg =
        isWarning ? scheme.onErrorContainer : fg;
    return SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map((l) => _recolor(l, effectiveFg))
            .toList(),
      ),
      duration: Duration(seconds: isWarning ? 8 : 4),
      backgroundColor: effectiveBg,
    );
  }

  Widget _recolor(Widget w, Color color) {
    if (w is Text) {
      final t = w;
      return Text(
        t.data ?? '',
        style: (t.style ?? const TextStyle()).copyWith(color: color),
      );
    }
    return w;
  }

  Future<void> _managePin(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) async {
    final doneText = L.tr(context, 'pinSetDone');
    if (settings.pin != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _CurrentPinDialog(expected: settings.pin!),
      );
      if (ok != true) return;
    }
    if (!context.mounted) return;
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinSetupDialog(),
    );
    if (pin != null && context.mounted) {
      provider.onChanged(settings.copyWith(pin: pin));
      AnimatedSnack.show(
        context,
        doneText,
        type: SnackType.success,
      );
    }
  }

  /// «N сообщений в день» with proper Russian plural forms
  /// (1 сообщение / 2-4 сообщения / 5+ сообщений); en/fr use the generic
  /// translated suffix.
  String _perDayLimitLabel(BuildContext context, int n) {
    if (Localizations.localeOf(context).languageCode != 'ru') {
      return '$n ${L.tr(context, 'aiLimitPerDay')}';
    }
    final n10 = n % 10;
    final n100 = n % 100;
    final String word;
    if (n10 == 1 && n100 != 11) {
      word = 'сообщение';
    } else if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) {
      word = 'сообщения';
    } else {
      word = 'сообщений';
    }
    return '$n $word в день';
  }
}
