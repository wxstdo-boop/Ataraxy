import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dream_journal/l10n/strings.dart';

/// Compact circular day-streak badge shown next to the Ataraxy wordmark in
/// the home header. Colours are pulled from the active [ColorScheme]
/// (Material You), so the badge always matches the theme.
///
/// Animations: the badge eases in once (fade + slide + spring scale) on
/// first build, the number counts up/down smoothly whenever the streak
/// changes, and the badge gently pulses on growth.
///
/// Long-pressing pops a small rounded card explaining the streak.
class StreakBadge extends StatefulWidget {
  /// Current streak in days (0 when nothing is written yet).
  final int streak;

  const StreakBadge({super.key, required this.streak});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    final enterCurve =
        CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _fade = enterCurve;
    _slide = Tween<Offset>(
      begin: const Offset(-0.4, 0),
      end: Offset.zero,
    ).animate(enterCurve);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(StreakBadge old) {
    super.didUpdateWidget(old);
    if (old.streak != widget.streak) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _showInfo() {
    HapticFeedback.mediumImpact();
    final scheme = Theme.of(context).colorScheme;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: L.tr(context, 'streak'),
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (context, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
      pageBuilder: (context, _, __) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: scheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  L.tr(context, 'streak'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.streak} ${L.tr(context, 'streakDays')}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  L.tr(context, 'streakHint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(L.tr(context, 'ok')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.streak > 0;
    // Material You colours: fire when active, quiet surface when empty.
    final colors = active
        ? [scheme.primary, scheme.tertiary]
        : [scheme.surfaceContainerHighest, scheme.outlineVariant];

    // The badge widens smoothly as the streak grows past 9 (10, 100, 1000…)
    // so the number always fits — 24 px for one digit, +7 px per extra
    // digit, capped at four digits so a 10000-day streak can't overflow.
    final digits = widget.streak.clamp(0, 9999).toString().length;
    final size = 24.0 + (digits - 1).clamp(0, 3) * 7.0;
    final fontSize = switch (digits) {
      1 => 13.0,
      2 => 12.0,
      _ => 11.0,
    };

    return Semantics(
      container: true,
      button: true,
      label:
          '${widget.streak} ${L.tr(context, 'streakDays')} — ${L.tr(context, 'streak')}',
      child: GestureDetector(
        onLongPress: _showInfo,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: widget.streak),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      // Cap at four digits so the badge width can't grow
                      // without bound; a 10000-day streak shows "9999+".
                      value >= 10000 ? '9999+' : '$value',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
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
