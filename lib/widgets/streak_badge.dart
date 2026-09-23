import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/widgets/winter_hat.dart';

/// Compact circular day-streak badge shown next to the Ataraxy wordmark in
/// the home header. Colours are pulled from the active [ColorScheme]
/// (Material You), so the badge always matches the theme.
///
/// Animations: the badge eases in once (fade + slide) on first build, and
/// afterwards ONLY the number changes — it counts up/down smoothly. The
/// disc itself never scales, recolors or pulses: size, gradient and colours
/// are constant, so the header geometry stays rock-steady.
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
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

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
  }

  @override
  void dispose() {
    _enter.dispose();
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
      pageBuilder: (context, _, _) => Center(
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
    // One constant look for every streak value (0 included): the disc never
    // recolors or resizes when the count changes — only the digits animate.
    final colors = [scheme.primary, scheme.tertiary];

    // CONSTANT geometry: the disc is always 42px with the same digit size —
    // nothing grows, shrinks or recolors as the streak increases. Huge
    // counts ('9999+') shrink INSIDE the fixed disc via FittedBox, so the
    // header layout never jumps.
    const size = 42.0;

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
            child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
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
                      // A quiet shadow even when empty — so the 0 badge
                      // keeps EXACTLY the same footprint as a "1" badge and
                      // never reads as smaller/dead.
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        // FittedBox keeps the digits at full size for normal
                        // counts and only shrinks the text (never the disc)
                        // for extreme '9999+' values.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: widget.streak),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Text(
                              value >= 10000 ? '9999+' : '$value',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The winter beanie crowns the streak badge: brim sits ON
                  // the circle's top arc (y≈3..10) above the number, pompom
                  // pokes into the header's 30px headroom. Straight, centered.
                  Positioned(
                    top: -10,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: const WinterHat(width: 32, height: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
