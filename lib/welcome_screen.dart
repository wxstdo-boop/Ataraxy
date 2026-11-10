import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/settings.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_letters.dart';
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
    // Do NOT fade this screen out here: the parent HomeContent already
    // cross-fades the welcome screen into the home screen (AnimatedSwitcher).
    // Running both meant the screen faded to the bare background first and
    // THEN the home faded in — two fades in a row, which read as a blink /
    // jerk with a blank frame between them. Handing straight to the parent
    // leaves a single smooth cross-fade.
    final updated = widget.settings.copyWith(
      // The welcome returns next launch UNLESS the user explicitly checked
      // "Больше не показывать" (keep that contract intact).
      showWelcome: !_dontShowAgain,
      reminderEnabled: _notificationsGranted,
    );
    widget.onComplete(updated);
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
                // On a short or narrow phone the welcome column can be taller
                // than the viewport (the permission card alone grows with the
                // text wrap). Make it scrollable when it doesn't fit, but keep
                // the two Spacers pushing the content apart when it does, so
                // the layout still breathes on a tall screen.
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
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
    final base = style.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurface,
    );
    // The brand wordmark writes itself in letter by letter (and the whole
    // card fades out smoothly on exit), so the greeting never just pops. A
    // gentler stagger (longer per-letter duration, shorter delay) keeps the
    // long greeting appearing as one soft, continuous wave instead of a
    // staccato tick-tick-tick.
    return AnimatedLetters(
      'Добро пожаловать в Ataraxy.',
      style: base,
      alignment: WrapAlignment.center,
      duration: const Duration(milliseconds: 620),
      delay: const Duration(milliseconds: 22),
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
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        // The plate itself shifts colour (neutral -> sage) and radius as the
        // state flips, so the whole card reacts, not just the button.
        color: notificationsGranted
            ? AppAccents.sage.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      // Clip so the sliding content never spills past the rounded plate.
      clipBehavior: Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Keep the outgoing card stacked under the incoming one so they
        // glide past each other (a page turn) instead of blinking.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, anim) {
          // Incoming card slides in from the right; the outgoing one leaves
          // to the left — a horizontal "card flip" rather than a fade.
          final incoming = child.key == ValueKey(notificationsGranted);
          final begin = incoming
              ? const Offset(0.14, 0)
              : const Offset(-0.14, 0);
          return ClipRect(
            child: FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: begin,
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(notificationsGranted),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    // Vertical layout: icon + text on top, a full-width button below. The old
    // inline Row let the wide "Включить" pill eat the text column down to a
    // few pixels on a 360dp phone, so the copy wrapped into a tall ribbon and
    // the two states ended up different heights (the card visibly jumped on
    // switch). Stacking keeps the text width stable and the frame constant.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed two-line footprint: "Разрешение получено" is one line and
          // "Для напоминаний о записях в дневник" is two, so without a floor
          // the card would still change height on switch (a 1-line vs 2-line
          // jump). The min height locks both states to the same frame.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PermissionIcon(
                  notificationsGranted: notificationsGranted,
                  scheme: scheme,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _PermissionText(
                    notificationsGranted: notificationsGranted,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _button(),
        ],
      ),
    );
  }

  Widget _button() {
    if (notificationsGranted) {
      return FilledButton.tonalIcon(
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
    return PressScale(
      scale: 0.94,
      haptic: true,
      child: FilledButton.tonalIcon(
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
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: notificationsGranted
            ? AppAccents.sage.withValues(alpha: 0.15)
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      // The whole card slides between states (see _PermissionCard), so the
      // badge itself only needs to tint — no second animation on top.
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
        // The whole card slides between its two states (see _PermissionCard),
        // so the wording simply swaps with it — no per-text animation needed.
        Text(
          notificationsGranted
              ? 'Разрешение получено'
              : 'Для напоминаний о записях в дневник',
          style: (style.bodySmall ?? const TextStyle()).copyWith(
            color: notificationsGranted
                ? AppAccents.sage
                : scheme.onSurfaceVariant,
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
