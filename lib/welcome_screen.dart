import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/settings.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/press_scale.dart';

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
      // Ask ONLY for the notification permission here — the system dialog.
      // Battery-optimization / exact-alarm prompts are a separate, heavier
      // step and are left for the settings screen, so tapping "Включить"
      // never yanks the user into a background-app settings page.
      final granted = await NotificationService().requestPermissions(
        requestExactAlarms: false,
      );
      if (!mounted) return;

      if (granted) {
        // Stay on the card so the button glides into its "Включено" state;
        // the user finishes the onboarding themselves with the Start button.
        setState(() {
          _notificationsGranted = true;
          _requesting = false;
        });
        return;
      }

      // On web, permission_handler has limited/no support — skip the
      // detailed permission checks that would throw.
      if (kIsWeb) return;

      final status = await Permission.notification.status;
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => _PermissionDeniedDialog(),
        );
        if (openSettings == true && mounted) {
          await openAppSettings();
        }
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Разрешение не получено'),
            content: const Text(
              'Без разрешения на уведомления напоминания не смогут '
              'показаться. Нажмите «Включить» ещё раз, если передумали.',
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
            colors: [scheme.primaryContainer, scheme.surface],
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
                      onChanged: (v) =>
                          setState(() => _dontShowAgain = v ?? false),
                    ),
                    const SizedBox(height: 16),
                    _StartButton(onPressed: _finish),
                    const SizedBox(height: 32),
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
        child: PressScale(
        scale: 0.88,
        child: IconButton(
          icon: Icon(Icons.close_rounded, color: scheme.onSurface),
          onPressed: onDismiss,
        ),
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
      child: Icon(Icons.auto_stories_rounded, size: 56, color: scheme.primary),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // The plate itself shifts color (neutral -> sage) and radius smoothly
        // as the state flips, so the whole card reacts, not just the button.
        color: notificationsGranted
            ? AppAccents.sage.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
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
          // The button itself never moves: it fades + scales between the
          // "Включить", spinner and green "Включено" states, so granting
          // the permission reads as one smooth motion, not a layout jump.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: _button(),
          ),
        ],
      ),
    );
  }

  Widget _button() {
    if (notificationsGranted) {
      return FilledButton.tonalIcon(
        key: const ValueKey('granted'),
        onPressed: null,
        icon: const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppAccents.sage,
        ),
        label: const Text('Включено', style: TextStyle(color: AppAccents.sage)),
        style: FilledButton.styleFrom(
          disabledBackgroundColor: AppAccents.sage.withValues(alpha: 0.15),
          disabledForegroundColor: AppAccents.sage,
        ),
      );
    }
    return FilledButton.tonalIcon(
      key: const ValueKey('enable'),
      onPressed: requesting ? null : onEnable,
      icon: requesting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_rounded, size: 18),
      label: const Text('Включить'),
    );
  }
}

class _PermissionIcon extends StatelessWidget {
  final bool notificationsGranted;
  final ColorScheme scheme;
  const _PermissionIcon({
    required this.notificationsGranted,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: notificationsGranted
            ? AppAccents.sage.withValues(alpha: 0.15)
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      // The icon swaps with a cross-fade + a small scale pop, so the state
      // change reads as the badge "turning on" rather than snapping.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          key: ValueKey(notificationsGranted),
          notificationsGranted
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: notificationsGranted ? AppAccents.sage : scheme.primary,
        ),
      ),
    );
  }
}

class _PermissionText extends StatelessWidget {
  final bool notificationsGranted;
  final TextTheme style;
  const _PermissionText({
    required this.notificationsGranted,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Уведомления',
          style: style.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        // Animate the label colour as the permission flips, so the wording
        // and the tint change together instead of the text snapping colour.
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          style: (style.bodySmall ?? const TextStyle()).copyWith(
            color: notificationsGranted
                ? AppAccents.sage
                : scheme.onSurfaceVariant,
          ),
          child: Text(
            notificationsGranted
                ? 'Разрешение получено'
                : 'Для напоминаний о записях в дневник',
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
    return PressScale(
      onTap: onPressed,
      scale: 0.96,
      haptic: true,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          child: const Text('Начать пользоваться'),
        ),
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
