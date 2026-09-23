import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/settings.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  final AppSettings settings;
  final void Function(AppSettings) onComplete;
  final VoidCallback onDismiss;

  const WelcomeScreen({
    super.key,
    required this.settings,
    required this.onComplete,
    required this.onDismiss,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late bool _dontShowAgain;
  bool _notificationsGranted = false;
  bool _requesting = false;
  bool _isClosing = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _dontShowAgain = false;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestNotifications() async {
    setState(() => _requesting = true);
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Already granted in a previous session? Surface the green
        // "granted" state and let the user finish with the Start button —
        // nothing to request, and the onboarding is NEVER force-closed.
        final notif = await Permission.notification.status;
        final battery = await Permission.ignoreBatteryOptimizations.status;
        if ((notif.isGranted || notif.isRestricted) &&
            (battery.isGranted || battery.isRestricted)) {
          if (mounted) {
            setState(() => _notificationsGranted = true);
            // Permissions were already granted in a previous session —
            // show the green state briefly, then glide away smoothly.
            _finishSoon();
          }
          return;
        }
      }

      final granted = await NotificationService().requestPermissions();
      if (mounted) {
        if (granted) {
          // Battery optimization is requested at the same moment
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            final battery = await Permission.ignoreBatteryOptimizations.status;
            if (!battery.isGranted && !battery.isRestricted) {
              await Permission.ignoreBatteryOptimizations.request();
            }
          }
          setState(() => _notificationsGranted = true);
          // Permissions granted — show the green state briefly, then glide
          // the whole welcome screen away as ONE piece (no layout reflow).
          _finishSoon();
          return;
        }
        // On web, permission_handler has limited/no support — skip the
        // detailed permission checks that would throw.
        if (kIsWeb) return;

        final status = await Permission.notification.status;
        final exact = await Permission.scheduleExactAlarm.status;
        final battery = await Permission.ignoreBatteryOptimizations.status;
        if (status.isPermanentlyDenied && mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => _PermissionDeniedDialog(),
          );
          if (openSettings == true && mounted) {
            await openAppSettings();
          }
        } else if (mounted) {
          final problems = <String>[];
          if (status.isDenied) problems.add('уведомления');
          if (exact.isDenied) problems.add('точные будильники');
          if (battery.isDenied) problems.add('оптимизацию батареи');
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Разрешения не получены'),
              content: Text(
                problems.isEmpty
                    ? 'Разрешение не было предоставлено. Попробуйте ещё раз.'
                    : 'Не хватает разрешений: ${problems.join(', ')}.\n'
                      'На MIUI это часто нужно включать вручную в настройках приложения.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Понятно'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      // Don't touch state while the exit animation is already playing.
      if (mounted && !_isClosing) setState(() => _requesting = false);
    }
  }

  void _finish() {
    if (_isClosing) return; // prevent double-fire
    _isClosing = true;
    // Animate out: the whole screen FADES and glides down gently as one
    // piece — nothing in the layout changes mid-animation, so no jerk.
    _animCtrl.reverse().then((_) {
      if (mounted) {
        final updated = widget.settings.copyWith(
          // The welcome returns next launch UNLESS the user explicitly
          // checked "Больше не показывать" (keep that contract intact).
          showWelcome: !_dontShowAgain,
          reminderEnabled: _notificationsGranted,
        );
        widget.onComplete(updated);
      }
    });
  }

  /// Lets the user SEE the green "Разрешение получено" for a beat before
  /// the whole window glides away in one smooth piece.
  void _finishSoon() {
    Future<void>.delayed(const Duration(milliseconds: 350)).then((_) {
      if (mounted && !_isClosing) _finish();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _WelcomeHeader(onDismiss: widget.onDismiss),
                    const Spacer(flex: 1),
                    _WelcomeIcon(scheme: scheme),
                    const SizedBox(height: 32),
                    _WelcomeTitle(style: style),
                    const SizedBox(height: 12),
                    _WelcomeSubtitle(style: style),
                    const SizedBox(height: 40),
                    if (!_notificationsGranted) ...[
                      _PermissionCard(
                        notificationsGranted: _notificationsGranted,
                        requesting: _requesting,
                        onEnable: _requestNotifications,
                        scheme: scheme,
                        style: style,
                      ),
                      const Spacer(flex: 1),
                      _DontShowAgainCheckbox(
                        value: _dontShowAgain,
                        onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
                      ),
                      const SizedBox(height: 16),
                      _StartButton(onPressed: _finish),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  final VoidCallback onDismiss;
  const _WelcomeHeader({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: IconButton(
          icon: Icon(Icons.close_rounded, color: scheme.onSurface),
          onPressed: onDismiss,
          tooltip: 'Пропустить',
        ),
      ),
    );
  }
}

class _WelcomeIcon extends StatelessWidget {
  final ColorScheme scheme;
  const _WelcomeIcon({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_stories_rounded,
        size: 56,
        color: scheme.primary,
      ),
    );
  }
}

class _WelcomeTitle extends StatelessWidget {
  final TextTheme style;
  const _WelcomeTitle({required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Добро пожаловать в Ataraxy',
      style: style.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _WelcomeSubtitle extends StatelessWidget {
  final TextTheme style;
  const _WelcomeSubtitle({required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ваш личный дневник для записи снов, мыслей и идей',
      style: style.bodyLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final bool notificationsGranted;
  final bool requesting;
  final VoidCallback onEnable;
  final ColorScheme scheme;
  final TextTheme style;

  const _PermissionCard({
    required this.notificationsGranted,
    required this.requesting,
    required this.onEnable,
    required this.scheme,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _PermissionIcon(
              notificationsGranted: notificationsGranted,
              scheme: scheme,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _PermissionText(
                notificationsGranted: notificationsGranted,
                style: style,
              ),
            ),
            const SizedBox(width: 8),
            notificationsGranted
                ? const Icon(Icons.check_circle_rounded, color: AppAccents.sage)
                : FilledButton.tonalIcon(
                    onPressed: requesting ? null : onEnable,
                    icon: requesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications_rounded, size: 18),
                    label: const Text('Включить'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _PermissionIcon extends StatelessWidget {
  final bool notificationsGranted;
  final ColorScheme scheme;
  const _PermissionIcon({required this.notificationsGranted, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: notificationsGranted
            ? AppAccents.sage.withValues(alpha: 0.15)
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        notificationsGranted
            ? Icons.notifications_active_rounded
            : Icons.notifications_none_rounded,
        color: notificationsGranted ? AppAccents.sage : scheme.primary,
      ),
    );
  }
}

class _PermissionText extends StatelessWidget {
  final bool notificationsGranted;
  final TextTheme style;
  const _PermissionText({required this.notificationsGranted, required this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Уведомления',
          style: style.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          notificationsGranted
              ? 'Разрешение получено'
              : 'Для напоминаний о записях в дневник',
          style: style.bodySmall?.copyWith(
            color: notificationsGranted
                ? AppAccents.sage
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DontShowAgainCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _DontShowAgainCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: const Text('Больше не показывать'),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        child: const Text('Начать пользоваться'),
      ),
    );
  }
}

class _PermissionDeniedDialog extends StatelessWidget {
  const _PermissionDeniedDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Разрешения отключены'),
      content: const Text(
        'Откройте настройки приложения и включите разрешение на уведомления вручную.\n\n'
        'На Xiaomi/MIUI также включите:\n'
        '• Автозапуск\n'
        '• Уведомления\n'
        '• Точные будильники\n'
        '• Отключите оптимизацию батареи для Ataraxy',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Открыть настройки'),
        ),
      ],
    );
  }
}
